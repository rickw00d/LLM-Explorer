[English](README.md) · [繁體中文](README.zh-TW.md) · **简体中文**

# ComfyUI 图像／视频模型对比 workflow

这些模型都很新，官方模板随版本更新最准确。**最可靠**的获取方式是直接用 ComfyUI 内置 Template，
它会对应到当下正确的节点与模型文件（缺文件会提示自动下载）。

## 获取官方模板

在 ComfyUI 界面：左上 **Workflow → Browse Templates**（或 **Templates** 面板），搜索：

- **LTX-2.5** — 官方 T2V / I2V / 含音频模板
- **Wan 2.2** — T2V（单张输出即等同文生图）
- **MiniMax H3** — 选 **Local / open-weights** 版本的三个模板（**不要**选 API 版）
- **Flux.2 Klein**、**Qwen-Image**、**Z-Image Turbo** — 文生图模板

在线参考文档：

- LTX-2.5： https://docs.comfy.org/tutorials/video/ltx/ltx-2-5
- Wan 2.2： https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2
- MiniMax H3： https://comfyui-wiki.com/en/tutorial/advanced/video/minimax/minimax-h3

## 做「公平对比」的方法

要比较多个模型，关键是**控制变量一致**：

1. 同一段 prompt、同一个 seed、同样的分辨率／帧数／步数。
2. 逐一各跑一次。内存虽大，但一次跑一个重模型最稳，也最便于对照时间。
3. 记录每次的：输出文件、耗时（ComfyUI 右下角或 log）、峰值内存（另开 `watch -n2 nvidia-smi`）。
4. 想并排在同一张图：把每个模型的输出接到 **Save Image/Video**，或用 **Image/Video Combine** 节点拼接。

> 进阶：可把多个模板合到同一张画布，共用同一个「CLIP Text Encode（prompt）」与固定 seed 的
> primitive 节点，分别接到各个 sampler，一次 Queue 跑完。做好后 **Save (API/JSON)** 导出，
> 放回本目录（例如 `compare_ltx_wan_h3.json`）方便重复使用。

## 存放你自己的 workflow

把在 ComfyUI 里调好、导出的 `.json` 放到这个目录，之后用 **Workflow → Open** 载入即可重现。

> 注意：对比工具自己抓取的 workflow 放在 `compare/workflows/`（`<模型>.<image|video>.json`
> 与对应的 `.meta.json`），由 **🎯 从 ComfyUI 抓取** 按钮写入，与本目录无关。
