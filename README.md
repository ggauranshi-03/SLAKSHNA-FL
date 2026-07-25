# SLAKSHNA — Decentralized Geo-Localised Personalized Federated Learning

A **Peer-to-Peer Federated Learning Framework** enabled by an asynchronous Layer-1 blockchain built in **Rust** and integrated with a high-performance Python Machine Learning Engine (**Bhaskera**). **SLAKSHNA** enables decentralized, privacy-preserving, trust-weighted Federated Learning (FL) without centralized aggregators or synchronous blocking rounds. It runs across geo-localized machines and institutional clusters (including SLURM GPU supercomputers) separated by complex firewalls, securely sharing compressed model updates without any central coordinator.

---

## Key Features & Architectural Highlights

- **Asynchronous Model-Lattice (Layer-1 Blockchain)**  
  Instead of traditional synchronous FL rounds (`FedAvg`) that block waiting for slow participants, SLAKSHNA operates as an asynchronous DAG lattice. Nodes continuously train on local data, broadcast compressed model deltas inside `ModelProposal` blocks, and evaluate peers asynchronously.

- **Iroh QUIC Mesh & Gossip Network (`iroh-gossip`)**  
  Built on modern **Iroh v1.0.2**, the framework utilizes **QUIC** transport, direct NAT traversal (STUN/DERP), and `iroh-gossip` topic swarms (`iiitd/l1-blocks`). Nodes discover peers dynamically using cryptographic Ed25519 `NodeId` public keys.

- **Universal Firewall & VPN Traversal (`Playit.gg`)**  
  Academic and enterprise networks (such as IIITD campus firewalls or remote VPNs) often block inbound UDP/TCP hole-punching and standard DERP relay traffic. SLAKSHNA natively supports static public UDP/TCP tunneling via **Playit.gg**, providing fixed, persistent public addresses (`<ip>:<port>`) for nodes across different cities without requiring root/sudo access or complex router configurations.

- **Bhaskera ML Engine (`ml_engine.py`)**  
  A robust Python engine bridging the Rust blockchain with distributed GPU/CPU training. Powered by **Ray Train (`TorchTrainer`)**, **PyTorch**, and **HuggingFace PEFT (LoRA)**, it executes local fine-tuning on tokenized datasets while streaming real-time epoch loss tracking.

- **SLURM Supercomputer & Multi-Core Cluster Support**  
  Fully compatible with academic SLURM clusters (`srun` / `sbatch`). Because SLURM isolates allocated GPUs inside containers where the index is always `CUDA_VISIBLE_DEVICES=0`, SLAKSHNA's node configuration (`gpu_id`) seamlessly maps to cluster-assigned resources without port collisions or resource deadlocks.

- **Reputation & Trust-Weighted Aggregation**  
  Peers asynchronously evaluate incoming model proposals (`LatticeBlockType::Evaluation`) by computing cosine similarity against their local gradient direction and tracking validation loss improvements. Nodes dynamically update peer trust scores (`state["alpha"]` and normalized `w_i` weights).

- **Dynamic Committee Election & Poisoning Defense**  
  On-chain evaluations are aggregated across the lattice (`Blockchain::get_elected_committee`). Top reputation nodes are elected to the validator committee, while malicious or poisoning nodes (e.g., nodes injecting destructive learning rates or random noise) are automatically filtered out and slashed.

- **Top-K Sparsification (`SparseLoCo`) & Bandwidth Compression**  
  Before broadcasting over the P2P network, local LoRA weight updates are sparsified to retain only the top 1% most significant weights (`sparsity=0.01`). The sparse tensors are half-precision encoded (`fp16`) and base64 compressed, slashing network bandwidth requirements by over 98%.

- **Differential Privacy (DP)**  
  Integrated with `opacus` (`PrivacyEngine`) and `opt-einsum` to ensure local gradients are cryptographically protected against membership inference and model inversion attacks.

---

## Security & Privacy Architecture

SLAKSHNA is built from the ground up to operate securely over untrusted public networks, proxies, and shared supercomputers:

