#!/usr/bin/env bash
# 停止 Compare Server 和 ComfyUI
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

stop_proc() {
  local name="$1" pidf="$2"
  if [[ -f "$pidf" ]]; then
    local pid; pid="$(cat "$pidf")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null && sleep 1; kill -9 "$pid" 2>/dev/null || true
      echo ">> $name 已停止 (PID $pid)"
    else
      echo ">> $name 未在執行"
    fi
    rm -f "$pidf"
  else
    echo ">> $name 未在執行"
  fi
}

stop_proc "Compare Server" "$SCRIPT_DIR/compare.pid"
stop_proc "ComfyUI"        "$SCRIPT_DIR/comfyui.pid"
