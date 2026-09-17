**English** · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md)

# LLM Explorer — Local AI Workstation on DGX Spark (GB10)

Three local services on a **GB10 Grace Blackwell** box (128 GB unified memory):
chat with multiple LLMs, generate images and video with ComfyUI, and compare
several generative models side by side from a single prompt.

| Service | Purpose | URL (local only) | Directory |
|---|---|---|---|
| **Open WebUI + Ollama** | Multi-LLM chat, hot-swappable models | http://localhost:8080 | [`chatbot/`](chatbot/) |
| **ComfyUI** | Image/video generation backend | http://localhost:8188 | [`comfyui/`](comfyui/) |
| **Model Comparison Tool** | One prompt, several models side by side (calls the ComfyUI API) | http://localhost:8890 | [`compare/`](compare/) |
| **HuggingFace Space frontend** | Optional remote UI that tunnels back to this machine | — | [`space/`](space/) |

> All three services bind to **127.0.0.1 only** by default. Public exposure is
> opt-in and requires a shared token — see [Public access](#4-public-access-optional).

Hardware limits and memory management: [`docs/notes.md`](docs/notes.md).

---

## Quick start: one-shot installer

The interactive installer covers everything below — system checks, ComfyUI
environment, model downloads, service start-up and the chatbot.

```bash
git clone https://github.com/rickw00d/LLM-Explorer.git
cd LLM-Explorer
./install.sh          # ↑↓ move · Space select · Enter start
```

Menu items:

1. System bootstrap — packages, Docker, CUDA checks
2. ComfyUI environment — venv + PyTorch cu130
3. Video models — LTX-2.5 / MiniMax H3 / Wan 2.2
4. Image models — Flux.2 Klein / Qwen-Image / Z-Image Turbo
5. Start ComfyUI + comparison tool
6. Chatbot — Open WebUI + Ollama + LLMs

Everything is logged to `install.log`. Nothing is selected by default — use
Space to pick.

If you prefer to do it by hand, the manual steps follow.

---

## 0. One-time prerequisites

```bash
# Let the current user run docker (log out and back in afterwards, or: newgrp docker)
sudo usermod -aG docker $USER

# Build headers Triton needs at generation time — without these, ComfyUI fails.
sudo apt-get update && sudo apt-get install -y python3-dev build-essential

# HuggingFace CLI for model downloads (needed by the ComfyUI part)
pip install -U "huggingface_hub[cli]"
hf auth login          # LTX-2.5 is gated — accept the licence on its HF page first
```

## 1. Chatbot (multi-LLM)

```bash
cd chatbot
./start.sh             # start Open WebUI (first run pulls the image)
./pull-models.sh       # download the models listed in models.txt
# Open http://localhost:8080 → create a local admin account → switch models in the UI
./stop.sh              # stop (add --remove to delete the container; models/settings are kept)
```

To add or remove models, edit [`chatbot/models.txt`](chatbot/models.txt) and re-run
`./pull-models.sh`. You can also pull a single model: `./pull-models.sh qwen3:8b`.

## 2. ComfyUI (image/video generation)

```bash
cd comfyui
./setup.sh             # venv + cu130 PyTorch + latest ComfyUI + Manager
./download-models.sh   # all models; or pass one of: ltx wan h3 flux2 qwen zimage video image
./start.sh             # start in the background → http://localhost:8188
./stop.sh              # stop
```

Models covered:

| Model | Type | Notes |
|---|---|---|
| LTX-2.5 (Lightricks, 22B int8) | video | gated repo — accept the licence first |
| MiniMax H3 / Hailuo 3.0 (int8) | video | use the **Local / open-weights** templates, not the API ones |
| Wan 2.2 T2V 14B (fp8) | video | a single-frame output is effectively text-to-image |
| Flux.2 Klein (9B fp8) | image | |
| Qwen-Image-2512 (bf16) | image | |
| Z-Image Turbo (6B bf16) | image | distilled, fast |

Fair-comparison method (same prompt / same seed): see
[`comfyui/workflows/README.md`](comfyui/workflows/README.md).

## 3. Model comparison tool

One web page: type a prompt → it runs the selected models once each → results
line up side by side with timings. The page is available in English, Traditional
Chinese and Simplified Chinese; it follows your browser language and remembers
whatever you pick from the selector.

```bash
cd compare && ./start.sh        # requires ComfyUI to be running
                                # → http://localhost:8890
./stop.sh                       # stop
```

First run: on each model card press **🎯 Capture from ComfyUI** (first open that
model's template in ComfyUI and press Run once). The tool grabs the workflow and
identifies the model. After that: type a prompt, pick image or video, tick the
models, press generate-and-compare.

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `COMFY_URL` | `http://127.0.0.1:8188` | ComfyUI backend |
| `COMPARE_HOST` / `COMPARE_PORT` | `127.0.0.1` / `8890` | bind address |
| `COMPARE_TOKEN` | *(empty)* | set it to switch on public mode |
| `COMPARE_MAX_PENDING` / `COMPARE_MAX_MODELS` / `COMPARE_MAX_PROMPT` | `8` / `3` / `2000` | public-mode limits |

> ⚠️ Before the first generation you must have `python3-dev` installed (see
> [docs/notes.md](docs/notes.md) troubleshooting), otherwise ComfyUI fails on a
> missing Triton header.

## 4. Public access (optional)

The comparison server has a public mode. Setting `COMPARE_TOKEN` makes every
`/api/*` call require an `X-Compare-Token` header, blocks the admin endpoints
(`/api/import`, `/api/savewf`, `/api/capture`, `/api/uitpl`, `/api/stop`), and
enforces a resolution allow-list plus queue limits.

```bash
# 1. Create the shared token (never commit it — .token is git-ignored)
openssl rand -hex 32 > compare/.token

# 2. start.sh picks .token up automatically and starts in public mode
cd compare && ./start.sh

# 3. Open the Cloudflare tunnel. It refuses to start unless an unauthenticated
#    request returns 401 — that interlock is deliberate.
./tunnel.sh start | stop | status
```

The HuggingFace Space frontend in [`space/`](space/) is the matching remote UI;
its three-layer security model is documented in [`space/README.md`](space/README.md).

---

## Things to keep in mind

- The platform is **aarch64 + Blackwell sm_121, so only CUDA 13 / cu130 packages work** (see notes).
- LLMs and video models **share the same 128 GB**. Run one heavy workload at a time;
  prefer quantised video models (NVFP4 / int8 / fp8).
- These are 2026-08-era model releases. If official filenames or nodes change, the
  safest route is letting the **ComfyUI template download them automatically**.

## Languages

Documentation is maintained in English, Traditional Chinese (`*.zh-TW.md`) and
Simplified Chinese (`*.zh-CN.md`). Scripts, code comments and terminal output are
English-only by design, so the code stays readable; end-user instructions live in
the translated documents. The comparison web UI carries all three languages at
runtime — see [`compare/i18n.js`](compare/i18n.js) and [`docs/i18n.js`](docs/i18n.js).

To add a language, add one entry to `LANGS` and one table to `I18N` in those two
files; missing keys fall back to English, so a partial translation is safe to ship.
`python3 tools/check-i18n.py` verifies that the tables, the markup and the server's
error codes all line up.

## Repository layout

```
LLM-Explorer/
├── README.md                   # this file (English)
├── README.zh-TW.md             # Traditional Chinese
├── README.zh-CN.md             # Simplified Chinese
├── install.sh                  # interactive installer
├── chatbot/                    # Open WebUI + Ollama (Docker)
│   ├── start.sh  stop.sh  pull-models.sh  models.txt
├── comfyui/                    # ComfyUI (native venv)
│   ├── setup.sh  start.sh  stop.sh  download-models.sh
│   └── workflows/              # comparison workflow notes + your exported .json
├── tools/check-i18n.py         # translation-table consistency check
├── compare/                    # comparison tool
│   ├── server.py  index.html  i18n.js  start.sh  stop.sh  tunnel.sh
│   └── workflows/              # captured per-model workflows
├── space/                      # HuggingFace Space frontend
└── docs/                       # documentation + GitHub Pages (index.html, i18n.js)
```
