# 架構說明

[English](ARCHITECTURE.md) · **繁體中文** · [简体中文](ARCHITECTURE.zh-CN.md)

三個各自獨立的本地服務，外加一個選用的遠端前端。這裡沒有任何分散式系統：所有行程都跑在
同一台 DGX Spark 上，彼此透過 loopback 溝通。

## 服務拓樸

```
                         ┌─────────────────────────────┐
  瀏覽器  ───────────────▶  Open WebUI + Ollama  :8080 │  Docker，自帶認證
                         └─────────────────────────────┘

                         ┌─────────────────────────────┐
  瀏覽器  ───────────────▶  比較伺服器          :8890  │  python3，僅標準函式庫
                         └──────────────┬──────────────┘
                                        │ HTTP，loopback
                         ┌──────────────▼──────────────┐
  瀏覽器  ───────────────▶  ComfyUI             :8188  │  venv，無認證
                         └─────────────────────────────┘
                                        │
                                   GPU：GB10

  HuggingFace Space ──── cloudflared 通道 ───▶ :8890  （僅對外模式）
```

| 服務 | 埠 | 綁定 | 行程模型 |
|---|---|---|---|
| Open WebUI + Ollama | 8080 | `127.0.0.1` | Docker，`--restart unless-stopped` |
| ComfyUI | 8188 | `127.0.0.1` | venv Python，`comfyui/run.sh` |
| 比較伺服器 | 8890 | `0.0.0.0` | 標準函式庫 Python，`compare/run.sh` |

比較伺服器**完全不依賴標準函式庫以外的套件**，建在 `http.server` 上，並代理 ComfyUI。
這是刻意的：即使 ComfyUI 的 venv 壞掉，它也必須能啟動，網頁才有辦法告訴你壞在哪。

## 一次生成的完整流程

1. 瀏覽器 POST 到 `/api/generate`，帶上 prompt、seed、類型（`image`／`video`）、
   勾選的模型 id 與解析度。
2. 伺服器為每個模型載入 `compare/workflows/<id>.<type>.json`——先前擷取下來的 ComfyUI
   API 格式圖——並改寫其中兩樣東西：正向 prompt 節點，以及所有字面上的 `seed` / `noise_seed`。
3. 把每張圖 POST 到 ComfyUI 的 `/prompt`，取回 prompt id。
4. 瀏覽器針對每個模型輪詢 `/api/status?id=…`。伺服器向 ComfyUI 查詢 history 與佇列狀態，
   回答 `queued`、`running` 或完成的結果。
5. 完成的輸出透過 `/api/view` 取回，它代理 ComfyUI 的 view 端點，所以瀏覽器完全不需要
   自己連到 8188。

同一個 seed、同一個 prompt 送給每個選取的模型——這正是重點：其他變因都一樣，比較才公平。

### 怎麼找到 prompt 節點

擷取到的 workflow 是別人的圖，所以伺服器必須**找出** prompt 輸入在哪，而不能假設節點 id。
`find_positive_node()` 依序嘗試：從 sampler 的 `positive` 連線往回走；再找輸入名稱就叫
`prompt` 或 `text` 的節點，優先挑 `_meta` 標題裡沒有 "negative" 的文字編碼類與影片包裝類節點。
都找不到時，退而尋找字面上的 `__PROMPT__` 佔位字串。

## 擷取 workflow

沒有可執行的圖，卡片就毫無用處。擷取流程是：

1. 在 ComfyUI 裡開啟該模型的官方範本，執行一次。
2. 回到卡片上按 **🎯 Capture from ComfyUI**。伺服器讀取 ComfyUI 的 history，取最近一張圖，
   從圖中的檔名辨識出是哪個模型（`compare/server.py` 裡的 `SIGNATURES`），然後寫出
   `compare/workflows/<id>.<type>.json` 以及旁邊的 `.meta.json`。

這也是為什麼 `/api/capture`、`/api/import`、`/api/savewf`、`/api/uitpl` 在對外模式下被封鎖：
它們合起來可以寫入檔案、把任意圖推進 ComfyUI，等同於對這台機器的讀寫權限。

## 讓三份清單保持同步

「卡片提供什麼」「它的 workflow 載入什麼」「下載器抓什麼」三者之間的落差，既安靜又昂貴。
`tools/check-models.py` 會比對這三者，不一致就失敗。它**只讀節點 `inputs` 底下的值**：
widget 的下拉選單也會列出磁碟上存在的其他檔案，拿那些去比對會用假的相符掩蓋真正的缺口。

