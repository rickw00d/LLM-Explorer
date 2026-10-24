#!/usr/bin/env bash
# Stop the background ComfyUI process.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDF="$SCRIPT_DIR/comfyui.pid"

# Mirror start.sh: when systemd owns ComfyUI, killing the PID directly just triggers
# Restart=on-failure. Ask systemd to stop it so it stays stopped.
if systemctl --user cat comfyui.service >/dev/null 2>&1 \
   && [[ "$(systemctl --user is-active comfyui.service)" == "active" ]]; then
  echo ">> Stopping comfyui.service through systemd…"
  systemctl --user stop comfyui.service
  rm -f "$PIDF"
  echo ">> Done."
  exit 0
fi

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
