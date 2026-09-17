[English](README.md) · **繁體中文** · [简体中文](README.zh-CN.md)

# LLM Explorer — Space 前端

這個 Space 只是**介面**。實際的影片／圖片生成跑在一台本地 NVIDIA GB10（DGX Spark）上，
透過通道連過去。Space 本身不含任何模型權重。

## 安全模型

三層，缺一不可：

| 層 | 機制 | 擋住什麼 |
|---|---|---|
| 1 | Space 設為 private + `SPACE_USERS` 帳密 | 誰能打開這個 UI |
| 2 | 共享密鑰 `COMPARE_TOKEN` | 只有這個 Space 打得進那台機器 |
| 3 | 機器端 `server.py` 的端點白名單 | 前兩層外洩時，也只能生成，不能寫檔或塞任意 workflow |

第 3 層是關鍵：機器端只要設了 `COMPARE_TOKEN` 就會自動封鎖 `/api/import`、`/api/savewf`、
`/api/capture`、`/api/uitpl`、`/api/stop`，並套用解析度白名單與佇列上限。詳見 `compare/server.py`。

## 設定

在 Space 的 **Settings → Variables and secrets** 加入：

| 名稱 | 類型 | 說明 |
|---|---|---|
| `COMPARE_URL` | Secret | 通道網址，例如 `https://xxx.trycloudflare.com` |
| `COMPARE_TOKEN` | Secret | 與機器端 `server.py` 相同的密鑰 |
| `SPACE_USERS` | Secret | 登入帳密 `alice:pw1,bob:pw2`；Space 已是 private 時可省略 |

機器端對應的啟動方式：

```bash
# 直接帶入密鑰：
COMPARE_TOKEN='與上面相同的密鑰' ./compare/start.sh

# 或存成檔案，start.sh 會自動讀取：
echo '與上面相同的密鑰' > compare/.token && ./compare/start.sh
```

## 已知限制

- **影片很慢**：HD 約 2~5 分鐘一支，FHD 更久，主機一次只跑一個工作。
- 送出後必須保持分頁開著，關掉就收不到結果。
- 2K／4K 不開放：MiniMax H3 在該 token 數下會產生網格偽影，關掉稀疏注意力則直接 OOM。
- 主機關機時 Space 會顯示生成主機離線。
- 這個 Space 的介面本身只有英文；三語介面在自架的比較頁面（`compare/index.html`）上。
