#!/usr/bin/env bash
# 啟動 / 停止 Cloudflare Tunnel，把 compare 服務發布到 https://llm.rickwood.dev
#
# 用法： ./tunnel.sh start | stop | status
#
# 安全前提（start 會自動檢查，不通過就拒絕啟動）：
#   compare server 必須處於「對外模式」——未帶密鑰的請求要回 401。
#   通道一開，這台機器就在公網上；沒有認證等於門戶洞開。
#
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
    if running; then echo ">> 通道已在執行 (PID $(cat "$PIDF"))。 https://$HOSTNAME_PUB"; exit 0; fi
    [[ -x "$CF" ]] || { echo "!! 找不到 cloudflared：$CF"; exit 1; }

    echo ">> 安全檢查：確認 compare server 處於對外模式…"
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8890/api/queue || echo 000)
    case "$code" in
      401) echo "   ✅ 未授權請求回 401" ;;
      000) echo "!! compare server 沒有回應。請先執行 ./start.sh"; exit 1 ;;
      *)   echo "!! 危險：未授權請求回 $code（預期 401）。"
           echo "!! server 目前沒有啟用認證，拒絕開通道。"
           echo "!! 請確認 compare/.token 存在後重新執行 ./start.sh"
           exit 1 ;;
    esac

    echo ">> 啟動通道…"
    setsid "$CF" tunnel run "$TUNNEL" > "$LOG" 2>&1 < /dev/null &
    echo $! > "$PIDF"
    sleep 12
    if grep -q "Registered tunnel connection" "$LOG"; then
      n=$(grep -c "Registered tunnel connection" "$LOG")
      echo ">> ✅ 已連線（$n 條）。 https://$HOSTNAME_PUB"
    else
      echo ">> ⚠️ 尚未看到連線成功訊息，檢查 log：tail -f \"$LOG\""
      grep -iE "ERR|error" "$LOG" | tail -3 || true
    fi
    ;;

  stop)
    if running; then kill "$(cat "$PIDF")" 2>/dev/null || true; rm -f "$PIDF"; echo ">> 通道已停止。"
    else echo ">> 通道未執行。"; rm -f "$PIDF"; fi
    ;;

  status)
    if running; then
      echo ">> 通道執行中 (PID $(cat "$PIDF"))"
      if [[ -f "$LOG" ]]; then
        echo "   連線數：$(grep -c 'Registered tunnel connection' "$LOG" || true)"
      fi
      echo -n "   公網探測："
      code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://$HOSTNAME_PUB/api/queue" || echo 000)
      case "$code" in
        401) echo "$code ✅（認證生效，通道正常）" ;;
        000) echo "無回應 ❌" ;;
        *)   echo "$code ⚠️（預期 401）" ;;
      esac
    else
      echo ">> 通道未執行。"
    fi
    ;;

  *) echo "用法： $0 {start|stop|status}"; exit 1 ;;
esac
