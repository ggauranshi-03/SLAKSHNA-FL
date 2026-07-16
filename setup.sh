#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. Setting up Python Environment ==="
# Check if Bhaskera central activation script exists relative to workspace
if [ -f "$SCRIPT_DIR/../../Bhaskera/bhaskera-activate.sh" ]; then
    ACTIVATE_PATH="$SCRIPT_DIR/../../Bhaskera/bhaskera-activate.sh"
    echo "🔍 Detected Bhaskera environment! Activating via $ACTIVATE_PATH..."
    source "$ACTIVATE_PATH"
elif [ -f "$SCRIPT_DIR/../Bhaskera/bhaskera-activate.sh" ]; then
    ACTIVATE_PATH="$SCRIPT_DIR/../Bhaskera/bhaskera-activate.sh"
    echo "🔍 Detected Bhaskera environment! Activating via $ACTIVATE_PATH..."
    source "$ACTIVATE_PATH"
elif [ -f "$SCRIPT_DIR/bhaskera-activate.sh" ]; then
    ACTIVATE_PATH="$SCRIPT_DIR/bhaskera-activate.sh"
    echo "🔍 Detected Bhaskera environment! Activating via $ACTIVATE_PATH..."
    source "$ACTIVATE_PATH"
else
    ACTIVATE_PATH="$SCRIPT_DIR/.venv/bin/activate"
    echo "📦 Creating local Python virtual environment (.venv)..."
    python3 -m venv "$SCRIPT_DIR/.venv"
    source "$ACTIVATE_PATH"
fi

pip install --upgrade pip
pip install torch torchvision numpy scipy opt-einsum opacus pyarrow ray pyyaml

echo "=== 2. Preparing Directories ==="
mkdir -p "$SCRIPT_DIR/data" "$SCRIPT_DIR/logs" "$SCRIPT_DIR/ml_models" "$SCRIPT_DIR/ml_states" "$SCRIPT_DIR/t"

echo "=== 3. Compiling Rust L1 Engine (Without Layer-2 Blockchain) ==="
cargo build --release --manifest-path "$SCRIPT_DIR/Cargo.toml"

echo "=========================================================="
echo "✅ Setup complete for Slakshna (Layer-1 FL over Bhaskera)!"
echo "To start your node:"
echo "  1. Activate environment: source $ACTIVATE_PATH"
echo "  2. Run the engine: ./target/release/iiitd --config <your_node_config.toml>"
echo "=========================================================="
