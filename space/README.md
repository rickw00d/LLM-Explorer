---
title: LLM Explorer
emoji: 🎬
colorFrom: orange
colorTo: purple
sdk: gradio
sdk_version: 6.26.0
app_file: app.py
pinned: false
---

# LLM Explorer — Space frontend / Space 前端

This Space is **the interface only**. The actual video and image generation runs on a
local NVIDIA GB10 (DGX Spark class) machine, reached through a tunnel. No model weights
live in this Space.

這個 Space 只是**介面**。實際的影片／圖片生成跑在一台本地 NVIDIA GB10（DGX Spark）上，
透過通道連過去。Space 本身不含任何模型權重。

## Security model / 安全模型

Three layers, all required / 三層，缺一不可：

| Layer 層 | Mechanism 機制 | What it stops 擋住什麼 |
|---|---|---|
| 1 | Space set to private + `SPACE_USERS` credentials<br>Space 設為 private + `SPACE_USERS` 帳密 | Who can open this UI at all<br>誰能打開這個 UI |
| 2 | Shared secret `COMPARE_TOKEN`<br>共享密鑰 `COMPARE_TOKEN` | Only this Space can reach the machine<br>只有這個 Space 打得進那台機器 |
| 3 | Endpoint allow-list in `server.py` on the machine<br>機器端 `server.py` 端點白名單 | If layers 1–2 leak, callers can still only generate — not write files or inject arbitrary workflows<br>前兩層外洩時，也只能生成，不能寫檔或塞任意 workflow |

Layer 3 is the important one: as soon as `COMPARE_TOKEN` is set, the machine blocks
`/api/import`, `/api/savewf`, `/api/capture`, `/api/uitpl` and `/api/stop`, and applies
the resolution allow-list and queue limits. See `compare/server.py`.

第 3 層是關鍵：機器端只要設了 `COMPARE_TOKEN` 就會自動封鎖 `/api/import`、`/api/savewf`、
`/api/capture`、`/api/uitpl`、`/api/stop`，並套用解析度白名單與佇列上限。詳見 `compare/server.py`。

## Configuration / 設定

Add these under the Space's **Settings → Variables and secrets**:
在 Space 的 **Settings → Variables and secrets** 加入：

| Name 名稱 | Type 類型 | Description 說明 |
|---|---|---|
| `COMPARE_URL` | Secret | Tunnel URL, e.g. `https://xxx.trycloudflare.com`<br>通道網址，例如 `https://xxx.trycloudflare.com` |
| `COMPARE_TOKEN` | Secret | Same secret as `server.py` on the machine<br>與機器端 `server.py` 相同的密鑰 |
| `SPACE_USERS` | Secret | Login pairs `alice:pw1,bob:pw2`; optional if the Space is already private<br>登入帳密；Space 已是 private 時可省略 |

Matching start-up on the machine / 機器端對應的啟動方式：

```bash
# Either export the token explicitly… / 直接帶入密鑰：
COMPARE_TOKEN='the same secret 與上面相同的密鑰' ./compare/start.sh

# …or store it once and let start.sh pick it up / 或存成檔案，start.sh 會自動讀取：
echo 'the same secret' > compare/.token && ./compare/start.sh
```

## Known limitations / 已知限制

- **Video is slow**: roughly 2–5 minutes for HD, longer for FHD, and the host runs one
  job at a time.
  **影片很慢**：HD 約 2~5 分鐘一支，FHD 更久，主機一次只跑一個工作。
- Keep the tab open after submitting — closing it loses the result.
  送出後必須保持分頁開著，關掉就收不到結果。
- 2K/4K is not offered: at that token count MiniMax H3 produces grid artefacts, and
  disabling sparse attention runs out of memory.
  2K／4K 不開放：MiniMax H3 在該 token 數下會產生網格偽影，關掉稀疏注意力則直接 OOM。
- When the host is powered off, the Space reports that the generation host is offline.
  主機關機時 Space 會顯示「生成主機離線」。
