# 安全性政策

[English](SECURITY.md) · **繁體中文** · [简体中文](SECURITY.zh-CN.md)

## 回報安全漏洞

請透過 GitHub 的私密通報表單回報，不要開公開 issue：

**<https://github.com/rickw00d/LLM-Explorer/security/advisories/new>**

請說明攻擊者能碰到什麼、重現步驟、以及你測試的 commit。切勿附上任何 token、`.env`
或 `Secret/` 裡的內容。

這是個人專案，不是有輪值待命的商業產品，大約一週內會收到回覆。

只支援 `main` 分支，沒有需要回溯修補的發行版本。

## 這套軟體會暴露什麼

在把這台機器接上你無法完全掌控的網路之前，請先讀這一段。三個服務的暴露程度不同，
而且其中一個**預設就能從區域網路連到**。

| 服務 | 埠 | 綁定位址 | 認證 |
|---|---|---|---|
| Open WebUI + Ollama | 8080 | `127.0.0.1` | 自帶帳號系統 |
| ComfyUI | 8188 | `127.0.0.1` | **完全沒有** |
| 模型比較工具 | 8890 | **`0.0.0.0`**（所有介面） | 沒有，除非設了密鑰 |

有兩點必須講白：

- **ComfyUI 沒有任何認證。** 任何連得到 8188 的人都能排入任意 workflow，等同於在
  ComfyUI 行程權限範圍內讀寫本機檔案。它綁在 loopback 正是為了這個原因，請不要對外開放。
- **比較工具綁定所有網路介面。** 預設狀態下，同網段的任何裝置都能打開它；在本機模式
  （無密鑰）下，也沒有任何東西能阻止他們透過它操作你的 ComfyUI。設
  `COMPARE_HOST=127.0.0.1` 可限回本機，或者設一組密鑰。

## 對外模式

設定 `COMPARE_TOKEN`（或建立 `compare/.token`）會讓比較伺服器切換到對外模式：

1. 每個 `/api/*` 呼叫都必須帶上相符的 `X-Compare-Token` 標頭。比對採用
   `hmac.compare_digest`，是常數時間比較。
2. 管理端點 —— `/api/import`、`/api/savewf`、`/api/capture`、`/api/uitpl` —— 全部封鎖。
   它們會寫入檔案或把任意 workflow 推進 ComfyUI，等同於對本機的讀寫權限。
   `COMPARE_ADMIN=1` 可以解除封鎖，但只該在可信任的網路上這麼做。
3. 解析度白名單、佇列數上限、模型數上限、prompt 長度上限同時生效。

`/api/stop` **刻意不列為**管理端點：中斷自己送出的工作不是寫入操作，而且遠端介面需要它。

### 通道互鎖

`compare/tunnel.sh` 在「未認證請求回傳 401」之前會拒絕開啟 Cloudflare 通道。這個檢查
存在的目的，就是讓通道不可能被開到一台沒設密鑰的伺服器上。請不要拿掉它。

```bash
openssl rand -hex 32 > compare/.token   # 絕對不要提交這個檔案
cd compare && ./start.sh                # 會自動讀取密鑰
./tunnel.sh start
```

## 強化檢查清單

- [ ] 不需要區網存取的話，設 `COMPARE_HOST=127.0.0.1`
- [ ] 需要的話，在 `compare/.token` 放一組密鑰
- [ ] 對外模式下不要設 `COMPARE_ADMIN`
- [ ] ComfyUI 保持在 loopback，不要加 `--listen`
- [ ] 用防火牆把 8188 對區網擋掉
- [ ] `compare/.token`、`compare/.env`、`Secret/` 三者皆未進版控——它們都在 `.gitignore` 裡，
      用 `git status --porcelain --ignored` 可以確認

## 不在範圍內

以下是已知且刻意為之，不算漏洞：

- ComfyUI 本身不帶認證。那是上游的設計，本專案的因應方式是把它綁在 loopback。
- 因為你自己改了綁定位址、開了防火牆埠、或設了 `COMPARE_ADMIN=1` 才連得到的東西。
- 從 HuggingFace 下載的權重。要不要信任某個模型庫是你的判斷；`download-models.sh`
  抓的是 `.safetensors`，載入時不會執行程式碼，但惡意的 workflow 仍然可以。
