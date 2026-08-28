#!/usr/bin/env bash
# 啟動模型比較工具（背景）。預設 127.0.0.1:8890（僅本機）。
# 需要 ComfyUI 已在 http://127.0.0.1:8188 執行。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/../comfyui/comfyui-env/bin/python"
[[ -x "$PY" ]] || PY="python3"
LOG="$SCRIPT_DIR/compare.log"; PIDF="$SCRIPT_DIR/compare.pid"

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo ">> 已在執行 (PID $(cat "$PIDF"))。 http://localhost:8890"; exit 0
fi
cd "$SCRIPT_DIR"
nohup "$PY" server.py >"$LOG" 2>&1 &
echo $! > "$PIDF"; sleep 1
echo ">> 已啟動 (PID $(cat "$PIDF"))。開瀏覽器： http://localhost:8890"
echo ">> log： tail -f \"$LOG\""
