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

**English** · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md)

# LLM Explorer — Space frontend

This Space is **the interface only**. The actual video and image generation runs on a
local NVIDIA GB10 (DGX Spark class) machine, reached through a tunnel. No model weights
live in this Space.

## Security model

Three layers, all required:

| Layer | Mechanism | What it stops |
|---|---|---|
| 1 | Space set to private + `SPACE_USERS` credentials | Who can open this UI at all |
| 2 | Shared secret `COMPARE_TOKEN` | Only this Space can reach the machine |
| 3 | Endpoint allow-list in `server.py` on the machine | If layers 1–2 leak, callers can still only generate — not write files or inject arbitrary workflows |

Layer 3 is the important one: as soon as `COMPARE_TOKEN` is set, the machine blocks
`/api/import`, `/api/savewf`, `/api/capture`, `/api/uitpl` and `/api/stop`, and applies
the resolution allow-list and queue limits. See `compare/server.py`.

## Configuration

Add these under the Space's **Settings → Variables and secrets**:

| Name | Type | Description |
|---|---|---|
| `COMPARE_URL` | Secret | Tunnel URL, e.g. `https://xxx.trycloudflare.com` |
| `COMPARE_TOKEN` | Secret | Same secret as `server.py` on the machine |
| `SPACE_USERS` | Secret | Login pairs `alice:pw1,bob:pw2`; optional if the Space is already private |

Matching start-up on the machine:

```bash
# Either export the token explicitly…
COMPARE_TOKEN='the same secret' ./compare/start.sh

# …or store it once and let start.sh pick it up
echo 'the same secret' > compare/.token && ./compare/start.sh
```

## Known limitations

- **Video is slow**: roughly 2–5 minutes for HD, longer for FHD, and the host runs one
  job at a time.
- Keep the tab open after submitting — closing it loses the result.
- 2K/4K is not offered: at that token count MiniMax H3 produces grid artefacts, and
  disabling sparse attention runs out of memory.
- When the host is powered off, the Space reports that the generation host is offline.
- This Space's own interface is English-only. The self-hosted comparison page
  (`compare/index.html`) is the one that carries all three languages.
