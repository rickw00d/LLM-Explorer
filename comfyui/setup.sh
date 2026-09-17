#!/usr/bin/env bash
# Install ComfyUI on DGX Spark (GB10 / sm_121 / aarch64 / CUDA 13.0).
# Uses the latest ComfyUI (only it has native nodes for the 2026-08 models such as
# LTX-2.5 and MiniMax H3) and the official cu130 aarch64 PyTorch wheel.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV="$SCRIPT_DIR/comfyui-env"
COMFY="$SCRIPT_DIR/ComfyUI"

echo ">> [1/5] Checking prerequisites…"
python3 --version
nvidia-smi -L

echo ">> [2/5] Creating venv: $VENV"
[[ -d "$VENV" ]] || python3 -m venv "$VENV"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install --upgrade pip

echo ">> [3/5] Installing PyTorch (cu130 / aarch64, Blackwell sm_121)…"
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130

echo ">> [4/5] Fetching the latest ComfyUI + dependencies…"
if [[ -d "$COMFY/.git" ]]; then
  git -C "$COMFY" pull --ff-only
else
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY"
fi
pip install -r "$COMFY/requirements.txt"

echo ">> [5/5] Installing ComfyUI-Manager (for custom nodes/models)…"
MGR="$COMFY/custom_nodes/ComfyUI-Manager"
if [[ -d "$MGR/.git" ]]; then
  git -C "$MGR" pull --ff-only
else
  git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MGR"
fi

echo
echo ">> Verifying GPU availability:"
python -c "import torch;print('torch', torch.__version__, '| cuda', torch.cuda.is_available(), '|', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NO GPU')"
echo
echo ">> Done. Next steps:"
echo "   ./download-models.sh   # download model weights"
echo "   ./start.sh             # start ComfyUI (http://localhost:8188)"
