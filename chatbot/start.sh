#!/usr/bin/env bash
# Start Open WebUI + Ollama (single container with Ollama built in).
# Bound to 127.0.0.1 only, so only a browser on this machine can reach it.
# Follows the NVIDIA DGX Spark open-webui playbook, rebound to loopback.
set -euo pipefail

NAME="open-webui"
IMAGE="ghcr.io/open-webui/open-webui:ollama"
PORT="8080"

# Start the existing container instead of running a new one
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo ">> Container '$NAME' exists, starting…"
  docker start "$NAME"
else
  echo ">> Creating container '$NAME' for the first time (pulls a multi-GB image, please wait)…"
  docker run -d \
    -p 127.0.0.1:${PORT}:8080 \
    --gpus=all \
    -v open-webui:/app/backend/data \
    -v open-webui-ollama:/root/.ollama \
    --restart unless-stopped \
    --name "$NAME" "$IMAGE"
fi

echo
echo ">> Started. Open your browser at http://localhost:${PORT}"
echo ">> Next: ./pull-models.sh to download the models listed in models.txt"
echo ">> On first visit, create a local admin account in the UI (data stays on this machine)."
