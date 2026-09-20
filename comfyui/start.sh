#!/usr/bin/env bash
# Start ComfyUI in the background. Binds 127.0.0.1:8188 by default (localhost-only,
# no --listen). Logs to comfyui.log, PID in comfyui.pid; stop it with ./stop.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$SCRIPT_DIR/comfyui-env"
COMFY="$SCRIPT_DIR/ComfyUI"
LOG="$SCRIPT_DIR/comfyui.log"
PIDF="$SCRIPT_DIR/comfyui.pid"

# A PID file alone proves nothing: a reboot recycles low PIDs, so the number left over
# from the last run often belongs to some unrelated daemon. Confirm the command matches.
pid_alive() {
  local pidf="$1" pat="$2" pid
  [[ -f "$pidf" ]] || return 1
  pid="$(cat "$pidf" 2>/dev/null)" || return 1
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q -- "$pat" || return 1
}

if pid_alive "$PIDF" "main.py"; then
  echo ">> ComfyUI is already running (PID $(cat "$PIDF")). http://localhost:8188"
  exit 0
fi
rm -f "$PIDF"

# shellcheck disable=SC1091
source "$VENV/bin/activate"
cd "$COMFY"

echo ">> Starting ComfyUI in the background… log: $LOG"
nohup python main.py --use-sage-attention --cache-none --enable-triton-backend >"$LOG" 2>&1 &
echo $! > "$PIDF"
sleep 2
echo ">> PID $(cat "$PIDF"). Open your browser at http://localhost:8188"
echo ">> Follow the log: tail -f \"$LOG\""
