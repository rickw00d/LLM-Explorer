#!/usr/bin/env bash
# 一鍵啟動 ComfyUI + Compare Server。
# ComfyUI 綁定 127.0.0.1:8188，Compare Server 綁定 127.0.0.1:8890。
#
# 對外模式：若 compare/.token 存在（或已設 COMPARE_TOKEN 環境變數），
# 就會帶著密鑰啟動 —— 所有 /api/* 需認證，管理端點自動封鎖。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_DIR="$SCRIPT_DIR/../comfyui/ComfyUI"
PY="$SCRIPT_DIR/../comfyui/comfyui-env/bin/python"
[[ -x "$PY" ]] || PY="python3"

COMFY_LOG="$SCRIPT_DIR/comfyui.log"; COMFY_PID="$SCRIPT_DIR/comfyui.pid"
COMP_LOG="$SCRIPT_DIR/compare.log";  COMP_PID="$SCRIPT_DIR/compare.pid"
TOKF="$SCRIPT_DIR/.token"

# ── 1. 啟動 ComfyUI ──────────────────────────────────────────
comfy_running=false
if [[ -f "$COMFY_PID" ]] && kill -0 "$(cat "$COMFY_PID")" 2>/dev/null; then
  echo ">> ComfyUI 已在執行 (PID $(cat "$COMFY_PID"))"
  comfy_running=true
fi

if ! $comfy_running; then
  [[ -d "$COMFY_DIR" ]] || { echo "!! 找不到 ComfyUI：$COMFY_DIR"; exit 1; }
  echo ">> 啟動 ComfyUI …"
  cd "$COMFY_DIR"
  nohup "$PY" main.py --listen 127.0.0.1 >"$COMFY_LOG" 2>&1 &
  echo $! > "$COMFY_PID"
  echo "   PID $(cat "$COMFY_PID")，等待就緒…"

  for i in $(seq 1 60); do
    if curl -s -o /dev/null -w '' http://127.0.0.1:8188/system_stats 2>/dev/null; then
      echo "   ✅ ComfyUI 就緒（${i}s）"
      break
    fi
    if ! kill -0 "$(cat "$COMFY_PID")" 2>/dev/null; then
      echo "!! ComfyUI 啟動失敗，查看 log：tail -f \"$COMFY_LOG\""
      exit 1
    fi
    sleep 1
  done
  if ! curl -s -o /dev/null http://127.0.0.1:8188/system_stats 2>/dev/null; then
    echo ">> ⚠️ ComfyUI 60s 內未就緒，繼續等待中… log：tail -f \"$COMFY_LOG\""
  fi
fi

# ── 2. 啟動 Compare Server ────────────────────────────────────
if [[ -f "$COMP_PID" ]] && kill -0 "$(cat "$COMP_PID")" 2>/dev/null; then
  echo ">> Compare Server 已在執行 (PID $(cat "$COMP_PID"))。 http://localhost:8890"
  exit 0
fi

if [[ -z "${COMPARE_TOKEN:-}" && -f "$TOKF" ]]; then
  COMPARE_TOKEN="$(tr -d '[:space:]' < "$TOKF")"
  export COMPARE_TOKEN
fi

cd "$SCRIPT_DIR"
nohup "$PY" server.py >"$COMP_LOG" 2>&1 &
echo $! > "$COMP_PID"; sleep 1
echo ">> Compare Server 已啟動 (PID $(cat "$COMP_PID"))。 http://localhost:8890"
if [[ -n "${COMPARE_TOKEN:-}" ]]; then
  echo ">> 模式：對外（需 X-Compare-Token，管理端點已封鎖）"
else
  echo ">> 模式：本機（無認證）—— 開通道前務必先建立 compare/.token"
fi
echo ">> log： tail -f \"$COMP_LOG\""
echo ">>        tail -f \"$COMFY_LOG\""
