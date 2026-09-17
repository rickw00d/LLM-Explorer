#!/usr/bin/env bash
# Stop the background ComfyUI process.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDF="$SCRIPT_DIR/comfyui.pid"

if [[ ! -f "$PIDF" ]]; then
  echo ">> No PID file; ComfyUI is probably not running."
  exit 0
fi
PID="$(cat "$PIDF")"
if kill -0 "$PID" 2>/dev/null; then
  echo ">> Stopping ComfyUI (PID $PID)…"
  kill "$PID"
  sleep 2
  kill -9 "$PID" 2>/dev/null || true
fi
rm -f "$PIDF"
echo ">> Done."
