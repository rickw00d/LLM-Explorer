# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project has no version
numbers yet; `main` is the only supported branch, so entries are grouped by the work
that produced them.

## Unreleased

### Added

- **Trilingual documentation and UI.** English, Traditional Chinese and Simplified
  Chinese. Markdown is one file per language; the web UIs translate at runtime from
  `compare/i18n.js` and `docs/i18n.js` with `data-i18n` attributes, English fallback,
  browser-language detection and a persisted picker.
- **Stable API error contract.** `compare/server.py` returns
  `{error_code, error_params, error}`. The front end translates the code; the English
  `error` sentence serves clients that do not, such as `curl` and the Space frontend.
- **Start at boot.** `systemd/install.sh` installs two user services — `comfyui.service`
  and `llm-compare.service` — with ordering, restart rate limits and lingering, and
  retires the older all-in-one unit.
- **Foreground launchers.** `comfyui/run.sh` and `compare/run.sh` hold the launch flags
  and `exec`, so `start.sh` and systemd supervise the same real process.
- **H3 Turbo-8 / Turbo-4 cards and downloader**, plus the NVFP4 base they run on.
- **HiDream-I1 downloader**, covering the transformer, four text encoders and the VAE.
- **Run history** in the comparison tool: each run lands in its own row instead of
  wiping the grid.
- **`tools/check-models.py`** — compares the cards in `compare/server.py`, the weights
  each captured workflow selects, and the download targets, and fails on drift.
- **`tools/check-i18n.py`** — key parity across the three tables, every key used in
  markup, every error code translated, and the inline English defaults.
- Repository documentation: contributing guides, security policy, code of conduct,
  issue and pull request templates, and an architecture overview.

### Changed

- **The comparison server binds `0.0.0.0` by default**, so other devices on the LAN can
  reach it. Set `COMPARE_HOST=127.0.0.1` for loopback only. See
  [SECURITY.md](SECURITY.md) for what this exposes.
- `/api/stop` is no longer an administrative endpoint, so cancelling a run works in
  public mode.
- `compare/start.sh` starts ComfyUI if it is not already up, and `compare/stop.sh`
  stops both.
- Download targets now match the builds the captured workflows actually load: LTX-2.5
  fp8_e4m3fn with the Gemma-4 enhancer and the x2 upscaler, the MiniMax H3 NVFP4 base,
  Wan 2.2 with its lightx2v 4-step LoRAs, Qwen-Image fp8_e4m3fn, and FLUX.2 Dev NVFP4
  in place of Klein 9B.
- The landing page reads without JavaScript: inline English defaults, and the language
  picker stays hidden until the runtime reveals it.

### Fixed

- **`install.sh` always reported "not logged in"** to HuggingFace. It called
  `hf auth status`, which is not a subcommand and exits 2. Now uses `hf auth whoami`.
- **`pull-models.sh` passed each whole line of `models.txt` to `ollama pull`**, trailing
  `# description` included, so every pull failed.
- **A hand-written systemd unit failed 1853 times with `status=203/EXEC`.** `ExecStart=`
  splits on whitespace and the repository path contains spaces; `systemd/install.sh`
  writes the quotes. Restart rate limits now stop a broken unit instead of letting it
  retry forever.
- **`systemd/install.sh` exited 1 with no output when the ports were free** — a
  no-match `grep` inside a `set -euo pipefail` pipeline.
- **A ComfyUI failure took the comparison server down with it** in `compare/start.sh`.
- **Stale PID files made the start scripts report success and start nothing.** A reboot
  recycles low PIDs; the scripts now confirm the process against `/proc/<pid>/cmdline`.
- **A gated HuggingFace repository failed once per file** with advice covering two
  different problems. The downloader now reports a repository once and says which it is:
  not logged in, or logged in without the licence accepted.
- **Different repositories sharing a filename** silently left a model on the wrong VAE.
  The downloader records each file's source and reports the clash.
- **`poll()` froze on "generating" forever** on a 401 or an unrecognised response.
- **`download-template-deps.py` hard-coded `python3.12`**, so a venv on any other minor
  release could not find the templates.
- `apt-get install` failures in `install.sh` were reported as success.

### Removed

- **Z-Image Turbo.** It had been taken out of the comparison tool but was still
  downloaded, including as part of `all` and preselected in `install.sh`.
- The `[cli]` extra from `pip install huggingface_hub`; it was dropped in
  huggingface_hub 2.x and the `hf` command ships in the base package.

## Earlier

The history before this work: the initial comparison tool, the GitHub Pages showcase,
the live ComfyUI queue indicator, public-mode hardening behind `COMPARE_TOKEN`, the
HuggingFace Space frontend, and `tunnel.sh` with its 401 interlock.
