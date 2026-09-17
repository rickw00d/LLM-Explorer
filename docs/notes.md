# Hardware limits, memory management and troubleshooting
# 硬體限制、記憶體管理與疑難排解

## Verified local environment / 本機環境（已驗證）

- Machine: GB10 Grace Blackwell (an MSI EdgeXpert unit — same silicon as NVIDIA DGX Spark)
  機型：GB10 Grace Blackwell（實機 MSI EdgeXpert，與 NVIDIA DGX Spark 同晶片）
- Platform: aarch64 (ARM64), Ubuntu 24.04, kernel 6.17.0-nvidia
  架構：aarch64 (ARM64)，Ubuntu 24.04，kernel 6.17.0-nvidia
- GPU: NVIDIA GB10, compute capability **sm_121**, Driver 580, **CUDA 13.0**
  GPU：NVIDIA GB10，compute capability **sm_121**，Driver 580，**CUDA 13.0**
- Memory: 128 GB unified (shared CPU/GPU) — about 121 GiB visible plus 15 GiB swap
  記憶體：128GB 統一記憶體（CPU/GPU 共用），可見約 121GiB + 15GiB swap
- Disk: 916 GB NVMe, roughly 830 GB free
  磁碟：NVMe 916GB，可用約 830GB

## Why only CUDA 13 / cu130 packages work / 為什麼只能用 CUDA 13 / cu130 的套件

- **sm_121 is supported from CUDA 13.0 onwards**; CUDA 12.8 tops out at sm_120.
  **只有 CUDA 13.0 起才支援 sm_121**；CUDA 12.8 最高只到 sm_120。
- PyTorch must be the **cu130 + aarch64** wheel:
  PyTorch 一定要裝 **cu130 + aarch64** wheel：
  `pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130`
- Ordinary x86 or cu12x wheels and images **will not run** on this machine.
  一般 x86 或 cu12x 的 wheel/映像檔在這台**跑不起來**。

## Memory management (important) / 記憶體管理（重點）

- LLMs and video models **share one 128 GB pool**. Run one heavy workload at a time.
  LLM 與影片模型**共用同一塊 128GB**。建議**一次跑一種重負載**。
- Ollama **unloads** idle models automatically, freeing memory.
  Ollama 閒置一段時間會**自動卸載**模型，釋放記憶體。
- Prefer **quantised** video models (NVFP4 / int8 / fp8). NVFP4 is Blackwell's native
  format; NVIDIA quotes up to 3x throughput and -60% memory for video generation.
  影片模型優先用**量化版**（NVFP4 / int8 / fp8）：NVFP4 是 Blackwell 原生格式，
  官方稱影片生成最高 3x 速度、-60% 記憶體。
- Monitoring: `watch -n2 nvidia-smi` for the GPU, `watch -n2 free -h` for unified memory.
  監看：`watch -n2 nvidia-smi` 看 GPU、`watch -n2 free -h` 看統一記憶體。

## Access scope: localhost only by default / 存取範圍：預設僅本機

- Open WebUI binds `127.0.0.1:8080` / Open WebUI：綁 `127.0.0.1:8080`
- ComfyUI binds `127.0.0.1:8188` (start.sh does not pass `--listen`)
  ComfyUI：預設綁 `127.0.0.1:8188`（start.sh 不加 `--listen`）
- Comparison tool binds `127.0.0.1:8890` (`COMPARE_HOST` / `COMPARE_PORT` to change)
  比較工具：綁 `127.0.0.1:8890`（可用 `COMPARE_HOST` / `COMPARE_PORT` 調整）

To reach the services from another machine on the LAN / 若要從別台電腦連（區網）:

- chatbot: change `-p 127.0.0.1:8080:8080` in start.sh to `-p 8080:8080`
  chatbot：把 start.sh 的 `-p 127.0.0.1:8080:8080` 改成 `-p 8080:8080`
- ComfyUI: change `python main.py` in start.sh to `python main.py --listen 0.0.0.0`
  ComfyUI：start.sh 的 `python main.py` 改成 `python main.py --listen 0.0.0.0`
