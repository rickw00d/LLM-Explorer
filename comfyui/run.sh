#!/usr/bin/env bash
# Run ComfyUI in the FOREGROUND. This is the single definition of how ComfyUI is
# launched: start.sh backgrounds it, systemd supervises it. Change the flags here.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$SCRIPT_DIR/comfyui-env"
COMFY="$SCRIPT_DIR/ComfyUI"

[[ -d "$COMFY" ]] || { echo "!! ComfyUI not found at $COMFY — run ./setup.sh first." >&2; exit 1; }
[[ -f "$VENV/bin/activate" ]] || { echo "!! venv not found at $VENV — run ./setup.sh first." >&2; exit 1; }

# shellcheck disable=SC1091
source "$VENV/bin/activate"
cd "$COMFY"
# exec keeps the PID, so both the PID file and systemd track the real process.
exec python main.py --use-sage-attention --cache-none --enable-triton-backend "$@"
