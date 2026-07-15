#!/usr/bin/env bash
set -e

echo "=== 1. Setting up Python Environment ==="
# Check if Bhaskera central activation script exists
if [ -f "/mnt/disk1/slakshna/Bhaskera/bhaskera-activate.sh" ]; then
    echo "🔍 Detected Bhaskera environment! Activating via /mnt/disk1/slakshna/Bhaskera/bhaskera-activate.sh..."
    source /mnt/disk1/slakshna/Bhaskera/bhaskera-activate.sh
elif [ -f "../../Bhaskera/bhaskera-activate.sh" ]; then
    echo "🔍 Detected Bhaskera environment! Activating via ../../Bhaskera/bhaskera-activate.sh..."
    source ../../Bhaskera/bhaskera-activate.sh
elif [ -f "../Bhaskera/bhaskera-activate.sh" ]; then
    echo "🔍 Detected Bhaskera environment! Activating via ../Bhaskera/bhaskera-activate.sh..."
    source ../Bhaskera/bhaskera-activate.sh
else
    echo "📦 Creating local Python virtual environment (.venv)..."
    python3 -m venv .venv
    source .venv/bin/activate
fi

pip install --upgrade pip
pip install torch torchvision numpy scipy opt-einsum opacus pyarrow ray pyyaml

echo "=== 2. Preparing Directories ==="
mkdir -p data logs ml_models ml_states t

echo "=== 3. Compiling Rust L1 Engine (Without Layer-2 Blockchain) ==="
cargo build --release

echo "=========================================================="
echo "✅ Setup complete for Slakshna (Layer-1 FL over Bhaskera)!"
echo "To start your node:"
echo "  1. Activate environment: source /mnt/disk1/slakshna/Bhaskera/bhaskera-activate.sh (or local .venv)"
echo "  2. Run the engine: ./target/release/iiitd --config <your_node_config.toml>"
echo "=========================================================="
