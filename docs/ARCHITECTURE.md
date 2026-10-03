# Architecture

**English** · [繁體中文](ARCHITECTURE.zh-TW.md) · [简体中文](ARCHITECTURE.zh-CN.md)

Three independent local services, plus an optional remote frontend. Nothing here is a
distributed system: every process runs on one DGX Spark box and talks over loopback.

## Topology

```
                         ┌─────────────────────────────┐
  browser  ──────────────▶  Open WebUI + Ollama  :8080 │  Docker, own auth
                         └─────────────────────────────┘

                         ┌─────────────────────────────┐
  browser  ──────────────▶  Comparison server   :8890  │  python3, stdlib only
                         └──────────────┬──────────────┘
                                        │ HTTP, loopback
                         ┌──────────────▼──────────────┐
  browser  ──────────────▶  ComfyUI             :8188  │  venv, no auth
                         └─────────────────────────────┘
                                        │
                                   GPU: GB10

  HuggingFace Space ──── cloudflared tunnel ───▶ :8890  (public mode only)
```

| Service | Port | Binds | Process model |
|---|---|---|---|
| Open WebUI + Ollama | 8080 | `127.0.0.1` | Docker, `--restart unless-stopped` |
| ComfyUI | 8188 | `127.0.0.1` | venv Python, `comfyui/run.sh` |
| Comparison server | 8890 | `0.0.0.0` | stdlib Python, `compare/run.sh` |

The comparison server has **no dependencies outside the standard library**. It runs on
`http.server` and proxies ComfyUI. That is deliberate: it has to start even when the
ComfyUI venv is broken, so the page can say so.

## A generation, end to end

1. The browser posts to `/api/generate` with a prompt, a seed, a type
   (`image`/`video`), the selected model ids and a resolution.
2. For each model the server loads `compare/workflows/<id>.<type>.json`, the ComfyUI
   API-format graph captured earlier, and rewrites two things in it: the positive
   prompt node and every literal `seed` / `noise_seed`.
3. It posts each graph to ComfyUI's `/prompt` and gets back a prompt id.
4. The browser polls `/api/status?id=…` per model. The server asks ComfyUI for history
   and queue state and answers `queued`, `running` or a finished result.
5. Finished output is fetched through `/api/view`, which proxies ComfyUI's view
   endpoint so the browser never needs to reach port 8188 itself.

The same seed and the same prompt go to every selected model, which is the whole point:
the comparison is only fair if nothing else varies.

### Finding the prompt node

A captured workflow is someone else's graph, so the server has to locate the prompt
input rather than assume a node id. `find_positive_node()` tries, in order: walking back
from the sampler's `positive` link; then nodes whose input is simply `prompt` or `text`,
preferring text-encode and video-wrapper class types whose `_meta` title does not say
"negative". Failing that, it looks for a literal `__PROMPT__` placeholder.

## Capturing a workflow

A card is useless without a graph to run. The capture flow is:

1. Open the model's official template in ComfyUI and run it once.
2. Press **🎯 Capture from ComfyUI** on the card. The server reads ComfyUI's history,
   takes the most recent graph, identifies which model it is from the filenames in it
   (`SIGNATURES` in `compare/server.py`), and writes
   `compare/workflows/<id>.<type>.json` plus a `.meta.json` beside it.

This is why `/api/capture`, `/api/import`, `/api/savewf` and `/api/uitpl` are blocked in
public mode: between them they write files and push arbitrary graphs into ComfyUI, which
is read/write access to the machine.

## Keeping three lists in step

Drift between what a card offers, what its workflow loads, and what the downloader
fetches is quiet and expensive. `tools/check-models.py` compares all three and fails if
they disagree. It reads only the values under a node's `inputs`: a widget's dropdown
also lists files that merely exist on disk, and matching against those would hide real
gaps behind false positives.

## Internationalisation

No framework. Markup carries `data-i18n`, `data-i18n-title` and `data-i18n-ph`
attributes; `i18n.js` holds one string table per language and swaps the text in.

```
detectLang()   localStorage 'lang' → navigator.languages → en
               zh-Hant|tw|hk|mo → zh-TW · any other zh → zh-CN · else en
t(key, vars)   table → English fallback → the key itself; {param} interpolation
applyI18n()    fills every [data-i18n*] node, sets <html lang> and document.title
setLang()      persists the choice and re-runs the listeners
```

English is the fallback at every level, so a half-finished translation degrades to
English rather than showing a raw key. `docs/index.html` goes further: the landing page
carries inline English defaults inside each translated element, so it reads correctly
with JavaScript disabled, and the language picker ships `hidden` until the runtime
reveals it.

### Errors cross the wire as codes

The server never returns a translated sentence. `err("CODE", **params)` produces:

```json
{"error_code": "PROMPT_TOO_LONG", "error_params": {"max": 2000},
 "error": "Prompt too long (max 2000 characters)"}
```

The browser renders `t("err.PROMPT_TOO_LONG", {max: 2000})`. The English `error` field
is there for clients that do not translate — `curl`, and the Gradio frontend in
`space/`. Both directions stay compatible: an old client ignores the code and prints
`error`; a new client falls back to `error` when it does not recognise the code.

`tools/check-i18n.py` fails if an `err("CODE")` lacks either its `ERROR_TEXT` entry or
its `err.CODE` translation.

## Process supervision

Each long-running service has three layers:

```
run.sh     foreground, holds the launch flags, ends in exec  ← the real process
start.sh   nohup run.sh &, writes a PID file                 ← interactive use
*.service  Type=simple, ExecStart=run.sh                     ← boot, restarts, journal
```

`exec` matters: without it the PID file and systemd would both track a wrapper shell
rather than the process that owns the port.

PID files are checked against `/proc/<pid>/cmdline`, not just `kill -0`. After a reboot
the kernel hands out low PIDs again, so a leftover PID often belongs to an unrelated
daemon — and the naive check reports "already running" and starts nothing.

The systemd units set `StartLimitIntervalSec=300` / `StartLimitBurst=5`. The default
limit is five starts in ten seconds, which a `RestartSec=10` unit never trips, so a
permanently broken service retries forever and nobody notices.

## Where state lives

| What | Where | In git |
|---|---|---|
| Model weights | `comfyui/ComfyUI/models/` | no |
| Download provenance | `…/models/<sub>/.<file>.from` | no |
| Captured workflows | `compare/workflows/*.json` | **yes** |
| Public-mode token | `compare/.token` | no, and never |
| Local env overrides | `compare/.env` | no |
| Logs, PID files | `*/\*.log`, `*/\*.pid` | no |
| Generated output | ComfyUI's own output directory | no |

Captured workflows are tracked on purpose: they are the definition of what each card
runs, and `tools/check-models.py` reads them.

## Public exposure

Optional, off by default, and interlocked. `compare/tunnel.sh` refuses to open a
Cloudflare tunnel unless an unauthenticated request to the server returns 401 — so a
tunnel cannot be opened to a server that has no token. The Space frontend in `space/`
is a Gradio app that calls the tunnel URL with the shared token.

See [SECURITY.md](../SECURITY.md) for the full posture, including what binding 8890 to
`0.0.0.0` means on your network.
