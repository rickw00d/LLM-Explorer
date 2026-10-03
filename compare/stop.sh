#!/usr/bin/env bash
# Stop the compare server, then ComfyUI.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDF="$SCRIPT_DIR/compare.pid"
COMFY_SH="$SCRIPT_DIR/../comfyui/stop.sh"

if [[ -f "$PIDF" ]]; then
  PID="$(cat "$PIDF")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null && sleep 1; kill -9 "$PID" 2>/dev/null || true
    echo ">> Compare server stopped (PID $PID)."
  else
    echo ">> Compare server not running."
  fi
  rm -f "$PIDF"
else
  echo ">> Compare server not running."
fi

# comfyui/stop.sh owns ComfyUI's PID file.
if [[ -x "$COMFY_SH" ]]; then
  "$COMFY_SH"
else
  echo ">> ComfyUI launcher not found at $COMFY_SH — stop it yourself if it is running."
fi
