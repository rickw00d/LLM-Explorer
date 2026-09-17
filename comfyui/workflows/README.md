# Comparison workflows for ComfyUI image/video models
# ComfyUI 生圖/生影片模型比對 workflow

These models are all recent, and the official templates track node and file changes
better than anything checked into a repo. The **most reliable** way to get a working
graph is ComfyUI's built-in Template browser — it maps to the correct nodes and model
files for your installed version, and offers to download anything missing.

這些模型都很新，官方模板隨版本更新最準確。**最可靠**的取得方式是直接用 ComfyUI 內建 Template，
它會對應到當下正確的節點與模型檔（缺檔會提示自動下載）。

## Getting the official templates / 取得官方模板

In the ComfyUI interface: top-left **Workflow → Browse Templates** (or the **Templates**
panel), then search for:

在 ComfyUI 介面：左上 **Workflow → Browse Templates**（或 **Templates** 面板），搜尋：

- **LTX-2.5** — official T2V / I2V / with-audio templates / 官方 T2V / I2V / 含音訊模板
- **Wan 2.2** — T2V (a single-frame output is effectively text-to-image) / T2V（單張輸出即等同文生圖）
- **MiniMax H3** — pick the three **Local / open-weights** templates, **not** the API ones
  / 選 **Local / open-weights** 版本的三個模板（**不要**選 API 版）
- **Flux.2 Klein**, **Qwen-Image**, **Z-Image Turbo** — text-to-image templates / 文生圖模板

Online references / 線上對照文件:

- LTX-2.5: https://docs.comfy.org/tutorials/video/ltx/ltx-2-5
- Wan 2.2: https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2
- MiniMax H3: https://comfyui-wiki.com/en/tutorial/advanced/video/minimax/minimax-h3

## How to compare fairly / 做「公平比對」的方法（重點）

The point of a comparison is holding everything except the model constant.
要比較多個模型，關鍵是**控制變因一致**：

1. Same prompt, same seed, same resolution / frame count / step count.
   **同一段 prompt**、**同一個 seed**、**同樣的解析度/影格數/步數**。
2. Run them one at a time. Memory is large, but one heavy model at a time is the most
   stable and makes the timings comparable.
   逐一各跑一次（記憶體雖大，但一次跑一個重模型最穩、也最好對照時間）。
3. Record for each run: the output file, the elapsed time (bottom-right of ComfyUI, or
   the log) and peak memory (`watch -n2 nvidia-smi` in another terminal).
   記錄每次的：產出檔、耗時（ComfyUI 右下角或 log）、峰值記憶體（另開 `watch -n2 nvidia-smi`）。
4. To line the results up in one image, feed each model's output into **Save Image/Video**,
   or stitch them with an **Image/Video Combine** node.
   想並排在同一張圖：把每個模型的輸出接到 **Save Image/Video**，或用 **Image/Video Combine** 節點拼接。

> Advanced: put several templates on one canvas sharing a single **CLIP Text Encode**
> (prompt) node and a fixed-seed primitive, wired to each sampler, so one Queue run
> covers all of them. Export it with **Save (API/JSON)** and drop it back into this
> folder (e.g. `compare_ltx_wan_h3.json`) for reuse.
> 進階：可把多個模板合到同一張畫布，共用同一個「CLIP Text Encode（prompt）」與固定 seed 的
> primitive 節點，分別接到各個 sampler，一次 Queue 跑完。做好後 **Save (API/JSON)** 匯出，
> 放回本資料夾（例如 `compare_ltx_wan_h3.json`）方便重複使用。

## Storing your own workflows / 存放你自己的 workflow

Drop the `.json` files you tuned and exported in ComfyUI into this folder; reload them
later with **Workflow → Open**.

把在 ComfyUI 裡調好、匯出的 `.json` 放到這個資料夾，之後用 ComfyUI 的 **Workflow → Open** 載入即可重現。

> Note: the comparison tool keeps its own captured workflows in `compare/workflows/`
> (`<model>.<image|video>.json` plus a `.meta.json`). Those are written by the
> **🎯 Capture from ComfyUI** button and are separate from this folder.
> 注意：比較工具自己擷取的 workflow 放在 `compare/workflows/`（`<模型>.<image|video>.json`
> 與對應的 `.meta.json`），由 **🎯 從 ComfyUI 擷取** 按鈕寫入，與本資料夾無關。
