# LLM Explorer — Local AI Workstation on DGX Spark (GB10)
# LLM Explorer — DGX Spark（GB10）本地 AI 工作站

Three local services on a **GB10 Grace Blackwell** box (128 GB unified memory):
chat with multiple LLMs, generate images/videos with ComfyUI, and compare
several generative models side by side from a single prompt.

> 在這台 **GB10 Grace Blackwell**（128GB 統一記憶體）上跑三套本地服務：多 LLM 聊天、
> ComfyUI 生圖/生影片，以及「同一個 prompt、多模型並排比較」的網頁工具。

| Service 服務 | Purpose 用途 | URL (local only 僅本機) | Directory 目錄 |
|---|---|---|---|
| **Open WebUI + Ollama** | Multi-LLM chat, hot-swappable models<br>多 LLM 聊天（Qwen / Gemma…，可熱切換） | http://localhost:8080 | [`chatbot/`](chatbot/) |
| **ComfyUI** | Image/video generation backend<br>生圖/生影片後端 | http://localhost:8188 | [`comfyui/`](comfyui/) |
| **Model Comparison Tool** | One prompt, several models side by side (calls the ComfyUI API)<br>同一個 prompt，多模型並排比較（呼叫 ComfyUI API） | http://localhost:8890 | [`compare/`](compare/) |
| **HuggingFace Space frontend** | Optional remote UI that tunnels back to this machine<br>選用的遠端前端，透過通道連回本機 | — | [`space/`](space/) |

