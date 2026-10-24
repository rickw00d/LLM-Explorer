# 參與貢獻

[English](CONTRIBUTING.md) · **繁體中文** · [简体中文](CONTRIBUTING.zh-CN.md)

感謝你撥空看這份文件。這個專案是在單台 DGX Spark（GB10）上跑多個生成式模型的工具組，
大部分的貢獻不外乎三類：新增一張模型卡片、修一支腳本、或更正文件。

## 動手之前

這裡沒有建置步驟。你需要 `bash`、`python3`，若要改網頁 UI 則需要 `node` 做語法檢查。

```bash
git clone https://github.com/rickw00d/LLM-Explorer.git
cd LLM-Explorer
python3 tools/check-i18n.py     # 三語字串表是否一致
python3 tools/check-models.py   # 卡片、workflow、下載目標是否一致
```

乾淨的 checkout 上這兩個都該通過。若沒通過，那本身就是值得回報的 bug。

## 檢查項目

這個專案沒有 CI、也沒有測試套件。以下四條指令就是契約：

```bash
for f in $(git ls-files '*.sh'); do bash -n "$f" || echo "FAIL $f"; done
python3 -m py_compile $(git ls-files '*.py')
node --check compare/i18n.js && node --check docs/i18n.js
python3 tools/check-i18n.py && python3 tools/check-models.py
```

開 PR 前請先跑過，並在 PR 裡寫明你實際執行了什麼。**語法檢查不等於測試**：如果你改了
`compare/start.sh`，就要真的把服務啟動起來確認。

## 語言

本專案採**英文為主、中文為輔**。所有使用者看得到的字串都有三種語言：英文、繁體中文
（`zh-TW`）、簡體中文（`zh-CN`）。

- **Markdown** —— 一種語言一個檔案：`README.md`、`README.zh-TW.md`、`README.zh-CN.md`。
  改一個就要三個一起改，並保留開頭的互連那一行。
- **網頁 UI** —— 執行期 i18n，不依賴任何框架。標記上掛 `data-i18n="key"`，字串放在
  `compare/i18n.js` 與 `docs/i18n.js`。新增 key 時三份表都要加。英文是 fallback，
  所以漏翻會退回英文，而不是顯示原始的 key。
- **Shell 腳本、Python、程式註解** —— **只用英文**。半夜兩點除錯的人在讀這些，一種語言就夠了。
- **`compare/server.py`** —— 絕對不要回傳翻譯過的句子。用 `err("CODE", **params)` 回傳
  **錯誤碼**，由前端以 `err.CODE` 這個 key 翻譯。回應同時帶一個純英文的 `error` 欄位，
  給不做翻譯的用戶端使用，例如 `curl` 和 HuggingFace Space 前端。

`tools/check-i18n.py` 會檢查：三語 key 是否對齊、標記裡用到的 key 是否都存在、每個
`err("CODE")` 是否都有對應的 `ERROR_TEXT` 與 `err.CODE` 翻譯、以及 `docs/index.html`
裡的英文預設值是否仍與字串表相符。

### 台灣用語與中國大陸用語

`zh-TW` 用台灣慣用語，`zh-CN` 用中國大陸慣用語。兩者**不是**互相做字元轉換就好——
影片／视频、檔案／文件、記憶體／内存等等都不同。請分別好好寫，不要拿簡繁轉換工具套。

## 新增一個模型到比較工具

一張卡片要五件事都成立才算完成，其中後三項 `tools/check-models.py` 會幫你把關：

1. **權重抓得到。** 在 `comfyui/download-models.sh` 加一個 `get_<name>()`，並接到 `case`
   分派。`dl()` 是用檔名 glob 比對，所以你只需要 repo id 和檔名，不需要 repo 內部路徑。
   記得一併加進 `video` 或 `image` 群組以及 `all`。
2. **模型認得出來。** 在 `compare/server.py` 的 `SIGNATURES` 加一筆，讓匯入的 workflow
   能從檔名被辨識。
3. **卡片存在。** 在 `compare/server.py` 的 `MODELS` 加 id、`MODEL_LABEL` 加標籤。
4. **workflow 已擷取。** 在 ComfyUI 裡開該模型的官方範本、跑一次，然後回到卡片上按
   **🎯 Capture from ComfyUI**，會寫出 `compare/workflows/<id>.<type>.json`。
5. **規格卡已翻譯。** 在 `compare/index.html` 用 `data-i18n` 加上 `info-card` 標記，
   並把字串加進 `compare/i18n.js` 的三份表。

有一條規則能避免這一切腐化：**下載目標抓的，必須就是擷取到的 workflow 載入的那些檔案。**
一張卡片的 workflow 要 NVFP4、下載器卻抓 int8——在你機器上看起來一切正常，直到別人重新安裝。

## Shell 腳本慣例

- 開頭一律 `set -euo pipefail`。某個指令允許失敗的話，用 `|| true` 明講，不要整個拿掉 `-e`。
- 小心 `set -e` 遇到管線：`grep` 找不到東西會回 1，腳本就無聲中止。這類管線結尾要加 `|| true`。
- 長時間執行的服務要有一支 **`run.sh`**，在前景執行並以 `exec` 收尾。`start.sh` 負責丟到背景，
  systemd 則直接監管它。啟動參數只有一份定義，而 `exec` 讓 PID 是真的。
- 不要只信 PID 檔。重開機會重新發小號 PID，判定「已在執行」之前要比對 `/proc/<pid>/cmdline`。
- 路徑要加引號。參考安裝位置的資料夾名稱含空格，而 systemd unit 的 `ExecStart=` 是以空白切分的。

## 機密資料

絕對不要提交 `compare/.token`、`compare/.env`、`Secret/` 底下任何東西，或 HuggingFace token。
它們都在 `.gitignore` 裡，請保持原狀。也不要貼到 issue 裡——bug 回報範本會請你確認這一點。

比較工具的對外模式之所以存在，就是為了確保通道不會在沒有共享密鑰的情況下被打開：
`tunnel.sh` 在未認證請求沒有回 401 之前會拒絕啟動。請不要削弱這個互鎖。

## Commit 與 Pull Request

- Commit 標題寫「改了什麼」，用祈使語氣：*Fix the HuggingFace login check*，而不是 *fixed stuff*。
- 在內文解釋**為什麼**。「做了什麼」看 diff 就知道。
- 一個 PR 處理一件事。
- 誠實填寫 PR 範本，包括你**沒有**驗證的部分。

## 回報問題

請使用 issue 範本，並先跑那兩個一致性檢查。如果是模型下載失敗，請附上確切的錯誤訊息：
下載器會區分「未登入」、「未接受授權」與「真的失敗」三種情況，而那個區分往往就是答案。
