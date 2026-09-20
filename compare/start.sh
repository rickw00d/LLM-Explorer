#!/usr/bin/env bash
# Start ComfyUI (if it is not already up) and then the model comparison tool.
# ComfyUI binds 127.0.0.1:8188; the compare server binds 127.0.0.1:8890 by default
# (override with COMPARE_HOST / COMPARE_PORT).
#
# Public mode: if compare/.token exists (or COMPARE_TOKEN is already exported), the
# server starts with that secret — every /api/* call then needs authentication and the
# admin endpoints are blocked. Having a token is deliberately the default path: opening
# the tunnel without one would leave this machine bare on the public internet.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_SH="$SCRIPT_DIR/../comfyui/start.sh"
PY="$SCRIPT_DIR/../comfyui/comfyui-env/bin/python"
[[ -x "$PY" ]] || PY="python3"
COMFY_URL="${COMFY_URL:-http://127.0.0.1:8188}"
LOG="$SCRIPT_DIR/compare.log"; PIDF="$SCRIPT_DIR/compare.pid"
TOKF="$SCRIPT_DIR/.token"
COMFY_WAIT="${COMFY_WAIT:-60}"

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

# ---- 1. ComfyUI -------------------------------------------------------------
# comfyui/start.sh owns ComfyUI's launch flags and PID file; don't duplicate them here.
if curl -sf -o /dev/null --max-time 2 "$COMFY_URL/system_stats" 2>/dev/null; then
  echo ">> ComfyUI already up at $COMFY_URL"
elif [[ -x "$COMFY_SH" ]]; then
  "$COMFY_SH"
  echo ">> Waiting for ComfyUI to become ready (up to ${COMFY_WAIT}s)…"
  for ((i=1; i<=COMFY_WAIT; i++)); do
    if curl -sf -o /dev/null --max-time 2 "$COMFY_URL/system_stats" 2>/dev/null; then
      echo ">> ComfyUI ready after ${i}s"
      break
    fi
    sleep 1
  done
  if ! curl -sf -o /dev/null --max-time 2 "$COMFY_URL/system_stats" 2>/dev/null; then
    # Loading the models can take longer than the timeout; that is not a failure.
    echo ">> ComfyUI not ready within ${COMFY_WAIT}s — still loading? log: tail -f \"$SCRIPT_DIR/../comfyui/comfyui.log\""
  fi
else
  echo ">> ComfyUI launcher not found at $COMFY_SH — start ComfyUI yourself, or generation will fail."
fi

# ---- 2. Compare server ------------------------------------------------------
if pid_alive "$PIDF" "server.py"; then
  echo ">> Compare server already running (PID $(cat "$PIDF")). http://localhost:8890"; exit 0
fi
rm -f "$PIDF"

if [[ -z "${COMPARE_TOKEN:-}" && -f "$TOKF" ]]; then
  COMPARE_TOKEN="$(tr -d '[:space:]' < "$TOKF")"
  export COMPARE_TOKEN
fi

cd "$SCRIPT_DIR"
nohup "$PY" server.py >"$LOG" 2>&1 &
echo $! > "$PIDF"; sleep 1
if ! pid_alive "$PIDF" "server.py"; then
  echo "!! Compare server died on startup. Last lines of the log:"; tail -n 20 "$LOG"; exit 1
fi
echo ">> Compare server started (PID $(cat "$PIDF")). Open http://localhost:8890"
if [[ -n "${COMPARE_TOKEN:-}" ]]; then
  echo ">> Mode: public — X-Compare-Token required, admin endpoints blocked"
else
  echo ">> Mode: local (no auth) — create compare/.token before opening any tunnel"
fi
echo ">> logs: tail -f \"$LOG\""
echo ">>       tail -f \"$SCRIPT_DIR/../comfyui/comfyui.log\""