- Configure your firewall yourself, and note that **ComfyUI has no password**.
  並自行設定防火牆，注意 ComfyUI 預設無密碼。

For exposure to the public internet, use the comparison tool's public mode
(`COMPARE_TOKEN`) and `compare/tunnel.sh` — never plain `--listen`.
要對公網開放，請用比較工具的對外模式（`COMPARE_TOKEN`）搭配 `compare/tunnel.sh`，
不要直接 `--listen`。

## Troubleshooting / 疑難排解

- **`docker ps` permission denied** — the user is not in the docker group yet.
  Run `sudo usermod -aG docker $USER`, then **log out and back in** (or `newgrp docker`).
  **`docker ps` 權限被拒**：使用者尚未在 docker 群組。執行 `sudo usermod -aG docker $USER`，
  然後**登出再登入**（或 `newgrp docker`）。
- **`torch.cuda.is_available()` is False** — check you installed the cu130 wheel, that
  `nvidia-smi` works, and that the venv is activated.
  **`torch.cuda.is_available()` 為 False**：確認裝的是 cu130 wheel、`nvidia-smi` 正常、venv 已 activate。
- **HuggingFace download returns 401/403** — run `hf auth login`; LTX-2.5 is a gated repo,
  so you must **accept the licence** on its repo page first.
  **HuggingFace 下載 401/403**：`hf auth login`；LTX-2.5 是 gated repo，需先到該 repo 頁面**接受授權**。
- **ComfyUI cannot find a model node** — update with `git -C comfyui/ComfyUI pull`, or
  install the missing nodes through ComfyUI-Manager.
  **ComfyUI 找不到某模型節點**：`git -C comfyui/ComfyUI pull` 更新到最新版；或用 ComfyUI-Manager 補裝。
- **Out of memory / very slow** — use a smaller quantised build, lower the resolution or
  frame count, or stop the other service first.
  **記憶體不足（OOM / 很慢）**：改用更小的量化版、降低解析度/影格數，或先停掉另一個服務。
- **ComfyUI fails with `Python.h: No such file or directory`** — PyTorch/Triton compile
  small CUDA helpers with gcc at runtime and need the Python development headers.
  Install them and restart ComfyUI:
  **ComfyUI 生成報錯 `Python.h: No such file or directory`**：PyTorch/Triton 在執行時會用 gcc
  即時編譯 CUDA 小工具，需要 Python 開發標頭檔。裝好後重啟 ComfyUI 即可：
  ```bash
  sudo apt-get update && sudo apt-get install -y python3-dev build-essential
  ```
  This is the critical prerequisite for local generation — until it is installed, every
  model that touches Triton fails.
  （這是本機生成能否成功的關鍵前置；未裝之前任何用到 Triton 的模型都會失敗。）
- **The Cloudflare tunnel will not connect** — check that outbound port 7844 is not
  blocked by your local network.
  **Cloudflare 通道連不上**：確認本機網路沒有擋掉 outbound 7844。
- **`tunnel.sh start` refuses to run** — the comparison server is not in public mode.
  Create `compare/.token` and re-run `compare/start.sh`; the interlock exists so the
  machine is never exposed without authentication.
  **`tunnel.sh start` 拒絕啟動**：代表比較工具不在對外模式。建立 `compare/.token` 後重跑
  `compare/start.sh`；這個連鎖鎖是為了避免機器在沒有認證的情況下裸露在公網上。

## Optional optimisations (get it working first) / 可選優化（先跑通再說）

- **SageAttention (sm_121a)** — community DGX Spark builds (SparkyUI / AEON / dr-vij)
  give extra speed, but you need to build the wheel yourself.
  **SageAttention（sm_121a）**：社群 DGX Spark 專用建置（SparkyUI / AEON / dr-vij）可再加速；需自編 wheel。
- Reference: `awesome-dgx-spark` https://github.com/bidual/awesome-dgx-spark
  參考：`awesome-dgx-spark` https://github.com/bidual/awesome-dgx-spark
