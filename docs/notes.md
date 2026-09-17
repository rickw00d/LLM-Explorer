**English** · [繁體中文](notes.zh-TW.md) · [简体中文](notes.zh-CN.md)

# Hardware limits, memory management and troubleshooting

## Verified local environment

- Machine: GB10 Grace Blackwell (an MSI EdgeXpert unit — same silicon as NVIDIA DGX Spark)
- Platform: aarch64 (ARM64), Ubuntu 24.04, kernel 6.17.0-nvidia
- GPU: NVIDIA GB10, compute capability **sm_121**, Driver 580, **CUDA 13.0**
- Memory: 128 GB unified (shared CPU/GPU) — about 121 GiB visible plus 15 GiB swap
- Disk: 916 GB NVMe, roughly 830 GB free

## Why only CUDA 13 / cu130 packages work

- **sm_121 is supported from CUDA 13.0 onwards**; CUDA 12.8 tops out at sm_120.
- PyTorch must be the **cu130 + aarch64** wheel:
  `pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130`
- Ordinary x86 or cu12x wheels and images **will not run** on this machine.

## Memory management (important)

- LLMs and video models **share one 128 GB pool**. Run one heavy workload at a time.
- Ollama **unloads** idle models automatically, freeing memory.
- Prefer **quantised** video models (NVFP4 / int8 / fp8). NVFP4 is Blackwell's native
  format; NVIDIA quotes up to 3x throughput and -60% memory for video generation.
- Monitoring: `watch -n2 nvidia-smi` for the GPU, `watch -n2 free -h` for unified memory.

## Access scope: localhost only by default

- Open WebUI binds `127.0.0.1:8080`
- ComfyUI binds `127.0.0.1:8188` (start.sh does not pass `--listen`)
- Comparison tool binds `127.0.0.1:8890` (`COMPARE_HOST` / `COMPARE_PORT` to change)

To reach the services from another machine on the LAN:

- chatbot: change `-p 127.0.0.1:8080:8080` in start.sh to `-p 8080:8080`
- ComfyUI: change `python main.py` in start.sh to `python main.py --listen 0.0.0.0`
- Configure your firewall yourself, and note that **ComfyUI has no password**.

For exposure to the public internet, use the comparison tool's public mode
(`COMPARE_TOKEN`) and `compare/tunnel.sh` — never plain `--listen`.

## Troubleshooting

- **`docker ps` permission denied** — the user is not in the docker group yet.
  Run `sudo usermod -aG docker $USER`, then **log out and back in** (or `newgrp docker`).
- **`torch.cuda.is_available()` is False** — check you installed the cu130 wheel, that
  `nvidia-smi` works, and that the venv is activated.
- **HuggingFace download returns 401/403** — run `hf auth login`; LTX-2.5 is a gated repo,
  so you must **accept the licence** on its repo page first.
- **ComfyUI cannot find a model node** — update with `git -C comfyui/ComfyUI pull`, or
  install the missing nodes through ComfyUI-Manager.
- **Out of memory / very slow** — use a smaller quantised build, lower the resolution or
  frame count, or stop the other service first.
- **ComfyUI fails with `Python.h: No such file or directory`** — PyTorch/Triton compile
  small CUDA helpers with gcc at runtime and need the Python development headers.
  Install them and restart ComfyUI:
  ```bash
  sudo apt-get update && sudo apt-get install -y python3-dev build-essential
  ```
  This is the critical prerequisite for local generation — until it is installed, every
  model that touches Triton fails.
- **The Cloudflare tunnel will not connect** — check that outbound port 7844 is not
  blocked by your local network.
- **`tunnel.sh start` refuses to run** — the comparison server is not in public mode.
  Create `compare/.token` and re-run `compare/start.sh`; the interlock exists so the
  machine is never exposed without authentication.

## Optional optimisations (get it working first)

- **SageAttention (sm_121a)** — community DGX Spark builds (SparkyUI / AEON / dr-vij)
  give extra speed, but you need to build the wheel yourself.
- Reference: `awesome-dgx-spark` https://github.com/bidual/awesome-dgx-spark
