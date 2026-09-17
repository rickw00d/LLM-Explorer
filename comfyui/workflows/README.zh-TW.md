[English](README.md) · **繁體中文** · [简体中文](README.zh-CN.md)

# ComfyUI 生圖／生影片模型比對 workflow

這些模型都很新，官方模板隨版本更新最準確。**最可靠**的取得方式是直接用 ComfyUI 內建 Template，
它會對應到當下正確的節點與模型檔（缺檔會提示自動下載）。

## 取得官方模板

在 ComfyUI 介面：左上 **Workflow → Browse Templates**（或 **Templates** 面板），搜尋：

- **LTX-2.5** — 官方 T2V / I2V / 含音訊模板
- **Wan 2.2** — T2V（單張輸出即等同文生圖）
- **MiniMax H3** — 選 **Local / open-weights** 版本的三個模板（**不要**選 API 版）
- **Flux.2 Klein**、**Qwen-Image**、**Z-Image Turbo** — 文生圖模板

線上對照文件：

- LTX-2.5： https://docs.comfy.org/tutorials/video/ltx/ltx-2-5
- Wan 2.2： https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2
- MiniMax H3： https://comfyui-wiki.com/en/tutorial/advanced/video/minimax/minimax-h3

## 做「公平比對」的方法

要比較多個模型，關鍵是**控制變因一致**：

1. 同一段 prompt、同一個 seed、同樣的解析度／影格數／步數。
2. 逐一各跑一次。記憶體雖大，但一次跑一個重模型最穩，也最好對照時間。
3. 記錄每次的：產出檔、耗時（ComfyUI 右下角或 log）、峰值記憶體（另開 `watch -n2 nvidia-smi`）。
4. 想並排在同一張圖：把每個模型的輸出接到 **Save Image/Video**，或用 **Image/Video Combine** 節點拼接。

> 進階：可把多個模板合到同一張畫布，共用同一個「CLIP Text Encode（prompt）」與固定 seed 的
> primitive 節點，分別接到各個 sampler，一次 Queue 跑完。做好後 **Save (API/JSON)** 匯出，
> 放回本資料夾（例如 `compare_ltx_wan_h3.json`）方便重複使用。

## 存放你自己的 workflow

把在 ComfyUI 裡調好、匯出的 `.json` 放到這個資料夾，之後用 **Workflow → Open** 載入即可重現。

> 注意：比較工具自己擷取的 workflow 放在 `compare/workflows/`（`<模型>.<image|video>.json`
> 與對應的 `.meta.json`），由 **🎯 從 ComfyUI 擷取** 按鈕寫入，與本資料夾無關。
