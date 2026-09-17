#!/usr/bin/env bash
# Start / stop the Cloudflare Tunnel that publishes the compare service at
# https://llm.rickwood.dev
#
# Usage: ./tunnel.sh start | stop | status
#
# Safety precondition (checked on start; the tunnel refuses to open otherwise):
#   the compare server must be in public mode — an unauthenticated request must
#   return 401. Once the tunnel is up this machine is on the public internet, and
#   without authentication that means wide open.
#
# Note: if the local network blocks outbound port 7844 the tunnel cannot connect
# (see docs/notes.md).
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
    if running; then echo ">> Tunnel already running (PID $(cat "$PIDF")). https://$HOSTNAME_PUB"; exit 0; fi
    [[ -x "$CF" ]] || { echo "!! cloudflared not found: $CF"; exit 1; }

    echo ">> Safety check: confirming the compare server is in public mode…"
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8890/api/queue || echo 000)
    case "$code" in
      401) echo "   ✅ unauthenticated request returns 401" ;;
      000) echo "!! compare server is not responding — run ./start.sh first"; exit 1 ;;
      *)   echo "!! DANGER: unauthenticated request returned $code (expected 401)"
           echo "!! The server has no authentication enabled; refusing to open the tunnel"
           echo "!! Create compare/.token, then re-run ./start.sh"
           exit 1 ;;
    esac

    echo ">> Starting the tunnel…"
    setsid "$CF" tunnel run "$TUNNEL" > "$LOG" 2>&1 < /dev/null &
    echo $! > "$PIDF"
    sleep 12
    if grep -q "Registered tunnel connection" "$LOG"; then
      n=$(grep -c "Registered tunnel connection" "$LOG")
      echo ">> ✅ connected ($n connections). https://$HOSTNAME_PUB"
    else
      echo ">> ⚠️ no connection message yet — check the log: tail -f \"$LOG\""
      grep -iE "ERR|error" "$LOG" | tail -3 || true
    fi
    ;;

  stop)
    if running; then kill "$(cat "$PIDF")" 2>/dev/null || true; rm -f "$PIDF"; echo ">> Tunnel stopped."
    else echo ">> Tunnel is not running."; rm -f "$PIDF"; fi
    ;;

  status)
    if running; then
      echo ">> Tunnel running (PID $(cat "$PIDF"))"
      if [[ -f "$LOG" ]]; then
        echo "   connections: $(grep -c 'Registered tunnel connection' "$LOG" || true)"
      fi
      echo -n "   public probe: "
      code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://$HOSTNAME_PUB/api/queue" || echo 000)
      case "$code" in
        401) echo "$code ✅ (auth enforced, tunnel healthy)" ;;
        000) echo "no response ❌" ;;
        *)   echo "$code ⚠️ (expected 401)" ;;
      esac
    else
      echo ">> Tunnel is not running."
    fi
    ;;

  *) echo "Usage: $0 {start|stop|status}"; exit 1 ;;
esac
