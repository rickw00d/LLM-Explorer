#!/usr/bin/env bash
# Start ComfyUI in the background. Binds 127.0.0.1:8188 by default (localhost-only,
# no --listen). Logs to comfyui.log, PID in comfyui.pid; stop it with ./stop.sh.
# 啟動 ComfyUI（背景執行）。預設綁 127.0.0.1:8188（localhost-only，不加 --listen）。
# log 寫到 comfyui.log，PID 寫到 comfyui.pid；用 ./stop.sh 停止。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$SCRIPT_DIR/comfyui-env"
COMFY="$SCRIPT_DIR/ComfyUI"
LOG="$SCRIPT_DIR/comfyui.log"
PIDF="$SCRIPT_DIR/comfyui.pid"

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo ">> ComfyUI is already running 已在執行 (PID $(cat "$PIDF")). http://localhost:8188"
  exit 0
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"
cd "$COMFY"

echo ">> Starting ComfyUI in the background 啟動 ComfyUI（背景）… log: $LOG"
nohup python main.py --use-sage-attention --cache-none --enable-triton-backend >"$LOG" 2>&1 &
echo $! > "$PIDF"
sleep 2
echo ">> PID $(cat "$PIDF"). Open your browser 開瀏覽器： http://localhost:8188"
echo ">> Follow the log 看即時 log： tail -f \"$LOG\""
