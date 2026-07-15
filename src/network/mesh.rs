use crate::chain::{ LatticeBlock, Transaction, Blockchain, BoxError };
use crate::network::Network;
use crate::state::State;
use crate::network::star::P2PMessage; // Re-use your existing message enums!
use futures::StreamExt;
use async_trait::async_trait;
use libp2p::{
    gossipsub,
    mdns,
    noise,
    swarm::NetworkBehaviour,
    swarm::SwarmEvent,
    tcp,
    yamux,
    SwarmBuilder,
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{ Hash, Hasher };
use std::sync::Arc;
use tokio::sync::{ RwLock, mpsc };
use tokio::io::{ AsyncRead, AsyncWrite };
use tracing::{ info, error, debug };

// 1. Define the combined Network Behaviour (Discovery + Messaging)
#[derive(NetworkBehaviour)]
struct MvmBehaviour {
    gossipsub: gossipsub::Behaviour,
    mdns: mdns::tokio::Behaviour,
}

pub struct MeshNetwork {
    config: crate::config::Config,
    blockchain: Arc<RwLock<Blockchain>>,
    state: Arc<RwLock<State>>,
    // Channel to send broadcast commands to the background Swarm task
    command_tx: Option<mpsc::Sender<P2PMessage>>,
    active_peers: Arc<RwLock<Vec<String>>>,
}

impl MeshNetwork {
    pub fn new(config: crate::config::Config, blockchain: Arc<RwLock<Blockchain>>, state: Arc<RwLock<State>>) -> Self {
        MeshNetwork {
            config,
            blockchain,
            state,
            command_tx: None,
            active_peers: Arc::new(RwLock::new(Vec::new())),
        }
    }

    // Helper to define our network topics
    fn fl_topic() -> gossipsub::IdentTopic {
        gossipsub::IdentTopic::new("iiitd/fl-work")
    }
    fn l1_topic() -> gossipsub::IdentTopic {
        gossipsub::IdentTopic::new("iiitd/l1-blocks")
    }
    fn tx_topic() -> gossipsub::IdentTopic {
        gossipsub::IdentTopic::new("iiitd/transactions")
    }
}

#[async_trait]
impl Network for MeshNetwork {
    async fn start(&mut self) -> Result<(), BoxError> {
        info!("🌐 Starting libp2p Mesh Network (Gossipsub + mDNS)...");

        // 1. Create a cryptographic identity for this node
        let local_key = libp2p::identity::Keypair::generate_ed25519();
        let local_peer_id = libp2p::PeerId::from(local_key.public());
        info!("Local Peer ID: {}", local_peer_id);

        // 2. Setup Gossipsub (The Mesh Routing Protocol)
        let message_id_fn = |message: &gossipsub::Message| {
            let mut s = DefaultHasher::new();
            message.data.hash(&mut s);
            gossipsub::MessageId::from(s.finish().to_string())
        };

        // let gossipsub_config = gossipsub::ConfigBuilder
        //     ::default()
        //     .heartbeat_interval(std::time::Duration::from_secs(1))
        //     .message_id_fn(message_id_fn)
        //     .build()
        //     .map_err(|e| e.to_string())?;
        // Inside MeshNetwork::start() around line 76
        let gossipsub_config = gossipsub::ConfigBuilder
            ::default()
            .heartbeat_interval(std::time::Duration::from_secs(1))
            .max_transmit_size(15 * 1024 * 1024) // NEW: Allow up to 15 MB payloads
            .message_id_fn(message_id_fn)
            .build()
            .map_err(|e| e.to_string())?;

        let mut gossipsub = gossipsub::Behaviour
            ::new(gossipsub::MessageAuthenticity::Signed(local_key.clone()), gossipsub_config)
            .map_err(|e| e.to_string())?;

        // Subscribe to our blockchain topics
        gossipsub.subscribe(&Self::fl_topic()).unwrap();
        gossipsub.subscribe(&Self::l1_topic()).unwrap();
        gossipsub.subscribe(&Self::tx_topic()).unwrap();

        // 3. Setup mDNS (Local Peer Discovery)
        let mdns = mdns::tokio::Behaviour::new(mdns::Config::default(), local_peer_id)?;

        // 4. Build the Swarm
        let behaviour = MvmBehaviour { gossipsub, mdns };
        let mut swarm = SwarmBuilder::with_existing_identity(local_key)
            .with_tokio()
            .with_tcp(tcp::Config::default(), noise::Config::new, yamux::Config::default)?
            .with_quic()
            .with_behaviour(|_| behaviour)?
            .build();

        // Listen on all interfaces on the configured P2P port deterministically
        let listen_quic = format!("/ip4/0.0.0.0/udp/{}/quic-v1", self.config.network.p2p_port);
        let listen_tcp  = format!("/ip4/0.0.0.0/tcp/{}", self.config.network.p2p_port);
        swarm.listen_on(listen_quic.parse()?)?;
        swarm.listen_on(listen_tcp.parse()?)?;
        
        // Explicitly dial bootnodes if provided in TOML for internet P2P connectivity
        if let Some(boot_nodes) = &self.config.network.boot_nodes {
            for node_addr in boot_nodes {
                if let Ok(multiaddr) = node_addr.parse::<libp2p::Multiaddr>() {
                    info!("🔗 Dialing bootnode at {}", multiaddr);
                    if let Err(e) = swarm.dial(multiaddr.clone()) {
                        error!("Failed to dial {}: {}", multiaddr, e);
                    }
                } else {
                    tracing::warn!("⚠️ Invalid bootnode multiaddress format: {}", node_addr);
                }
            }
        }

        // Setup communication channels
        let (cmd_tx, mut cmd_rx) = mpsc::channel::<P2PMessage>(100);
        self.command_tx = Some(cmd_tx);

        let bc_clone = self.blockchain.clone();
        let state_clone = self.state.clone();
        let peers_clone = self.active_peers.clone();

        // 5. The Main Event Loop (Runs in the background)
        tokio::spawn(async move {
            loop {
                tokio::select! {
                    // Handle OUTBOUND broadcasts (from the Node to the Swarm)
                    Some(msg) = cmd_rx.recv() => {
                        let (topic, data) = match &msg {
                            P2PMessage::NewLatticeBlock(_) => (Self::l1_topic(), serde_json::to_vec(&msg).unwrap()),
                            P2PMessage::SubmitTx(_) => (Self::tx_topic(), serde_json::to_vec(&msg).unwrap()),
                            _ => continue,
                        };
                        
                        if let Err(e) = swarm.behaviour_mut().gossipsub.publish(topic, data) {
                            debug!("Failed to publish message: {:?}", e);
                        }
                    }

                    // Handle INCOMING events (from the Swarm to the Node)
                    event = swarm.select_next_some() => match event {
                        SwarmEvent::NewListenAddr { address, .. } => {
                            info!("📡 Node is listening on {}", address);
                        }
                        
                        SwarmEvent::ConnectionEstablished { peer_id, endpoint, .. } => {
                            info!("🔗 Connection established with peer ({:?}): {}", endpoint.get_remote_address(), peer_id);
                            swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer_id);
                            let mut peers = peers_clone.write().await;
                            if !peers.contains(&peer_id.to_string()) {
                                peers.push(peer_id.to_string());
                            }
                        }

                        SwarmEvent::ConnectionClosed { peer_id, .. } => {
                            info!("🔌 Connection closed with peer: {}", peer_id);
                            swarm.behaviour_mut().gossipsub.remove_explicit_peer(&peer_id);
                            let mut peers = peers_clone.write().await;
                            peers.retain(|p| p != &peer_id.to_string());
                        }

                        // mDNS discovered a new peer! Add them to the mesh.
                        SwarmEvent::Behaviour(MvmBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
                            for (peer_id, _multiaddr) in list {
                                info!("🔗 Discovered new local peer via mDNS: {}", peer_id);
                                swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer_id);
                                let mut peers = peers_clone.write().await;
                                if !peers.contains(&peer_id.to_string()) {
                                    peers.push(peer_id.to_string());
                                }
                            }
                        }
                        
                        // mDNS lost a peer
                        SwarmEvent::Behaviour(MvmBehaviourEvent::Mdns(mdns::Event::Expired(list))) => {
                            for (peer_id, _multiaddr) in list {
                                info!("🔌 Lost local mDNS peer: {}", peer_id);
                                swarm.behaviour_mut().gossipsub.remove_explicit_peer(&peer_id);
                                let mut peers = peers_clone.write().await;
                                peers.retain(|p| p != &peer_id.to_string());
                            }
                        }

                        // Gossipsub received a message from the mesh!
                        SwarmEvent::Behaviour(MvmBehaviourEvent::Gossipsub(gossipsub::Event::Message { message, .. })) => {
                            if let Ok(p2p_msg) = serde_json::from_slice::<P2PMessage>(&message.data) {
                                match p2p_msg {
                                    P2PMessage::NewLatticeBlock(block) => {
                                        info!("📡 Gossiped Lattice Block received");
                                        let mut bc = bc_clone.write().await;
                                        bc.add_lattice_block(block);
                                    }
                                    _ => {}
                                }
                            }
                        }
                        _ => {}
                    }
                }
            }
        });

        Ok(())
    }

    async fn broadcast_lattice_block(&self, block: &LatticeBlock) -> Result<(), BoxError> {
        if let Some(tx) = &self.command_tx {
            let _ = tx.send(P2PMessage::NewLatticeBlock(block.clone())).await;
        }
        Ok(())
    }

    async fn broadcast_tx(&self, transaction: &Transaction) -> Result<(), BoxError> {
        if let Some(tx) = &self.command_tx {
            let _ = tx.send(P2PMessage::SubmitTx(transaction.clone())).await;
        }
        Ok(())
    }

    async fn get_active_peer_ids(&self) -> Vec<String> {
        let peers = self.active_peers.read().await;
        peers.clone()
    }

    fn peer_count(&self) -> usize {
        self.active_peers
            .try_read()
            .map(|p| p.len())
            .unwrap_or(0)
    }

    fn browser_count(&self) -> usize {
        0 // WebRTC integration needed for browsers later
    }
}
