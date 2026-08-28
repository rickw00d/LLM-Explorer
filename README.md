# LLM Explorer — DGX Spark（GB10）本地 AI 工作站

在這台 **GB10 Grace Blackwell**（128GB 統一記憶體）上跑兩套本地服務：

| 服務 | 用途 | 網址（僅本機） | 目錄 |
|------|------|----------------|------|
| **Open WebUI + Ollama** | 多 LLM 聊天（Qwen / Gemma…，可熱切換） | http://localhost:8080 | [`chatbot/`](chatbot/) |
| **ComfyUI** | 生圖/生影片後端（LTX-2.5 / Wan 2.2 / MiniMax H3） | http://localhost:8188 | [`comfyui/`](comfyui/) |
| **模型比較工具** | 同一個 prompt，三個模型並排比較（呼叫 ComfyUI API） | http://localhost:8890 | [`compare/`](compare/) |

> 三個服務都**只綁定 127.0.0.1**（localhost-only）。硬體限制與記憶體管理見 [`docs/notes.md`](docs/notes.md)。

---

## 0. 一次性前置
```bash
# 讓目前使用者能用 docker（之後要登出再登入，或 newgrp docker）
sudo usermod -aG docker $USER

# 下載模型用的 HuggingFace CLI（ComfyUI 部分需要）
pip install -U "huggingface_hub[cli]"
hf auth login          # LTX-2.5 為 gated，需先到其 HF 頁面接受授權
```

## 1. Chatbot（多 LLM）
```bash
cd chatbot
./start.sh             # 啟動 Open WebUI（首次會拉映像檔）
./pull-models.sh       # 依 models.txt 下載 Qwen / Gemma
# 瀏覽器開 http://localhost:8080 → 建本機管理員帳號 → 在 UI 切換模型對話
./stop.sh              # 停止（加 --remove 連容器一起刪，模型/設定仍保留）
```
想加/減模型：編輯 [`chatbot/models.txt`](chatbot/models.txt) 後再跑 `./pull-models.sh`。

## 2. ComfyUI（生圖/生影片模型比對）
```bash
cd comfyui
./setup.sh             # 建 venv + 裝 cu130 PyTorch + 最新 ComfyUI + Manager
./download-models.sh   # 下載 LTX-2.5 / Wan 2.2 / MiniMax H3（可加 ltx|wan|h3 只下一組）
./start.sh             # 啟動 ComfyUI（背景）→ http://localhost:8188
./stop.sh              # 停止
```
比對方法（同 prompt / 同 seed）見 [`comfyui/workflows/README.md`](comfyui/workflows/README.md)。

## 3. 模型比較工具（同一 prompt · 三模型並排）
一個網頁：輸入一個 prompt → 對 LTX-2.5 / Wan 2.2 / MiniMax H3 各跑一次 → 同頁並排比較（含耗時）。
```bash
cd compare && ./start.sh        # 需 ComfyUI 已在跑 → http://localhost:8890
```
首次使用：在每個模型的頁面卡片按 **🎯 從 ComfyUI 擷取**（先在 ComfyUI 開該模型 Template 按一次 Run），
工具會自動抓取並辨識模型。之後輸入 prompt、選圖片/影片、勾選模型，按「一次生成並比較」。
> ⚠️ 首次生成前，必須先裝 `python3-dev`（見 [docs/notes.md](docs/notes.md) 疑難排解），否則 ComfyUI 會因 Triton 缺標頭檔而失敗。

---

## 重要提醒
- **架構是 aarch64 + Blackwell sm_121，只能用 CUDA 13 / cu130 的套件**（詳見 notes）。
- LLM 與影片模型**共用 128GB**，建議**一次跑一種重負載**；影片模型優先用**量化版**（NVFP4/int8/fp8）。
- 這些模型是 2026-08 的新版本；若官方檔名/節點有變，最保險是讓 **ComfyUI Template 自動下載**。

## 目錄結構
```
LLM Explorer/
├── README.md              # 本檔
├── chatbot/               # Open WebUI + Ollama（Docker）
│   ├── start.sh  stop.sh  pull-models.sh  models.txt
├── comfyui/               # ComfyUI（原生 venv）
│   ├── setup.sh  start.sh  stop.sh  download-models.sh
│   └── workflows/         # 比對 workflow 說明 + 你匯出的 .json
└── docs/notes.md          # 硬體限制 / 記憶體管理 / 疑難排解
```
