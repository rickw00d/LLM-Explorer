#!/usr/bin/env bash
# 在 DGX Spark（GB10 / sm_121 / aarch64 / CUDA 13.0）安裝 ComfyUI。
# 用最新版 ComfyUI（才有 LTX-2.5 / MiniMax H3 等 2026-08 新模型的原生節點），
# PyTorch 走官方 cu130 aarch64 wheel。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV="$SCRIPT_DIR/comfyui-env"
COMFY="$SCRIPT_DIR/ComfyUI"

echo ">> [1/5] 檢查前置需求…"
python3 --version
nvidia-smi -L

echo ">> [2/5] 建立 venv：$VENV"
[[ -d "$VENV" ]] || python3 -m venv "$VENV"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install --upgrade pip

echo ">> [3/5] 安裝 PyTorch（cu130 / aarch64，支援 Blackwell sm_121）…"
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130

echo ">> [4/5] 取得最新 ComfyUI + 相依套件…"
if [[ -d "$COMFY/.git" ]]; then
  git -C "$COMFY" pull --ff-only
else
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY"
fi
pip install -r "$COMFY/requirements.txt"

echo ">> [5/5] 安裝 ComfyUI-Manager（方便補裝自訂節點/模型）…"
MGR="$COMFY/custom_nodes/ComfyUI-Manager"
if [[ -d "$MGR/.git" ]]; then
  git -C "$MGR" pull --ff-only
else
  git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MGR"
fi

echo
echo ">> 驗證 GPU 是否可用："
python -c "import torch;print('torch', torch.__version__, '| cuda', torch.cuda.is_available(), '|', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NO GPU')"
echo
echo ">> 完成。接著："
echo "   ./download-models.sh   # 下載 LTX-2.5 / Wan 2.2 / MiniMax H3 權重"
echo "   ./start.sh             # 啟動 ComfyUI（http://localhost:8188）"
