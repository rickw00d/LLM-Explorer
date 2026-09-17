#!/usr/bin/env bash
# Start the model comparison tool in the background. Binds 127.0.0.1:8890 by default
# (localhost only) and needs ComfyUI running at http://127.0.0.1:8188.
#
# Public mode: if compare/.token exists (or COMPARE_TOKEN is already exported), the
# server starts with that secret — every /api/* call then needs authentication and the
# admin endpoints are blocked. Having a token is deliberately the default path: opening
# the tunnel without one would leave this machine bare on the public internet.
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
  echo ">> Already running 已在執行 (PID $(cat "$PIDF")). http://localhost:8890"; exit 0
fi

if [[ -z "${COMPARE_TOKEN:-}" && -f "$TOKF" ]]; then
  COMPARE_TOKEN="$(tr -d '[:space:]' < "$TOKF")"
  export COMPARE_TOKEN
fi

cd "$SCRIPT_DIR"
nohup "$PY" server.py >"$LOG" 2>&1 &
echo $! > "$PIDF"; sleep 1
echo ">> Started 已啟動 (PID $(cat "$PIDF")). Open 開瀏覽器： http://localhost:8890"
if [[ -n "${COMPARE_TOKEN:-}" ]]; then
  echo ">> Mode: public — X-Compare-Token required, admin endpoints blocked 模式：對外"
else
  echo ">> Mode: local (no auth) — create compare/.token before opening any tunnel 模式：本機（無認證）"
fi
echo ">> log： tail -f \"$LOG\""
