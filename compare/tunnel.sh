#!/usr/bin/env bash
# Start / stop the Cloudflare Tunnel that publishes the compare service at
# https://llm.rickwood.dev
#
# Usage 用法： ./tunnel.sh start | stop | status
#
# Safety precondition (checked on start; the tunnel refuses to open otherwise):
#   the compare server must be in public mode — an unauthenticated request must
#   return 401. Once the tunnel is up this machine is on the public internet, and
#   without authentication that means wide open.
# 安全前提（start 會自動檢查，不通過就拒絕啟動）：
#   compare server 必須處於「對外模式」——未帶密鑰的請求要回 401。
#   通道一開，這台機器就在公網上；沒有認證等於門戶洞開。
#
# Note: if the local network blocks outbound port 7844 the tunnel cannot connect
# (see docs/notes.md).
# 注意：本機網路若擋掉 outbound 7844，通道會連不上（見 docs/notes.md）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CF="$HOME/.local/bin/cloudflared"
TUNNEL="llm-explorer"
HOSTNAME_PUB="llm.rickwood.dev"
LOG="$SCRIPT_DIR/tunnel.log"
PIDF="$SCRIPT_DIR/tunnel.pid"

running() { [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }

case "${1:-start}" in
  start)
    if running; then echo ">> Tunnel already running 通道已在執行 (PID $(cat "$PIDF")). https://$HOSTNAME_PUB"; exit 0; fi
    [[ -x "$CF" ]] || { echo "!! cloudflared not found 找不到 cloudflared：$CF"; exit 1; }

    echo ">> Safety check: confirming the compare server is in public mode 安全檢查…"
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8890/api/queue || echo 000)
    case "$code" in
      401) echo "   ✅ unauthenticated request returns 401 未授權請求回 401" ;;
      000) echo "!! compare server is not responding — run ./start.sh first 沒有回應，請先執行 ./start.sh"; exit 1 ;;
      *)   echo "!! DANGER: unauthenticated request returned $code (expected 401) 危險：預期 401。"
           echo "!! The server has no authentication enabled; refusing to open the tunnel 拒絕開通道。"
           echo "!! Create compare/.token, then re-run ./start.sh 請確認 compare/.token 存在後重新執行。"
           exit 1 ;;
    esac

    echo ">> Starting the tunnel 啟動通道…"
    setsid "$CF" tunnel run "$TUNNEL" > "$LOG" 2>&1 < /dev/null &
    echo $! > "$PIDF"
    sleep 12
    if grep -q "Registered tunnel connection" "$LOG"; then
      n=$(grep -c "Registered tunnel connection" "$LOG")
      echo ">> ✅ connected 已連線（$n connections 條）。 https://$HOSTNAME_PUB"
    else
      echo ">> ⚠️ no connection message yet — check the log 尚未看到連線成功訊息，檢查 log：tail -f \"$LOG\""
      grep -iE "ERR|error" "$LOG" | tail -3 || true
    fi
    ;;

  stop)
    if running; then kill "$(cat "$PIDF")" 2>/dev/null || true; rm -f "$PIDF"; echo ">> Tunnel stopped 通道已停止。"
    else echo ">> Tunnel is not running 通道未執行。"; rm -f "$PIDF"; fi
    ;;

  status)
    if running; then
      echo ">> Tunnel running 通道執行中 (PID $(cat "$PIDF"))"
      if [[ -f "$LOG" ]]; then
        echo "   connections 連線數：$(grep -c 'Registered tunnel connection' "$LOG" || true)"
      fi
      echo -n "   public probe 公網探測："
      code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://$HOSTNAME_PUB/api/queue" || echo 000)
      case "$code" in
        401) echo "$code ✅ (auth enforced, tunnel healthy 認證生效，通道正常)" ;;
        000) echo "no response 無回應 ❌" ;;
        *)   echo "$code ⚠️ (expected 401 預期 401)" ;;
      esac
    else
      echo ">> Tunnel is not running 通道未執行。"
    fi
    ;;

  *) echo "Usage 用法： $0 {start|stop|status}"; exit 1 ;;
esac
