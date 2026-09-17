#!/usr/bin/env bash
# Start Open WebUI + Ollama (single container with Ollama built in).
# Bound to 127.0.0.1 only, so only a browser on this machine can reach it.
# Follows the NVIDIA DGX Spark open-webui playbook, rebound to loopback.
# 啟動 Open WebUI + Ollama（單容器，內建 Ollama）。
# 僅綁定 127.0.0.1（localhost-only）→ 只有本機瀏覽器能連。
# 依 NVIDIA DGX Spark open-webui playbook，改綁 loopback。
set -euo pipefail

NAME="open-webui"
IMAGE="ghcr.io/open-webui/open-webui:ollama"
PORT="8080"

# Start the existing container instead of running a new one
# 若容器已存在就直接啟動，避免重複 run
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo ">> Container '$NAME' exists, starting 容器已存在，啟動中…"
  docker start "$NAME"
else
  echo ">> Creating container '$NAME' for the first time (pulls a multi-GB image, please wait)"; echo ">> 第一次建立容器（首次會拉映像檔，約數 GB，請稍候）…"
  docker run -d \
    -p 127.0.0.1:${PORT}:8080 \
    --gpus=all \
    -v open-webui:/app/backend/data \
    -v open-webui-ollama:/root/.ollama \
    --restart unless-stopped \
    --name "$NAME" "$IMAGE"
fi

echo
echo ">> Started. Open your browser 已啟動，開瀏覽器： http://localhost:${PORT}"
echo ">> Next: ./pull-models.sh to download the models in models.txt 下一步：下載模型"
echo ">> On first visit, create a local admin account in the UI (data stays on this machine)."; echo ">> 首次進入請在 UI 建立本機管理員帳號（資料只存在本機，不外流）。"
