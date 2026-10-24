# Contributing

**English** · [繁體中文](CONTRIBUTING.zh-TW.md) · [简体中文](CONTRIBUTING.zh-CN.md)

Thanks for looking. This is a toolkit for running several generative models locally on
one DGX Spark (GB10) box, so most contributions are one of: a new model card, a fix to
a script, or a documentation correction.

## Before you start

Nothing here needs a build step. You need `bash`, `python3`, and — for the web UIs —
`node` to syntax-check the JavaScript.

```bash
git clone https://github.com/rickw00d/LLM-Explorer.git
cd LLM-Explorer
python3 tools/check-i18n.py     # translation tables agree
python3 tools/check-models.py   # cards, workflows and download targets agree
```

Both should pass on a clean checkout. If they do not, that is a bug worth reporting on
its own.

## The checks

There is no CI and no test suite. These four commands are the contract:

```bash
for f in $(git ls-files '*.sh'); do bash -n "$f" || echo "FAIL $f"; done
python3 -m py_compile $(git ls-files '*.py')
node --check compare/i18n.js && node --check docs/i18n.js
python3 tools/check-i18n.py && python3 tools/check-models.py
```

Run them before opening a pull request, and say in the PR what you actually ran. A
syntax check is not a test: if you changed `compare/start.sh`, start the service and
confirm it comes up.

## Languages

The repository is **English-primary with Chinese companions**. Every user-facing string
exists in three languages: English, Traditional Chinese (`zh-TW`) and Simplified
Chinese (`zh-CN`).

- **Markdown** — one file per language: `README.md`, `README.zh-TW.md`, `README.zh-CN.md`.
  Change one, change all three, and keep the cross-link header line intact.
- **Web UIs** — runtime i18n, no framework. Markup carries `data-i18n="key"` and the
  strings live in `compare/i18n.js` and `docs/i18n.js`. Add a key to all three tables.
  English is the fallback, so a missing translation degrades to English rather than
  showing a raw key.
- **Shell scripts, Python, comments** — **English only**. They are read by whoever is
  debugging at 2am, and one language is enough.
- **`compare/server.py`** — never return a translated sentence. Return an error *code*
  via `err("CODE", **params)`; the front end translates it with the `err.CODE` key. The
  response also carries a plain English `error` field for clients that do not translate,
  such as `curl` and the HuggingFace Space frontend.

`tools/check-i18n.py` enforces key parity, that every key used in markup exists, that
every `err("CODE")` has both an `ERROR_TEXT` entry and an `err.CODE` translation, and
that the inline English defaults in `docs/index.html` still match their table entries.

### Taiwanese vs mainland wording

`zh-TW` uses Taiwanese terminology, `zh-CN` uses mainland terminology. They are not
mechanical conversions of each other — 影片/视频, 檔案/文件, 記憶體/内存 and so on.
Write each one properly rather than running a character converter over the other.

## Adding a model to the comparison tool

A card is only finished when all five of these are true, and
`tools/check-models.py` checks the last three for you:

1. **Weights can be fetched.** Add a `get_<name>()` function to
   `comfyui/download-models.sh` and wire it into the `case` dispatch. `dl()` matches by
   filename glob, so you need the repository id and the filename, not the path inside
   the repo. Add it to the `video` or `image` group and to `all`.
2. **The model is detectable.** Add a `SIGNATURES` entry in `compare/server.py` so an
   imported workflow is recognised by its filenames.
3. **The card exists.** Add the id to `MODELS` and a label to `MODEL_LABEL` in
   `compare/server.py`.
4. **The workflow is captured.** Open the model's official template in ComfyUI, run it
   once, then press **🎯 Capture from ComfyUI** on the card. That writes
   `compare/workflows/<id>.<type>.json`.
5. **The spec card is translated.** Add the `info-card` markup to `compare/index.html`
   using `data-i18n` keys, and the strings to all three tables in `compare/i18n.js`.

The one rule that keeps this from rotting: **the download target must fetch exactly what
the captured workflow loads.** A card whose workflow wants an NVFP4 build while the
downloader fetches int8 looks fine until someone installs from scratch.

## Shell script conventions

- `set -euo pipefail` at the top. If a command is allowed to fail, say so with
  `|| true` rather than dropping `-e`.
- Beware `set -e` with pipelines: `grep` finds nothing, exits 1, and the script dies
  silently. End such pipelines with `|| true`.
- Long-running services have a **`run.sh`** that runs in the foreground and ends in
  `exec`. `start.sh` backgrounds it; systemd supervises it directly. One definition of
  the launch flags, and `exec` keeps the PID honest.
- Never trust a PID file alone. A reboot recycles low PIDs, so confirm the process
  identity against `/proc/<pid>/cmdline` before deciding something is already running.
- Quote paths. The reference install lives under a directory with spaces in its name,
  and `ExecStart=` in a systemd unit splits on whitespace.

## Secrets

Never commit `compare/.token`, `compare/.env`, anything under `Secret/`, or a
HuggingFace token. They are in `.gitignore`; keep them there. Do not paste them into
issues either — the bug report template asks you to confirm that.

The comparison tool's public mode exists so a tunnel is never opened without a shared
secret: `tunnel.sh` refuses to start unless an unauthenticated request returns 401.
Do not weaken that interlock.

## Commits and pull requests

- Write the commit subject as what changes, in the imperative: *Fix the HuggingFace
  login check*, not *fixed stuff*.
- Explain **why** in the body. The diff shows what.
- One concern per pull request.
- Fill in the PR template honestly, including the parts you did not verify.

## Reporting bugs

Use the issue template and run the two consistency checks first. If a model fails to
download, include the exact error: the downloader distinguishes "not logged in" from
"licence not accepted" from a genuine failure, and that distinction is the answer.
