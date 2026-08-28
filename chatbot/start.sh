#!/usr/bin/env bash
# 啟動 Open WebUI + Ollama（單容器，內建 Ollama）。
# 僅綁定 127.0.0.1（localhost-only）→ 只有本機瀏覽器能連。
# 依 NVIDIA DGX Spark open-webui playbook，改綁 loopback。
set -euo pipefail

NAME="open-webui"
IMAGE="ghcr.io/open-webui/open-webui:ollama"
PORT="8080"

# 若容器已存在就直接啟動，避免重複 run
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo ">> 容器 '$NAME' 已存在，啟動中…"
  docker start "$NAME"
else
  echo ">> 第一次建立容器 '$NAME'（首次會拉映像檔，約數 GB，請稍候）…"
  docker run -d \
    -p 127.0.0.1:${PORT}:8080 \
    --gpus=all \
    -v open-webui:/app/backend/data \
    -v open-webui-ollama:/root/.ollama \
    --restart unless-stopped \
    --name "$NAME" "$IMAGE"
fi

echo
echo ">> 已啟動。開瀏覽器： http://localhost:${PORT}"
echo ">> 下一步：./pull-models.sh 下載 Qwen / Gemma 等模型"
echo ">> 首次進入請在 UI 建立本機管理員帳號（資料只存在本機，不外流）。"
