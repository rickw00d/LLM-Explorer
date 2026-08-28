#!/usr/bin/env bash
# 停止 Open WebUI 容器。預設只停止（保留資料與已下載模型）。
# 加參數 --remove 會連容器一起刪掉（volume 內的模型/設定仍保留）。
set -euo pipefail
NAME="open-webui"

if ! docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo ">> 找不到容器 '$NAME'，無需停止。"
  exit 0
fi

echo ">> 停止 '$NAME'…"
docker stop "$NAME"

if [[ "${1:-}" == "--remove" ]]; then
  echo ">> 移除容器（保留 volume: open-webui / open-webui-ollama）…"
  docker rm "$NAME"
fi
echo ">> 完成。"
