use crate::chain::{ LatticeBlock, Blockchain, BoxError };
use crate::network::Network;
use crate::state::State;
use crate::network::star::P2PMessage;
use async_trait::async_trait;

use iroh_net::{Endpoint, ticket::NodeTicket};
use iroh_gossip::net::{Gossip, Event as GossipEvent};

use std::sync::Arc;
use std::str::FromStr;
use tokio::sync::{ RwLock, mpsc };
use tracing::{ info, error, debug };
use futures::StreamExt;

pub struct MeshNetwork {
    config: crate::config::Config,
    blockchain: Arc<RwLock<Blockchain>>,
    state: Arc<RwLock<State>>,
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

    fn fl_topic() -> [u8; 32] {
        let hash = blake3::hash(b"iiitd-slakshna-fl-work");
        *hash.as_bytes()
    }
}

#[async_trait]
impl Network for MeshNetwork {
    async fn start(&mut self) -> Result<(), BoxError> {
        info!("🌐 Starting Iroh Mesh Network (QUIC + Gossip)...");

        let endpoint = Endpoint::builder().bind(0).await?;
        let local_node_id = endpoint.node_id();
        info!("Local Node ID: {}", local_node_id);
        
        let my_addr = endpoint.node_addr().await?;
        let ticket = NodeTicket::new(my_addr.clone())?;
        info!("🎟️ Iroh Ticket (Use this as boot_node on other machines):\n{}", ticket);

        let gossip = Gossip::from_endpoint(endpoint.clone(), Default::default(), &my_addr.info);

        let topic = Self::fl_topic();
        let mut receiver = gossip.subscribe(topic.into()).await?;

        let (cmd_tx, mut cmd_rx) = mpsc::channel::<P2PMessage>(100);
        self.command_tx = Some(cmd_tx);

        let bc_clone = self.blockchain.clone();
        let _state_clone = self.state.clone();
        let peers_clone = self.active_peers.clone();
        let gossip_clone = gossip.clone();

        if let Some(boot_nodes) = &self.config.network.boot_nodes {
            for ticket_str in boot_nodes {
                if let Ok(ticket) = NodeTicket::from_str(ticket_str) {
                    info!("🔗 Dialing bootnode via ticket: {}", ticket.node_addr().node_id);
                    if let Err(e) = endpoint.add_node_addr(ticket.node_addr().clone()) {
                        error!("Failed to add bootnode addr: {}", e);
                    }
                } else {
                    tracing::warn!("⚠️ Invalid Iroh ticket format: {}", ticket_str);
                }
            }
        }

        tokio::spawn(async move {
            loop {
                tokio::select! {
                    Some(msg) = cmd_rx.recv() => {
                        let data = match &msg {
                            P2PMessage::NewLatticeBlock(_) => serde_json::to_vec(&msg).unwrap(),
                            _ => continue,
                        };
                        if let Err(e) = gossip_clone.broadcast(Self::fl_topic().into(), data.into()).await {
                            debug!("Failed to broadcast: {:?}", e);
                        }
                    }

                    event_res = receiver.recv() => {
                        let event_res: Result<GossipEvent, _> = event_res;
                        match event_res {
                            Ok(event) => match event {
                                GossipEvent::Received(msg) => {
                                    if let Ok(p2p_msg) = serde_json::from_slice::<P2PMessage>(&msg.content) {
                                        match p2p_msg {
                                            P2PMessage::NewLatticeBlock(block) => {
                                                info!("📡 Gossiped Lattice Block received from {}", msg.delivered_from);
                                                let mut bc = bc_clone.write().await;
                                                bc.add_lattice_block(block);
                                            }
                                            _ => {}
                                        }
                                    }
                                }
                                GossipEvent::NeighborUp(node_id) => {
                                    info!("🔗 Neighbor connected: {}", node_id);
                                    let mut peers = peers_clone.write().await;
                                    if !peers.contains(&node_id.to_string()) {
                                        peers.push(node_id.to_string());
                                    }
                                }
                                GossipEvent::NeighborDown(node_id) => {
                                    info!("🔌 Neighbor disconnected: {}", node_id);
                                    let mut peers = peers_clone.write().await;
                                    peers.retain(|p| p != &node_id.to_string());
                                }
                                _ => {}
                            },
                            Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                            Err(e) => error!("Gossip receiver error: {:?}", e),
                        }
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

    async fn get_active_peer_ids(&self) -> Vec<String> {
        let peers = self.active_peers.read().await;
        peers.clone()
    }

    fn peer_count(&self) -> usize {
        self.active_peers.try_read().map(|p| p.len()).unwrap_or(0)
    }

    fn browser_count(&self) -> usize {
        0
    }
}