> All three services bind to **127.0.0.1 only** by default. Public exposure is
> opt-in and requires a shared token — see [Public access](#4-public-access-optional--對外開放選用).
> 三個服務預設都**只綁定 127.0.0.1**。對外開放需自行啟用，且必須設密鑰。

Hardware limits and memory management: [`docs/notes.md`](docs/notes.md).
硬體限制與記憶體管理見 [`docs/notes.md`](docs/notes.md)。

---

## Quick start: one-shot installer / 快速開始：一鍵安裝

The interactive installer covers everything below — system checks, ComfyUI
environment, model downloads, service start-up and the chatbot.

互動式安裝腳本涵蓋以下所有步驟：系統檢查、ComfyUI 環境、模型下載、啟動服務與 chatbot。

```bash
git clone https://github.com/rickw00d/LLM-Explorer.git
cd LLM-Explorer
./install.sh          # ↑↓ move · Space select · Enter start（可複選）
```

Menu items / 選單項目:

1. System bootstrap — packages, Docker, CUDA checks / 系統初始化（套件、Docker、CUDA 檢查）
2. ComfyUI environment — venv + PyTorch cu130 / ComfyUI 環境
3. Video models — LTX-2.5 / MiniMax H3 / Wan 2.2 / 影片模型
4. Image models — Flux.2 Klein / Qwen-Image / Z-Image Turbo / 圖片模型
5. Start ComfyUI + comparison tool / 啟動 ComfyUI + 比較工具
6. Chatbot — Open WebUI + Ollama + LLMs / Chatbot

Everything is logged to `install.log`. Nothing is selected by default — use
Space to pick. 全程記錄在 `install.log`；預設全部不勾選，請用 Space 選取。

If you prefer to do it by hand, the manual steps follow.
想手動安裝的話，請看以下步驟。

---

## 0. One-time prerequisites / 一次性前置

```bash
# Let the current user run docker (log out and back in afterwards, or: newgrp docker)
# 讓目前使用者能用 docker（之後要登出再登入，或 newgrp docker）
sudo usermod -aG docker $USER

# Build headers Triton needs at generation time — without these, ComfyUI fails.
# Triton 執行期即時編譯需要的開發標頭檔；沒裝的話 ComfyUI 生成會失敗。
sudo apt-get update && sudo apt-get install -y python3-dev build-essential

# HuggingFace CLI for model downloads (needed by the ComfyUI part)
# 下載模型用的 HuggingFace CLI（ComfyUI 部分需要）
pip install -U "huggingface_hub[cli]"
hf auth login          # LTX-2.5 is gated — accept the licence on its HF page first
                       # LTX-2.5 為 gated，需先到其 HF 頁面接受授權
```

## 1. Chatbot (multi-LLM) / Chatbot（多 LLM）

```bash
cd chatbot
./start.sh             # start Open WebUI (first run pulls the image) 啟動 Open WebUI（首次會拉映像檔）
./pull-models.sh       # download the models listed in models.txt 依 models.txt 下載模型
# Open http://localhost:8080 → create a local admin account → switch models in the UI
# 瀏覽器開 http://localhost:8080 → 建本機管理員帳號 → 在 UI 切換模型對話
./stop.sh              # stop (add --remove to delete the container; models/settings are kept)
                       # 停止（加 --remove 連容器一起刪，模型/設定仍保留）
```

To add or remove models, edit [`chatbot/models.txt`](chatbot/models.txt) and re-run
`./pull-models.sh`. You can also pull a single model: `./pull-models.sh qwen3:8b`.

想加/減模型：編輯 [`chatbot/models.txt`](chatbot/models.txt) 後再跑 `./pull-models.sh`；
也可以只拉單一模型：`./pull-models.sh qwen3:8b`。

## 2. ComfyUI (image/video generation) / ComfyUI（生圖/生影片）

```bash
cd comfyui
./setup.sh             # venv + cu130 PyTorch + latest ComfyUI + Manager
                       # 建 venv + 裝 cu130 PyTorch + 最新 ComfyUI + Manager
./download-models.sh   # all models; or pass one of: ltx wan h3 flux2 qwen zimage video image
                       # 下載全部；也可指定 ltx|wan|h3|flux2|qwen|zimage|video|image
./start.sh             # start in the background → http://localhost:8188 啟動（背景）
./stop.sh              # stop 停止
```

Models covered / 涵蓋的模型:

| Model 模型 | Type 類型 | Notes 備註 |
|---|---|---|
| LTX-2.5 (Lightricks, 22B int8) | video 影片 | gated repo — accept the licence first 需先接受授權 |
| MiniMax H3 / Hailuo 3.0 (int8) | video 影片 | use the **Local / open-weights** templates, not the API ones 用本地權重版模板 |
| Wan 2.2 T2V 14B (fp8) | video 影片 | single frame = text-to-image 單張輸出即等同文生圖 |
| Flux.2 Klein (9B fp8) | image 圖片 | |
| Qwen-Image-2512 (bf16) | image 圖片 | |
| Z-Image Turbo (6B bf16) | image 圖片 | distilled, fast 蒸餾版，較快 |

Fair-comparison method (same prompt / same seed): see
[`comfyui/workflows/README.md`](comfyui/workflows/README.md).
比對方法（同 prompt / 同 seed）見 [`comfyui/workflows/README.md`](comfyui/workflows/README.md)。

## 3. Model comparison tool / 模型比較工具

One web page: type a prompt → it runs the selected models once each → results
line up side by side with timings.

一個網頁：輸入一個 prompt → 對選定的模型各跑一次 → 同頁並排比較（含耗時）。

```bash
cd compare && ./start.sh        # requires ComfyUI to be running 需 ComfyUI 已在跑
                                # → http://localhost:8890
./stop.sh                       # stop 停止
```

First run: on each model card press **🎯 Capture from ComfyUI** (first open that
model's template in ComfyUI and press Run once). The tool grabs the workflow and
identifies the model. After that: type a prompt, pick image or video, tick the
models, press generate-and-compare.

首次使用：在每個模型的頁面卡片按 **🎯 從 ComfyUI 擷取**（先在 ComfyUI 開該模型 Template 按一次 Run），
工具會自動抓取並辨識模型。之後輸入 prompt、選圖片/影片、勾選模型，按「一次生成並比較」。

Environment variables / 環境變數:

| Variable 變數 | Default 預設 | Meaning 意義 |
|---|---|---|
| `COMFY_URL` | `http://127.0.0.1:8188` | ComfyUI backend 後端位址 |
| `COMPARE_HOST` / `COMPARE_PORT` | `127.0.0.1` / `8890` | bind address 綁定位址 |
| `COMPARE_TOKEN` | *(empty 空)* | set it to switch on public mode 設了就進入對外模式 |
| `COMPARE_MAX_PENDING` / `COMPARE_MAX_MODELS` / `COMPARE_MAX_PROMPT` | `8` / `3` / `2000` | public-mode limits 對外模式上限 |

> ⚠️ Before the first generation you must have `python3-dev` installed (see
> [docs/notes.md](docs/notes.md) troubleshooting), otherwise ComfyUI fails on a
> missing Triton header.
> ⚠️ 首次生成前，必須先裝 `python3-dev`（見 [docs/notes.md](docs/notes.md) 疑難排解），
> 否則 ComfyUI 會因 Triton 缺標頭檔而失敗。

## 4. Public access (optional) / 對外開放（選用）

The comparison server has a public mode. Setting `COMPARE_TOKEN` makes every
`/api/*` call require an `X-Compare-Token` header, blocks the admin endpoints
(`/api/import`, `/api/savewf`, `/api/capture`, `/api/uitpl`, `/api/stop`), and
enforces a resolution allow-list plus queue limits.

比較工具內建「對外模式」：設了 `COMPARE_TOKEN` 之後，所有 `/api/*` 都要帶
`X-Compare-Token` 標頭，管理端點全部封鎖，並套用解析度白名單與佇列上限。

```bash
# 1. Create the shared token (never commit it — .token is git-ignored)
#    建立共享密鑰（絕對不進版控，.token 已在 .gitignore）
openssl rand -hex 32 > compare/.token

# 2. start.sh picks .token up automatically and starts in public mode
#    start.sh 會自動讀取 .token，以對外模式啟動
cd compare && ./start.sh

# 3. Open the Cloudflare tunnel. It refuses to start unless an unauthenticated
#    request returns 401 — that interlock is deliberate.
#    開 Cloudflare 通道。未授權請求若不是回 401 就拒絕啟動，這個連鎖鎖是刻意的。
./tunnel.sh start | stop | status
```

The HuggingFace Space frontend in [`space/`](space/) is the matching remote UI;
its three-layer security model is documented in [`space/README.md`](space/README.md).

[`space/`](space/) 是搭配的 HuggingFace Space 遠端前端，三層安全模型見
[`space/README.md`](space/README.md)。

---

## Things to keep in mind / 重要提醒

- The platform is **aarch64 + Blackwell sm_121, so only CUDA 13 / cu130 packages work** (see notes).
  **架構是 aarch64 + Blackwell sm_121，只能用 CUDA 13 / cu130 的套件**（詳見 notes）。
- LLMs and video models **share the same 128 GB**. Run one heavy workload at a time;
  prefer quantised video models (NVFP4 / int8 / fp8).
  LLM 與影片模型**共用 128GB**，建議**一次跑一種重負載**；影片模型優先用**量化版**。
- These are 2026-08-era model releases. If official filenames or nodes change, the
  safest route is letting the **ComfyUI template download them automatically**.
  這些模型是 2026-08 的新版本；若官方檔名/節點有變，最保險是讓 **ComfyUI Template 自動下載**。

## Repository layout / 目錄結構

```
LLM-Explorer/
├── README.md                   # this file 本檔
├── install.sh                  # interactive installer 互動式安裝腳本
├── chatbot/                    # Open WebUI + Ollama (Docker)
│   ├── start.sh  stop.sh  pull-models.sh  models.txt
├── comfyui/                    # ComfyUI (native venv 原生 venv)
│   ├── setup.sh  start.sh  stop.sh  download-models.sh
│   └── workflows/              # comparison workflow notes + your exported .json
├── compare/                    # comparison tool 比較工具
│   ├── server.py  index.html  start.sh  stop.sh  tunnel.sh
│   └── workflows/              # captured per-model workflows 擷取到的各模型 workflow
├── space/                      # HuggingFace Space frontend 前端
└── docs/notes.md               # hardware / memory / troubleshooting 硬體·記憶體·疑難排解
```
