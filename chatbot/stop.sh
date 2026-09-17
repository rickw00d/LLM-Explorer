#!/usr/bin/env bash
# Stop the Open WebUI container. By default it only stops (data and downloaded
# models are kept). Pass --remove to delete the container too; the volumes with
# models/settings survive either way.
set -euo pipefail
NAME="open-webui"

if ! docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo ">> Container '$NAME' not found, nothing to stop."
  exit 0
fi

echo ">> Stopping '$NAME'…"
docker stop "$NAME"

if [[ "${1:-}" == "--remove" ]]; then
  echo ">> Removing container (volumes open-webui / open-webui-ollama are kept)…"
  docker rm "$NAME"
fi
echo ">> Done."