1. **End-to-End Cryptographic Transport (`TLS 1.3 over QUIC`)**  
   Every node generates an `Ed25519` cryptographic keypair upon startup (`src/network/mesh.rs`). All communication across the Iroh mesh—whether sent directly via local IPs or routed across public internet tunnels like `Playit.gg`—is wrapped in end-to-end **TLS 1.3** encryption.
   - **Zero-Trust Tunnels:** Public proxy services (`Playit.gg`) act purely as raw packet forwarders ("dumb pipes"). They cannot read, decrypt, or tamper with model weights or blockchain blocks because they do not hold the private keys.
   
2. **Cryptographic Block Signatures & Validation**  
   Every `LatticeBlock` (`Proposal` or `Evaluation`) is hashed and cryptographically signed (`LatticeBlock::sign`) by the authoring node's Ed25519 private key. Receiving nodes strictly verify signatures (`LatticeBlock::verify`) before admitting blocks into the local RocksDB chain state.

3. **Byzantine Fault Tolerant (BFT) Poisoning Defense**  
   To prevent adversarial nodes from ruining the global model (`Model Poisoning`), SLAKSHNA does not use simple averaging. When a node receives a peer's delta, `ml_engine.py` evaluates the proposal against local validation metrics (`Cosine Similarity` & `Validation Loss`). If a node submits poisoned or erratic updates, its trust score (`alpha`) drops, rendering its weight in the Federated Averaging formula close to `0.0`.

4. **Differential Privacy against Data Reconstruction**  
   By combining `SparseLoCo` (sharing only 1% of fine-tuned LoRA weights) with `Opacus` gradient clipping and noise injection, raw local dataset samples (`ultrachat`, patient records, etc.) can never be reconstructed by eavesdroppers or peer nodes.

---

## System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Axum HTTP & WS Server                           │
│               (Node Status, Block Queries, Leaderboard)                │
├──────────────────────────────────┬─────────────────────────────────────┤
│         Rust L1 Engine           │           Python ML Engine          │
│                                  │                                     │
│  • Iroh Mesh & Gossip Consensus  │  • ml_engine.py Bridge              │
│  • Committee Election (Trust)    │  • Bhaskera (Ray Train / PyTorch)   │
│  • RocksDB State Persistence     │  • LoRA Fine-Tuning & SparseLoCo    │
│  • Asynchronous Evaluation       │  • Opacus Differential Privacy      │
├──────────────────────────────────┴─────────────────────────────────────┤
│            Iroh Network (`iroh-gossip` topic `iiitd/l1-blocks`)        │
│          (QUIC / Ed25519 TLS 1.3 / mDNS / STUN / Playit.gg)            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Layer | Technologies Used |
| :--- | :--- |
| **Core Blockchain** | **Rust** (`edition = 2021`), **Tokio** async runtime, **RocksDB** (`librocksdb-sys`) |
| **P2P Networking** | **Iroh** (`iroh v1.0.2`, `iroh-gossip`, `iroh-relay`), **QUIC**, **Ed25519 TLS 1.3**, **Playit.gg** (Static Tunnels) |
| **API & WebSockets** | **Axum 0.7**, **Hyper**, **tokio-tungstenite** (`WebSocket`), **Serde / Serde JSON** |
| **ML Engine & FL** | **Python 3.11+**, **PyTorch**, **Ray / Ray Train** (`ray.train.torch.TorchTrainer`), **setproctitle** |
| **Transformers & PEFT** | **HuggingFace Transformers**, **PEFT** (`LoRA`), **PyArrow** (Parquet caching), **PyYAML** |
| **Differential Privacy** | **Opacus** (`PrivacyEngine`), **opt-einsum**, **SciPy**, **NumPy** |

---

## Repository Structure

