#!/usr/bin/env bash
# Pull every model in models.txt via the Ollama built into the open-webui container.
# Usage: ./pull-models.sh            # read models.txt
#        ./pull-models.sh qwen3:8b   # pull a single model
# 依 models.txt 逐一 ollama pull（透過 open-webui 容器內建的 Ollama）。
# 用法： ./pull-models.sh            # 讀 models.txt
#        ./pull-models.sh qwen3:8b   # 只拉指定的一個模型
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="open-webui"

if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "!! Container '$NAME' is not running — run ./start.sh first 容器未在執行，請先 ./start.sh" >&2
  exit 1
fi

pull_one() { echo ">> pull: $1"; docker exec "$NAME" ollama pull "$1"; }

if [[ $# -ge 1 ]]; then
  pull_one "$1"
else
  # Read models.txt, skipping blank lines and # comments 讀 models.txt，略過空行與 # 註解
  grep -vE '^\s*(#|$)' "$SCRIPT_DIR/models.txt" | while read -r m; do
    pull_one "$m"
  done
fi

echo
echo ">> Installed models 目前已安裝的模型："
docker exec "$NAME" ollama list
