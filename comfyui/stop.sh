#!/usr/bin/env bash
# Stop the background ComfyUI process. 停止背景執行的 ComfyUI。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDF="$SCRIPT_DIR/comfyui.pid"

if [[ ! -f "$PIDF" ]]; then
  echo ">> No PID file; ComfyUI is probably not running 找不到 PID 檔，ComfyUI 可能未在執行。"
  exit 0
fi
PID="$(cat "$PIDF")"
if kill -0 "$PID" 2>/dev/null; then
  echo ">> Stopping ComfyUI 停止 ComfyUI (PID $PID)…"
  kill "$PID"
  sleep 2
  kill -9 "$PID" 2>/dev/null || true
fi
rm -f "$PIDF"
echo ">> Done 完成。"
