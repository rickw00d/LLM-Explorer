#!/usr/bin/env bash
# Run ComfyUI in the FOREGROUND. This is the single definition of how ComfyUI is
# launched: start.sh backgrounds it, systemd supervises it. Change the flags here.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$SCRIPT_DIR/comfyui-env"
COMFY="$SCRIPT_DIR/ComfyUI"

[[ -d "$COMFY" ]] || { echo "!! ComfyUI not found at $COMFY — run ./setup.sh first." >&2; exit 1; }
[[ -f "$VENV/bin/activate" ]] || { echo "!! venv not found at $VENV — run ./setup.sh first." >&2; exit 1; }

# Preflight: refuse to become a second ComfyUI on the same port.
#
# There are two launch paths (./start.sh for a terminal, comfyui.service for systemd)
# and neither can see the other's bookkeeping: start.sh guards on comfyui.pid, systemd
# guards on its own cgroup. Whoever starts second used to bind-fail and, under
# Restart=on-failure, retry until StartLimitBurst gave up — leaving the unit "failed"
# while a perfectly healthy ComfyUI kept serving. Exit 0 in that case so systemd treats
# it as "nothing to do" instead of a failure to retry. A port held by something that is
# NOT ComfyUI is a real misconfiguration, so that still exits non-zero.
PORT="${COMFYUI_PORT:-8188}"
if curl -fsS --max-time 5 "http://127.0.0.1:$PORT/system_stats" >/dev/null 2>&1; then
  echo ">> ComfyUI already serving on 127.0.0.1:$PORT — nothing to do." >&2
  exit 0
fi
if command -v ss >/dev/null 2>&1 && ss -tln "sport = :$PORT" 2>/dev/null | grep -q ":$PORT"; then
  echo "!! Port $PORT is held by a process that does not answer as ComfyUI." >&2
  echo "!! Free it, then start again:  ss -tlnp 'sport = :$PORT'" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"
cd "$COMFY"
# exec keeps the PID, so both the PID file and systemd track the real process.
exec python main.py --use-sage-attention --cache-none --enable-triton-backend "$@"
