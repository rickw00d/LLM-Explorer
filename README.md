**English** · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md)

# LLM Explorer — Local AI Workstation on DGX Spark (GB10)

Three local services on a **GB10 Grace Blackwell** box (128 GB unified memory):
chat with multiple LLMs, generate images and video with ComfyUI, and compare
several generative models side by side from a single prompt.

| Service | Purpose | URL | Directory |
|---|---|---|---|
| **Open WebUI + Ollama** | Multi-LLM chat, hot-swappable models | http://localhost:8080 | [`chatbot/`](chatbot/) |
| **ComfyUI** | Image/video generation backend | http://localhost:8188 | [`comfyui/`](comfyui/) |
| **Model Comparison Tool** | One prompt, several models side by side (calls the ComfyUI API) | http://localhost:8890 | [`compare/`](compare/) |
| **HuggingFace Space frontend** | Optional remote UI that tunnels back to this machine | — | [`space/`](space/) |

> Open WebUI and ComfyUI bind to **127.0.0.1 only**. The comparison tool binds
> **`0.0.0.0` (every interface)** by default, so other devices on your LAN can reach it;
> set `COMPARE_HOST=127.0.0.1` to keep it on loopback. Without a token, anyone who can
> reach port 8890 can push arbitrary workflows into ComfyUI — set one
> (see [Public access](#4-public-access-optional)) or firewall the port.

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
4. Image models — FLUX.2 Dev / Qwen-Image / HiDream-I1
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
pip install -U huggingface_hub
hf auth login          # then accept the LTX-2.5 licence, or its downloads are refused:
                       # https://huggingface.co/Lightricks/LTX-2.5
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
./download-models.sh   # all models; or one of: ltx wan h3 h3turbo flux2 qwen hidream video image
./start.sh             # start in the background → http://localhost:8188
./stop.sh              # stop
```

Models covered:

| Model | Type | Notes |
|---|---|---|
| LTX-2.5 (Lightricks, 22B fp8_e4m3fn) | video | gated repo — accept the licence first |
| MiniMax H3 / Hailuo 3.0 (NVFP4) | video | use the **Local / open-weights** templates, not the API ones |
| Wan 2.2 T2V 14B (fp8) | video | runs 4 steps with the lightx2v distillation LoRAs |
| H3 Turbo-8 / Turbo-4 (LoRAs) | video | distilled; also needs the `h3` files |
| FLUX.2 Dev (NVFP4 mixed) | image | Mistral 3 Small encoder; weights span three repos |
| Qwen-Image-2512 (fp8_e4m3fn) | image | |
| HiDream-I1 dev (fp8) | image | four text encoders |

> The download targets mirror the cards the comparison tool shows. Z-Image Turbo was
> removed from that UI, so it is no longer downloaded. Different repos sometimes ship
> different files under one name — `ae.safetensors` is the usual culprit — so the
> downloader records where each file came from and says so when a second repo wants
> that name, instead of leaving a model on the wrong VAE.
>
> The builds listed here are the ones the captured workflows in `compare/workflows/`
> actually load. `python3 tools/check-models.py` compares the three lists — the cards
> in `compare/server.py`, the weights each workflow selects, and the download targets —
> and fails if they drift apart again.

Fair-comparison method (same prompt / same seed): see
[`comfyui/workflows/README.md`](comfyui/workflows/README.md).

## 3. Model comparison tool

One web page: type a prompt → it runs the selected models once each → results
line up side by side with timings. The page is available in English, Traditional
Chinese and Simplified Chinese; it follows your browser language and remembers
whatever you pick from the selector.

```bash
cd compare && ./start.sh        # starts ComfyUI too, if it is not already up
                                # → http://localhost:8890
./stop.sh                       # stops both
```

First run: on each model card press **🎯 Capture from ComfyUI** (first open that
model's template in ComfyUI and press Run once). The tool grabs the workflow and
identifies the model. After that: type a prompt, pick image or video, tick the
models, press generate-and-compare.

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `COMFY_URL` | `http://127.0.0.1:8188` | ComfyUI backend |
| `COMPARE_HOST` / `COMPARE_PORT` | `0.0.0.0` / `8890` | bind address — `0.0.0.0` is every interface; use `127.0.0.1` for loopback only |
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

## 5. Start at boot (optional)

```bash
bash systemd/install.sh
```

Installs two systemd **user** services — `comfyui.service` and
`llm-compare.service` — enables lingering so they start at boot without a login,
and retires the older all-in-one `llm-explorer.service` if one is installed.

```bash
systemctl --user status comfyui llm-compare
journalctl --user -u comfyui -f
systemctl --user restart llm-compare
```

Both units run `run.sh`, which holds the launch flags and `exec`s, so systemd
supervises the real process rather than a wrapper. Open WebUI needs nothing here:
its container already carries `--restart unless-stopped`.

> If you write a unit by hand, quote the path in `ExecStart`. systemd splits that
> line on whitespace, so a repository path containing a space becomes a different
> command and the service fails with `status=203/EXEC`, restarting forever.
> `systemd/install.sh` writes the quotes for you.

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
│   ├── setup.sh  start.sh  run.sh  stop.sh  download-models.sh
│   └── workflows/              # comparison workflow notes + your exported .json
├── tools/                      # check-i18n.py (translations) · check-models.py (model lists)
├── compare/                    # comparison tool
│   ├── server.py  index.html  i18n.js  start.sh  run.sh  stop.sh  tunnel.sh
│   └── workflows/              # captured per-model workflows
├── systemd/                    # user services for starting at boot (install.sh)
├── space/                      # HuggingFace Space frontend
└── docs/                       # documentation + GitHub Pages (index.html, i18n.js)
```
