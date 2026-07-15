# SLAKSHNA-FL — Decentralized Geo-localised Personalized Federated Learning

An **Asynchronous Layer-1 Model-Lattice Blockchain** built in Rust and integrated with a high-performance Python Machine Learning Engine (**Bhaskera**). **SLAKSHNA-FL** enables decentralized, privacy-preserving, trust-weighted Federated Learning (FL) without centralized aggregators or synchronous blocking rounds.

---

## 🌟 Key Features

- **Asynchronous Model-Lattice (Layer-1 Blockchain)**  
  Instead of traditional synchronous FL rounds (`FedAvg`) that block waiting for slow participants, SLAKSHNA-FL operates as an asynchronous lattice. Nodes continuously train on local data, broadcast compressed model deltas inside `ModelProposal` blocks, and evaluate peers asynchronously.
  
- **Bhaskera ML Engine (`ml_engine.py`)**  
  A robust Python engine bridging the Rust blockchain with distributed GPU/CPU training. Powered by **Ray Train (`TorchTrainer`)**, **PyTorch**, and **HuggingFace PEFT (LoRA)**, it executes local fine-tuning on tokenized datasets with real-time epoch loss tracking.

- **Reputation & Trust-Weighted Aggregation**  
  Peers asynchronously evaluate incoming model proposals (`LatticeBlockType::Evaluation`) by computing cosine similarity against their local gradient direction and tracking validation loss improvements. Nodes dynamically update peer trust scores (`state["alpha"]` and normalized `w_i` weights).

- **Dynamic Committee Election & Poisoning Defense**  
  On-chain evaluations are aggregated across the lattice (`Blockchain::get_elected_committee`). Top reputation nodes are elected to the validator committee, while malicious or poisoning nodes (e.g., nodes injecting destructive learning rates) are automatically filtered out.

- **Top-K Sparsification (`SparseLoCo`) & Compression**  
  Before broadcasting over the P2P network, local LoRA weight updates are sparsified to retain only the top 1% most significant weights (`sparsity=0.01`). The sparse tensors are half-precision encoded (`fp16`) and base64 compressed to minimize network bandwidth (`iiitd/l1-blocks` gossip topic).

- **Differential Privacy (DP)**  
  Integrated with `opacus` (`PrivacyEngine`) and `opt-einsum` to ensure local gradients are cryptographically protected against membership inference and data reconstruction attacks.

- **Libp2p Star & Mesh Networking**  
  Built with Rust `libp2p` featuring TCP/QUIC transports, Noise encryption, Yamux multiplexing, Gossipsub message propagation, mDNS local discovery, and UPnP NAT traversal for over-the-internet deployment.

---

## 🏗️ System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Axum HTTP & WS Server                           │
│               (Node Status, Block Queries, Leaderboard)                │
├──────────────────────────────────┬─────────────────────────────────────┤
│         Rust L1 Engine           │           Python ML Engine          │
│                                  │                                     │
│  • LatticeBlock & Consensus      │  • ml_engine.py Bridge              │
│  • Committee Election (Trust)    │  • Bhaskera (Ray Train / PyTorch)   │
│  • RocksDB State & Blockchain    │  • LoRA Fine-Tuning & SparseLoCo    │
│  • Asynchronous Evaluation       │  • Opacus Differential Privacy      │
├──────────────────────────────────┴─────────────────────────────────────┤
│               Libp2p Network (Gossipsub `iiitd/l1-blocks`)             │
│                      (TCP / QUIC / mDNS / UPnP)                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Technology Stack

| Layer | Technologies Used |
| :--- | :--- |
| **Core Blockchain** | **Rust** (`edition = 2021`), **Tokio** async runtime, **RocksDB** (`librocksdb-sys`) |
| **P2P Networking** | **Libp2p** (`v0.53`), **QUIC** (`libp2p-quic`), **Gossipsub**, **Noise** cryptography, **mDNS**, **UPnP**, **bore** (tunneling) |
| **API & WebSockets** | **Axum 0.7**, **Hyper**, **tokio-tungstenite** (`WebSocket`), **Serde / Serde JSON** |
| **ML Engine & FL** | **Python 3.11+**, **PyTorch**, **Ray / Ray Train** (`ray.train.torch.TorchTrainer`), **setproctitle** |
| **Transformers & PEFT** | **HuggingFace Transformers**, **PEFT** (`LoRA`), **PyArrow** (Parquet caching), **PyYAML** |
| **Differential Privacy** | **Opacus** (`PrivacyEngine`), **opt-einsum**, **SciPy**, **NumPy** |

---

## 📁 Repository Structure

