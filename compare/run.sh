#!/usr/bin/env bash
# Run the comparison server in the FOREGROUND. This is the single definition of how
# the server is launched: start.sh backgrounds it, systemd supervises it.
#
# If compare/.token exists and COMPARE_TOKEN is not already set, the token is picked up
# here, so public mode works the same whether you start it by hand or through systemd.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/../comfyui/comfyui-env/bin/python"
[[ -x "$PY" ]] || PY="python3"
TOKF="$SCRIPT_DIR/.token"

if [[ -z "${COMPARE_TOKEN:-}" && -f "$TOKF" ]]; then
  COMPARE_TOKEN="$(tr -d '[:space:]' < "$TOKF")"
  export COMPARE_TOKEN
fi

cd "$SCRIPT_DIR"
# exec keeps the PID, so both the PID file and systemd track the real process.
exec "$PY" server.py "$@"