| Path | Description |
| :--- | :--- |
| `src/main.rs` | Node entry point, phase execution, ML process orchestration (`spawn` streaming), and lattice broadcast |
| `src/chain.rs` | L1 `LatticeBlock` definitions (`Proposal`, `Evaluation`), hash calculations, and committee election |
| `src/state.rs` | RocksDB persistence layer (`State`, `StateSnapshot`) for lattice DAG blocks and accounts |
| `src/network/` | Iroh QUIC + Gossip network implementation (`mesh.rs`, `mod.rs`, `star.rs`) for peer synchronization |
| `src/api.rs` | Axum HTTP REST endpoints and real-time WebSocket broadcast server |
| `src/config.rs` | TOML configuration loader for chain parameters, network ports, and storage paths |
| `ml_engine.py` | Python bridge executing Bhaskera distributed LoRA training, sparsification (`SparseLoCo`), and evaluation |
| `Bhaskera/` | Submodule / embedded repository containing the Bhaskera distributed LLM training framework |
| `config.toml` | Master/Node-1 configuration file |
| `node2.toml` / `node3.toml` | Peer node configuration files |

---

## Environment & Prerequisites Setup

When setting up on a machine where Rust, Cargo, or Python are installed in custom directories (such as `/mnt/disk1/...` or scratch drives), export your environment variables before compiling or running:

```bash
# 1. Point to your Rust & Cargo installation
export CARGO_HOME=/mnt/disk1/slakshna/rust/.cargo
export RUSTUP_HOME=/mnt/disk1/slakshna/rust/.rustup
export PATH=$CARGO_HOME/bin:$PATH

# 2. Activate Python Environment
if [ -f "/mnt/disk1/slakshna/Bhaskera/bhaskera-activate.sh" ]; then
    source /mnt/disk1/slakshna/Bhaskera/bhaskera-activate.sh
elif [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
fi
```

### Installation & Build

```bash
# Upgrade pip and install core ML/FL dependencies
pip install --upgrade pip
pip install torch torchvision numpy scipy opt-einsum opacus pyarrow ray pyyaml setproctitle toml

# Build the Rust Layer-1 node binary in release mode
cargo build --release
```

---

## TOML Configuration Breakdown

Every node requires its own `.toml` configuration file (`config.toml`, `node2.toml`, etc.).

### Master Node (`config.toml`)
```toml
[node]
id = "node-1"
type = "master"
data_dir = "./data-node1"   # Dedicated RocksDB and delta storage directory
gpu_id = 0                  # GPU assigned to this node for local training

[network]
topology = "mesh"
host = "0.0.0.0"
p2p_port = 9000             # Iroh QUIC router listening port
api_port = 8545             # Axum HTTP REST API port
ws_port = 8546              # WebSocket port
boot_nodes = []             # Master has no initial boot nodes
```

### Remote Peer Node (`node2.toml` / `node3.toml`)
When connecting a remote node over the internet or across campuses, point `boot_nodes` directly to the Master Node's **Ed25519 `NodeId`** (printed by the master node upon startup) or its public static tunnel (`Playit.gg`):

```toml
[node]
id = "node-2"
type = "full"
data_dir = "./data-node2"   # MUST be unique per node
gpu_id = 0                  # Set to 0 if running inside SLURM (--gres=gpu:1), or 1 if multi-GPU server

[network]
topology = "mesh"
host = "0.0.0.0"
p2p_port = 9001             
api_port = 8555             
ws_port = 8547              

# Point boot_nodes to the Master Node's Iroh PublicKey (NodeId):
# Iroh automatically discovers the route via direct IP, mDNS, STUN, or public Playit tunnel
boot_nodes = ["<MASTER_IROH_PUBLIC_KEY>@<tunnel address>"]
```

---

## Running the System across Geo-Localized Machines

If your machines are located in different cities (e.g., Delhi $\leftrightarrow$ Mumbai) and are separated by strict university or corporate firewalls (NAT/Deep Packet Inspection) that block peer-to-peer discovery, you must use a reverse proxy tunnel.

