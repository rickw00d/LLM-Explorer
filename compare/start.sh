#!/usr/bin/env bash
# 啟動模型比較工具（背景）。預設 127.0.0.1:8890（僅本機）。
# 需要 ComfyUI 已在 http://127.0.0.1:8188 執行。
#
# 對外模式：若 compare/.token 存在（或已設 COMPARE_TOKEN 環境變數），
# 就會帶著密鑰啟動 —— 所有 /api/* 需認證，管理端點自動封鎖。
# 這支腳本刻意讓「有密鑰」成為預設：通道開通前忘了設密鑰，
# 等於把機器裸露在公網上。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/../comfyui/comfyui-env/bin/python"
[[ -x "$PY" ]] || PY="python3"
LOG="$SCRIPT_DIR/compare.log"; PIDF="$SCRIPT_DIR/compare.pid"
TOKF="$SCRIPT_DIR/.token"

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo ">> 已在執行 (PID $(cat "$PIDF"))。 http://localhost:8890"; exit 0
fi

if [[ -z "${COMPARE_TOKEN:-}" && -f "$TOKF" ]]; then
  COMPARE_TOKEN="$(tr -d '[:space:]' < "$TOKF")"
  export COMPARE_TOKEN
fi

cd "$SCRIPT_DIR"
nohup "$PY" server.py >"$LOG" 2>&1 &
echo $! > "$PIDF"; sleep 1
echo ">> 已啟動 (PID $(cat "$PIDF"))。開瀏覽器： http://localhost:8890"
if [[ -n "${COMPARE_TOKEN:-}" ]]; then
  echo ">> 模式：對外（需 X-Compare-Token，管理端點已封鎖）"
else
  echo ">> 模式：本機（無認證）—— 開通道前務必先建立 compare/.token"
fi
echo ">> log： tail -f \"$LOG\""