| Path | Description |
| :--- | :--- |
| `src/main.rs` | Node entry point, environment setup, Phase A local training loop & lattice broadcast |
| `src/chain.rs` | L1 `LatticeBlock` definitions (`ModelProposal`, `Evaluation`), trust scoring & committee election |
| `src/state.rs` | RocksDB persistence layer (`State`, `StateSnapshot`) for lattice blocks and accounts |
| `src/network/` | Libp2p network implementation (`star.rs`, `mesh.rs`, `mod.rs`) for P2P synchronization |
| `src/api.rs` | Axum HTTP REST endpoints and real-time WebSocket broadcast server |
| `src/config.rs` | TOML configuration loader for chain parameters, network ports, and storage paths |
| `ml_engine.py` | Python bridge executing Bhaskera distributed LoRA training, sparsification, and evaluation |
| `Bhaskera/` | Submodule / embedded repository containing the Bhaskera distributed LLM training launcher |
| `setup.sh` | Automated setup script initializing Python venv, dependencies, and compiling the Rust binary |
| `deploy.sh` | Automated Docker & Nginx deployment script for cloud VPS / DigitalOcean Droplets |
| `config.toml` | Master node configuration file (ports `8545`/`9000`) |
| `node2.toml` / `node3.toml` | Slave/peer node configuration files for multi-node simulation |

---

## 🔧 Environment Setup (PATH & Variables)

When setting up on a machine where Rust, Cargo, or Python are installed in non-standard directories (such as `/mnt/disk1/...`), configure your environment variables first before running or compiling:

```bash
# 1. Point to correct Rust & Cargo paths
export CARGO_HOME=/mnt/disk1/slakshna/rust/.cargo
export RUSTUP_HOME=/mnt/disk1/slakshna/rust/.rustup
export PATH=$CARGO_HOME/bin:$PATH

# 2. Activate Python Environment (Bhaskera or local .venv)
if [ -f "/mnt/disk1/slakshna/Bhaskera/bhaskera-activate.sh" ]; then
    source /mnt/disk1/slakshna/Bhaskera/bhaskera-activate.sh
elif [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
fi
```

To make these environment exports permanent, append them to your `~/.bashrc` or `~/.profile`.

---

## 🚀 Quick Start & Setup

### 1. Automated Setup (`setup.sh`)
The easiest way to prepare Python dependencies and build the Rust L1 binary:

```bash
chmod +x setup.sh
./setup.sh
```

### 2. Manual Setup
After setting up your environment variables (above), compile the Rust node:

```bash
# Upgrade pip and install core ML/FL dependencies
pip install --upgrade pip
pip install torch torchvision numpy scipy opt-einsum opacus pyarrow ray pyyaml setproctitle

# Build the Rust Layer-1 engine in release mode
cargo build --release
```

---

## ⚙️ TOML Configuration Breakdown

Every node requires a `.toml` configuration file (`config.toml`, `node2.toml`, `node3.toml`). 

### Master Node (`config.toml`)
The bootstrap / master node typically runs on default ports and binds to GPU 0:
```toml
[node]
id = "node-1"
type = "master"
data_dir = "./data-node1"   # Dedicated RocksDB storage directory
gpu_id = 0                  # GPU assigned to this node for local training

[network]
topology = "mesh"
host = "0.0.0.0"
p2p_port = 9000             # Master P2P listening port
api_port = 8545             # Master REST API port
ws_port = 8546              # Master WebSocket port
boot_nodes = []             # Master has no boot nodes

[network.star]
master_url = ""             # Empty for master node
```

### Peer / Slave Nodes (`node2.toml` & `node3.toml`)
When running additional nodes, **each node must have a unique `data_dir`, `gpu_id`, and unique ports** (`api_port`, `ws_port`, `p2p_port`) to prevent address binding conflicts and RocksDB lock errors. Additionally, peer nodes specify the master node via `boot_nodes` and `master_url`:

```toml
# Example for Node 2 (node2.toml)
[node]
id = "node-2"
type = "full"
data_dir = "./data-node2"   # MUST be unique (e.g., ./data-node2, ./data-node3)
gpu_id = 1                  # Assign distinct GPU (e.g., 1, 2)

[network]
topology = "mesh"
host = "0.0.0.0"
p2p_port = 9001             # Unique P2P port per node (9001, 9002...)
api_port = 8555             # Unique API port per node (8555, 8565...)
ws_port = 8547              # Unique WS port per node

# Connect to the master node's P2P address:
boot_nodes = ["/ip4/192.168.22.23/tcp/9000"]   # Or /ip4/127.0.0.1/tcp/9000 if local

[network.star]
# Connect to the master node's HTTP API endpoint:
master_url = "http://192.168.22.23:8545"       # Or http://127.0.0.1:8545 if local
```

