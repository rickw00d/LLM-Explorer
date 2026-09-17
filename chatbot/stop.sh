#!/usr/bin/env bash
# Stop the Open WebUI container. By default it only stops (data and downloaded
# models are kept). Pass --remove to delete the container too; the volumes with
# models/settings survive either way.
# 停止 Open WebUI 容器。預設只停止（保留資料與已下載模型）。
# 加參數 --remove 會連容器一起刪掉（volume 內的模型/設定仍保留）。
set -euo pipefail
NAME="open-webui"

if ! docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo ">> Container '$NAME' not found, nothing to stop 找不到容器，無需停止。"
  exit 0
fi

echo ">> Stopping 停止 '$NAME'…"
docker stop "$NAME"

if [[ "${1:-}" == "--remove" ]]; then
  echo ">> Removing container (volumes open-webui / open-webui-ollama are kept) 移除容器…"
  docker rm "$NAME"
fi
echo ">> Done 完成。"
