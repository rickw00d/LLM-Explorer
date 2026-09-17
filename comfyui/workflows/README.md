**English** · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md)

# Comparison workflows for ComfyUI image/video models

These models are all recent, and the official templates track node and file changes
better than anything checked into a repo. The **most reliable** way to get a working
graph is ComfyUI's built-in Template browser — it maps to the correct nodes and model
files for your installed version, and offers to download anything missing.

## Getting the official templates

In the ComfyUI interface: top-left **Workflow → Browse Templates** (or the **Templates**
panel), then search for:

- **LTX-2.5** — official T2V / I2V / with-audio templates
- **Wan 2.2** — T2V (a single-frame output is effectively text-to-image)
- **MiniMax H3** — pick the three **Local / open-weights** templates, **not** the API ones
- **Flux.2 Klein**, **Qwen-Image**, **Z-Image Turbo** — text-to-image templates

Online references:

- LTX-2.5: https://docs.comfy.org/tutorials/video/ltx/ltx-2-5
- Wan 2.2: https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2
- MiniMax H3: https://comfyui-wiki.com/en/tutorial/advanced/video/minimax/minimax-h3

## How to compare fairly

The point of a comparison is holding everything except the model constant.

1. Same prompt, same seed, same resolution / frame count / step count.
2. Run them one at a time. Memory is large, but one heavy model at a time is the most
   stable and makes the timings comparable.
3. Record for each run: the output file, the elapsed time (bottom-right of ComfyUI, or
   the log) and peak memory (`watch -n2 nvidia-smi` in another terminal).
4. To line the results up in one image, feed each model's output into **Save Image/Video**,
   or stitch them with an **Image/Video Combine** node.

> Advanced: put several templates on one canvas sharing a single **CLIP Text Encode**
> (prompt) node and a fixed-seed primitive, wired to each sampler, so one Queue run
> covers all of them. Export it with **Save (API/JSON)** and drop it back into this
> folder (e.g. `compare_ltx_wan_h3.json`) for reuse.

## Storing your own workflows

Drop the `.json` files you tuned and exported in ComfyUI into this folder; reload them
later with **Workflow → Open**.

> Note: the comparison tool keeps its own captured workflows in `compare/workflows/`
> (`<model>.<image|video>.json` plus a `.meta.json`). Those are written by the
> **🎯 Capture from ComfyUI** button and are separate from this folder.