---

## 🖥️ Running the System Locally

### Standalone Master Node
```bash
./target/release/iiitd --config config.toml
```

### Multi-Node Local Lattice Simulation
Open separate terminal windows on your machine, activate your environment, and start each node:

```bash
# Terminal 1 — Master / Bootstrap Node (`config.toml` on ports 8545 / 9000)
./target/release/iiitd --config config.toml

# Terminal 2 — Peer Node 2 (`node2.toml` on ports 8555 / 9001)
./target/release/iiitd --config node2.toml

# Terminal 3 — Peer Node 3 (`node3.toml` on ports 8565 / 9002)
./target/release/iiitd --config node3.toml
```

---

## 🌍 Over-the-Internet P2P Networking (`bore` Tunnels)

When deploying nodes across different physical machines behind firewalls or NATs (without public IPs), you can use [bore](https://github.com/ekzhang/bore) (`bore-cli`) to expose local ports to the internet over public tunneling servers.

### Step 1: Expose Master Node Ports via `bore`
On the machine hosting the **Master Node (`config.toml`)**, open tunnels for both the P2P port (`9000`) and the API port (`8545`):

```bash
# Terminal A: Expose Master P2P Port (9000)
bore local 9000 --to bore.pub
# Output: listening at bore.pub:34812 (Save this assigned port!)

# Terminal B: Expose Master API Port (8545)
bore local 8545 --to bore.pub
# Output: listening at bore.pub:41205 (Save this assigned port!)
```

### Step 2: Configure Remote Peer Nodes Over the Internet
On the remote machine hosting Node 2 or Node 3, edit your `.toml` configuration file (`node2.toml`) to use the public `bore.pub` addresses:

```toml
[network]
# Point boot_nodes to the bore tunnel for port 9000 (/dns4/<domain>/tcp/<assigned_port>):
boot_nodes = ["/dns4/bore.pub/tcp/34812"]

[network.star]
# Point master_url to the bore tunnel for port 8545 (http://<domain>:<assigned_port>):
master_url = "http://bore.pub:41205"
```

Then start the remote peer node normally:
```bash
./target/release/iiitd --config node2.toml
```
The remote node will connect over the internet directly into your master node's P2P lattice!

---

## 🌐 HTTP REST & WebSocket API

The node exposes an Axum-powered API for monitoring lattice blocks, trust evaluations, and system status:

### General & Node Status
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/` | Basic node info & API welcome |
| `GET` | `/status` | Returns chain height, active P2P peer count, browser websocket connections, and node type |

### Lattice Block Queries
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/block/:height` | Query L1 Lattice Block status (or not implemented note if L2 queried) |
| `GET` | `/block/latest` | Query latest L1 status |
| `GET` | `/blocks?limit=N` | Returns list of recent lattice blocks |

### Reputation & Rankings
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/leaderboard` | Returns active account / node reputation rankings |

### Real-Time WebSockets
| Endpoint | Description |
| :--- | :--- |
| `ws://localhost:8545/ws` | Live WebSocket subscription emitting new blocks, node status events, and peer updates |

---

## ☁️ Production Deployment (`deploy.sh`)

To deploy the node to a cloud VPS (e.g., DigitalOcean Droplet, AWS EC2) with Docker, Nginx, and automated Let's Encrypt SSL:

```bash
# Run on the cloud server as root
chmod +x deploy.sh
./deploy.sh
```

### Useful Docker Commands:
```bash
# Check running containers
docker compose ps

# View live backend logs
docker compose logs -f backend

# Restart services without rebuilding
docker compose restart backend

# Full clean rebuild
docker compose up -d --build --force-recreate
```

---

## 🔒 Security & Malicious Node Testing

SLAKSHNA-FL includes built-in defense testing against model poisoning attacks. You can designate specific nodes as malicious via environment variables:

```bash
# Run Node 2 as a malicious poisoning node (injects destructive learning rates)
MALICIOUS_NODES="node-2" ./target/release/iiitd --config node2.toml
```

During training, honest nodes (`node-1`, `node-3`) will evaluate `node-2`'s proposal via cosine similarity in `ml_engine.py`, observe a drop in alignment, slash its `state["alpha"]` trust score, and exclude `node-2` from the elected validator committee (`get_elected_committee`).

---

## 📄 License

This project is licensed under the **Apache License 2.0** — see the [LICENSE](file:///mnt/disk1/slakshna/slakshnaFL/SLAKSHNA/LICENSE) file for details.
