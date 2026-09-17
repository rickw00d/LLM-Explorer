#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDF="$SCRIPT_DIR/compare.pid"
[[ -f "$PIDF" ]] || { echo ">> Not running 未在執行"; exit 0; }
PID="$(cat "$PIDF")"
kill "$PID" 2>/dev/null && sleep 1; kill -9 "$PID" 2>/dev/null || true
rm -f "$PIDF"; echo ">> Stopped 已停止"