## 國際化

不用框架。標記上掛 `data-i18n`、`data-i18n-title`、`data-i18n-ph`；`i18n.js` 每種語言
一份字串表，負責把文字換上去。

```
detectLang()   localStorage 'lang' → navigator.languages → en
               zh-Hant|tw|hk|mo → zh-TW · 其他 zh → zh-CN · 其餘 → en
t(key, vars)   查表 → 退回英文 → 最後退回 key 本身；支援 {param} 代入
applyI18n()    填入所有 [data-i18n*] 節點，並同步 <html lang> 與 document.title
setLang()      記住選擇並重新執行所有監聽器
```

每一層的 fallback 都是英文，所以翻到一半只會退回英文，不會冒出原始 key。
`docs/index.html` 更進一步：首頁在每個待翻譯元素裡內嵌英文預設值，所以**停用 JavaScript
也讀得懂**，而語言選單預設帶 `hidden`，由執行期才顯示出來。

### 錯誤以「代碼」跨越網路

伺服器從不回傳翻譯過的句子。`err("CODE", **params)` 產生的是：

```json
{"error_code": "PROMPT_TOO_LONG", "error_params": {"max": 2000},
 "error": "Prompt too long (max 2000 characters)"}
```

瀏覽器渲染的是 `t("err.PROMPT_TOO_LONG", {max: 2000})`。那個英文 `error` 欄位是給不做翻譯的
用戶端用的——`curl`，以及 `space/` 裡的 Gradio 前端。兩個方向都保持相容：舊用戶端忽略代碼、
直接印 `error`；新用戶端遇到不認得的代碼時退回 `error`。

`tools/check-i18n.py` 會在某個 `err("CODE")` 缺少 `ERROR_TEXT` 條目或 `err.CODE` 翻譯時失敗。

## 行程監管

每個長時間執行的服務都有三層：

```
run.sh     前景執行，持有啟動參數，以 exec 收尾   ← 真正的行程
start.sh   nohup run.sh &，寫 PID 檔              ← 互動使用
*.service  Type=simple，ExecStart=run.sh          ← 開機、重啟、journal
```

`exec` 很關鍵：少了它，PID 檔和 systemd 追蹤到的都會是外層的 shell，而不是真正佔住埠的那個行程。

PID 檔會比對 `/proc/<pid>/cmdline`，不只是 `kill -0`。重開機後核心會重新發放小號 PID，
所以殘留的 PID 往往屬於某個不相干的 daemon——而天真的檢查會回報「已在執行」然後什麼都不啟動。

systemd unit 設了 `StartLimitIntervalSec=300` / `StartLimitBurst=5`。預設限制是「10 秒內 5 次」，
而 `RestartSec=10` 的 unit 永遠碰不到那個門檻，於是壞掉的服務會無限重試而沒人發現。

## 狀態存放位置

| 內容 | 位置 | 進版控？ |
|---|---|---|
| 模型權重 | `comfyui/ComfyUI/models/` | 否 |
| 下載來源記錄 | `…/models/<sub>/.<file>.from` | 否 |
| 擷取到的 workflow | `compare/workflows/*.json` | **是** |
| 對外模式密鑰 | `compare/.token` | 否，而且永遠不要 |
| 本機環境覆寫 | `compare/.env` | 否 |
| 日誌、PID 檔 | `*/\*.log`、`*/\*.pid` | 否 |
| 生成輸出 | ComfyUI 自己的 output 目錄 | 否 |

擷取到的 workflow 刻意進版控：它們就是「每張卡片實際跑什麼」的定義，而
`tools/check-models.py` 要讀它們。

## 對外開放

選用、預設關閉、而且有互鎖。`compare/tunnel.sh` 在「未認證請求回傳 401」之前會拒絕開啟
Cloudflare 通道——所以通道不可能被開到一台沒設密鑰的伺服器上。`space/` 裡的 Space 前端是
一個 Gradio 應用，帶著共享密鑰呼叫通道網址。

完整的安全態勢見 [SECURITY.zh-TW.md](../SECURITY.zh-TW.md)，包含把 8890 綁在 `0.0.0.0`
對你的網路代表什麼。