**What is Playit.gg?**  
[Playit.gg](https://playit.gg) is a service that creates a secure outbound tunnel from your local machine to a public cloud server. It gives your local node a static public IP address on the internet, completely bypassing incoming firewall restrictions. Because SLAKSHNA uses Iroh (End-to-End Encryption), passing data through Playit's public servers is 100% secure.

### Step 1: Start the Playit Tunnel (Main Machine)
*You must run this on your "Main Machine" (e.g., Delhi server) **before** starting the SLAKSHNA node.*

1. Install `playit` on the main machine.
2. Start the Playit daemon (e.g., `cd ~/playit && ./playit start`).
3. Follow the CLI prompt to create a tunnel. Create a **UDP/TCP tunnel** pointing to your local Iroh `p2p_port` (e.g., `9000` or `9001` based on your config).
4. Playit will assign you a public endpoint. **Note down this IP and Port** (e.g., `147.185.221.225:42060`).

### Step 2: Start the Master Node (Main Machine)
With the tunnel running in the background, start your node:
```bash
./target/release/iiitd --config config.toml
```
When started, the node will output its unique cryptographic Iroh `NodeId` (Public Key):
```
INFO 🔑 Iroh NodeId: a65a49db0894467a3b6d95eda3924c309a5589e265f734332f2b65100364be90
```

### Step 3: Connect Peer Nodes (e.g., Mumbai Machine)
On your secondary machines, open their TOML configuration file (e.g., `node2.toml`).

You need to tell this machine exactly how to reach the Main Machine. Combine the **NodeId** (from Step 2) and the **Playit Public IP:Port** (from Step 1) using the format `<node_id>@<playit_ip>:<playit_port>`.

Update the `boot_nodes` field:
```toml
[network]
# Format: ["<NodeId>@<Playit_IP>:<Playit_Port>"]
boot_nodes = ["a65a49db0894467a3b6d95eda3924c309a5589e265f734332f2b65100364be90@147.185.221.225:42060"]
```

Now, start the peer node:
```bash
./target/release/iiitd --config node2.toml
```
The peer node will dial the public Playit IP, encrypt the traffic using the NodeId, and establish a direct connection to the main machine!

---

## Running on Academic SLURM Supercomputers

When deploying SLAKSHNA on a SLURM cluster login node:
1. **Never run directly on the login node without a GPU allocation**, as `torch.cuda.is_available()` will fail (`no GPUs found!`).
2. **Set `gpu_id = 0` in your `.toml` file.** When SLURM allocates a physical GPU (`rpgpu[...]`) to your job, it maps that card inside the container to `CUDA_VISIBLE_DEVICES=0`.
3. **Launch the node using `srun` on the GPU partition:**
   ```bash
   srun -p gpu --gres=gpu:1 --time=04:00:00 ./target/release/iiitd --config config.toml
   ```

---

## HTTP REST & WebSocket API

The node exposes an Axum-powered API for monitoring lattice blocks, trust evaluations, and system status:

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/status` | Returns chain height, active Iroh P2P peer count, and node status |
| `GET` | `/blocks?limit=N` | Returns list of recent `Proposal` and `Evaluation` blocks |
| `GET` | `/block/latest` | Query latest L1 consensus status |
| `GET` | `/leaderboard` | Returns active node reputation and trust score rankings (`alpha` / `w_i`) |
| `WS` | `ws://localhost:8546/ws` | Live WebSocket stream emitting new blocks and peer evaluation updates |

---

## Testing Model Poisoning & Defense

You can simulate a malicious node attempting to poison the Federated Learning consensus by setting the `MALICIOUS_NODES` environment variable:

```bash
MALICIOUS_NODES="node-2" ./target/release/iiitd --config node2.toml
```

When `node-2` runs in malicious mode, it injects a destructive learning rate (`learning_rate = 1.0`). When `node-1` receives `node-2`'s proposal, `ml_engine.py` computes cosine similarity and observes negative alignment. `node-1` automatically slashes `node-2`'s trust score and excludes it from the validator committee (`get_elected_committee`).

---

## 📄 License

This project is licensed under the **Apache License 2.0** — see the [LICENSE](file:///mnt/disk1/slakshna/slakshnaFL/SLAKSHNA/LICENSE) file for details.
