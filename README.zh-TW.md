[English](README.md) · **繁體中文** · [简体中文](README.zh-CN.md)

# LLM Explorer — DGX Spark（GB10）本地 AI 工作站

在一台 **GB10 Grace Blackwell**（128GB 統一記憶體）上跑三套本地服務：多 LLM 聊天、
用 ComfyUI 生圖／生影片，以及「同一個 prompt、多模型並排比較」的網頁工具。

| 服務 | 用途 | 網址 | 目錄 |
|---|---|---|---|
| **Open WebUI + Ollama** | 多 LLM 聊天，可熱切換模型 | http://localhost:8080 | [`chatbot/`](chatbot/) |
| **ComfyUI** | 生圖／生影片後端 | http://localhost:8188 | [`comfyui/`](comfyui/) |
| **模型比較工具** | 同一個 prompt，多模型並排比較（呼叫 ComfyUI API） | http://localhost:8890 | [`compare/`](compare/) |
| **HuggingFace Space 前端** | 選用的遠端介面，透過通道連回本機 | — | [`space/`](space/) |

> Open WebUI 與 ComfyUI **只綁定 127.0.0.1**。模型比較工具預設綁定
> **`0.0.0.0`（所有網路介面）**，同網段的其他裝置可以直接連上；想限回本機，
> 設 `COMPARE_HOST=127.0.0.1`。沒有密鑰時，任何連得到 8890 的人都能把任意
> workflow 推進你的 ComfyUI —— 請設密鑰（見[對外開放](#4-對外開放選用)）或用防火牆擋掉這個埠。

硬體限制與記憶體管理見 [`docs/notes.zh-TW.md`](docs/notes.zh-TW.md)。

---

## 快速開始：一鍵安裝

互動式安裝腳本涵蓋以下所有步驟：系統檢查、ComfyUI 環境、模型下載、啟動服務與 chatbot。

```bash
git clone https://github.com/rickw00d/LLM-Explorer.git
cd LLM-Explorer
./install.sh          # ↑↓ 移動 · Space 勾選 · Enter 開始
```

選單項目：

1. 系統初始化 — 套件、Docker、CUDA 檢查
2. ComfyUI 環境 — venv + PyTorch cu130
3. 影片模型 — LTX-2.5 / MiniMax H3 / Wan 2.2
4. 圖片模型 — Flux.2 Klein / Qwen-Image / Z-Image Turbo
5. 啟動 ComfyUI + 比較工具
6. Chatbot — Open WebUI + Ollama + LLM

全程記錄在 `install.log`；預設全部不勾選，請用 Space 選取。

> 腳本的選單與終端輸出一律為英文，中文使用說明由本文件承擔。

想手動安裝的話，請看以下步驟。

---

## 0. 一次性前置

```bash
# 讓目前使用者能用 docker（之後要登出再登入，或 newgrp docker）
sudo usermod -aG docker $USER

# Triton 執行期即時編譯需要的開發標頭檔；沒裝的話 ComfyUI 生成會失敗
sudo apt-get update && sudo apt-get install -y python3-dev build-essential

# 下載模型用的 HuggingFace CLI（ComfyUI 部分需要）
pip install -U "huggingface_hub[cli]"
hf auth login          # LTX-2.5 為 gated，需先到其 HF 頁面接受授權
```

## 1. Chatbot（多 LLM）

```bash
cd chatbot
./start.sh             # 啟動 Open WebUI（首次會拉映像檔）
./pull-models.sh       # 依 models.txt 下載模型
# 瀏覽器開 http://localhost:8080 → 建本機管理員帳號 → 在 UI 切換模型對話
./stop.sh              # 停止（加 --remove 連容器一起刪，模型／設定仍保留）
```

想加／減模型：編輯 [`chatbot/models.txt`](chatbot/models.txt) 後再跑 `./pull-models.sh`；
也可以只拉單一模型：`./pull-models.sh qwen3:8b`。

## 2. ComfyUI（生圖／生影片）

```bash
cd comfyui
./setup.sh             # 建 venv + 裝 cu130 PyTorch + 最新 ComfyUI + Manager
./download-models.sh   # 下載全部；也可指定 ltx|wan|h3|flux2|qwen|zimage|video|image
./start.sh             # 背景啟動 → http://localhost:8188
./stop.sh              # 停止
```

涵蓋的模型：

| 模型 | 類型 | 備註 |
|---|---|---|
| LTX-2.5（Lightricks，22B int8） | 影片 | gated repo，需先接受授權 |
| MiniMax H3 / Hailuo 3.0（int8） | 影片 | 用**本地開放權重版**模板，不要用 API 版 |
| Wan 2.2 T2V 14B（fp8） | 影片 | 單張輸出即等同文生圖 |
| Flux.2 Klein（9B fp8） | 圖片 | |
| Qwen-Image-2512（bf16） | 圖片 | |
| Z-Image Turbo（6B bf16） | 圖片 | 蒸餾版，較快 |

公平比對方法（同 prompt／同 seed）見
[`comfyui/workflows/README.zh-TW.md`](comfyui/workflows/README.zh-TW.md)。

## 3. 模型比較工具

一個網頁：輸入一個 prompt → 對選定的模型各跑一次 → 同頁並排比較（含耗時）。
網頁提供英文、繁體中文、簡體中文三種語言，會依瀏覽器語言自動選擇，
也會記住你在語言選單中的選擇。

```bash
cd compare && ./start.sh        # ComfyUI 沒在跑的話會一併啟動
                                # → http://localhost:8890
./stop.sh                       # 兩個一起停
```

首次使用：在每個模型的卡片按 **🎯 從 ComfyUI 擷取**（先在 ComfyUI 開該模型 Template 按一次 Run），
工具會自動抓取並辨識模型。之後輸入 prompt、選圖片／影片、勾選模型，按「一次生成並比較」。

環境變數：

| 變數 | 預設 | 意義 |
|---|---|---|
| `COMFY_URL` | `http://127.0.0.1:8188` | ComfyUI 後端位址 |
| `COMPARE_HOST` / `COMPARE_PORT` | `0.0.0.0` / `8890` | 綁定位址 —— `0.0.0.0` 是所有介面，只要本機請設 `127.0.0.1` |
| `COMPARE_TOKEN` | *(空)* | 設了就進入對外模式 |
| `COMPARE_MAX_PENDING` / `COMPARE_MAX_MODELS` / `COMPARE_MAX_PROMPT` | `8` / `3` / `2000` | 對外模式上限 |

> ⚠️ 首次生成前必須先裝 `python3-dev`（見 [docs/notes.zh-TW.md](docs/notes.zh-TW.md) 疑難排解），
> 否則 ComfyUI 會因 Triton 缺標頭檔而失敗。

## 4. 對外開放（選用）

比較工具內建對外模式：設了 `COMPARE_TOKEN` 之後，所有 `/api/*` 都要帶
`X-Compare-Token` 標頭，管理端點（`/api/import`、`/api/savewf`、`/api/capture`、
`/api/uitpl`、`/api/stop`）全部封鎖，並套用解析度白名單與佇列上限。

```bash
# 1. 建立共享密鑰（絕對不進版控，.token 已在 .gitignore）
openssl rand -hex 32 > compare/.token

# 2. start.sh 會自動讀取 .token，以對外模式啟動
cd compare && ./start.sh

# 3. 開 Cloudflare 通道。未授權請求若不是回 401 就拒絕啟動，這個連鎖鎖是刻意的。
./tunnel.sh start | stop | status
```

[`space/`](space/) 是搭配的 HuggingFace Space 遠端前端，三層安全模型見
[`space/README.zh-TW.md`](space/README.zh-TW.md)。

---

## 5. 開機自動啟動（選用）

```bash
bash systemd/install.sh
```

會安裝兩個 systemd **user** service（`comfyui.service` 與 `llm-compare.service`），
啟用 lingering 讓它們開機就跑、不必先登入桌面，並停用舊版的單一
`llm-explorer.service`（若有安裝）。

```bash
systemctl --user status comfyui llm-compare
journalctl --user -u comfyui -f
systemctl --user restart llm-compare
```

兩個 unit 都執行 `run.sh`；啟動參數寫在裡面，而且用 `exec`，所以 systemd 監管的是
真正的行程而不是外層包裝。Open WebUI 不需要另外設定，它的容器本身就帶了
`--restart unless-stopped`。

> 自己手寫 unit 的話，`ExecStart` 的路徑一定要加引號。systemd 會以空白切分那一行，
> 所以路徑只要含空格就會變成另一個指令，服務以 `status=203/EXEC` 失敗並無限重試。
> `systemd/install.sh` 會幫你把引號加好。

---

## 重要提醒

- **架構是 aarch64 + Blackwell sm_121，只能用 CUDA 13 / cu130 的套件**（詳見 notes）。
- LLM 與影片模型**共用 128GB**，建議一次跑一種重負載；影片模型優先用量化版（NVFP4 / int8 / fp8）。
- 這些模型是 2026-08 的新版本；若官方檔名／節點有變，最保險是讓 **ComfyUI Template 自動下載**。

## 語言

文件維護英文、繁體中文（`*.zh-TW.md`）、簡體中文（`*.zh-CN.md`）三種版本。
腳本、程式碼註解與終端輸出刻意只用英文，讓程式碼保持易讀；使用者導向的說明都放在翻譯文件裡。
比較工具的網頁 UI 則在執行期支援三種語言，見 [`compare/i18n.js`](compare/i18n.js)
與 [`docs/i18n.js`](docs/i18n.js)。

要新增語言：在這兩個檔案的 `LANGS` 加一筆、`I18N` 加一張表即可；缺少的 key 會自動退回英文，
因此翻譯到一半也能安全上線。執行 `python3 tools/check-i18n.py` 可檢查字串表、網頁標記與
後端錯誤碼三者是否一致。

## 目錄結構

```
LLM-Explorer/
├── README.md                   # 英文（主）
├── README.zh-TW.md             # 本檔
├── README.zh-CN.md             # 簡體中文
├── install.sh                  # 互動式安裝腳本
├── chatbot/                    # Open WebUI + Ollama（Docker）
│   ├── start.sh  stop.sh  pull-models.sh  models.txt
├── comfyui/                    # ComfyUI（原生 venv）
│   ├── setup.sh  start.sh  run.sh  stop.sh  download-models.sh
│   └── workflows/              # 比對 workflow 說明 + 你匯出的 .json
├── compare/                    # 比較工具
│   ├── server.py  index.html  i18n.js  start.sh  run.sh  stop.sh  tunnel.sh
│   └── workflows/              # 擷取到的各模型 workflow
├── systemd/                    # 開機自動啟動用的 user service（install.sh）
├── space/                      # HuggingFace Space 前端
└── docs/                       # 說明文件 + GitHub Pages（index.html、i18n.js）
```
