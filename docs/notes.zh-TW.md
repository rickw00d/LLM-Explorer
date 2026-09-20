[English](notes.md) · **繁體中文** · [简体中文](notes.zh-CN.md)

# 硬體限制、記憶體管理與疑難排解

## 本機環境（已驗證）

- 機型：GB10 Grace Blackwell（實機 MSI EdgeXpert，與 NVIDIA DGX Spark 同晶片）
- 架構：aarch64 (ARM64)，Ubuntu 24.04，kernel 6.17.0-nvidia
- GPU：NVIDIA GB10，compute capability **sm_121**，Driver 580，**CUDA 13.0**
- 記憶體：128GB 統一記憶體（CPU/GPU 共用），可見約 121GiB + 15GiB swap
- 磁碟：NVMe 916GB，可用約 830GB

## 為什麼只能用 CUDA 13 / cu130 的套件

- **只有 CUDA 13.0 起才支援 sm_121**；CUDA 12.8 最高只到 sm_120。
- PyTorch 一定要裝 **cu130 + aarch64** wheel：
  `pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130`
- 一般 x86 或 cu12x 的 wheel／映像檔在這台**跑不起來**。

## 記憶體管理（重點）

- LLM 與影片模型**共用同一塊 128GB**，建議一次跑一種重負載。
- Ollama 閒置一段時間會**自動卸載**模型，釋放記憶體。
- 影片模型優先用**量化版**（NVFP4 / int8 / fp8）：NVFP4 是 Blackwell 原生格式，
  官方稱影片生成最高 3x 速度、-60% 記憶體。
- 監看：`watch -n2 nvidia-smi` 看 GPU、`watch -n2 free -h` 看統一記憶體。

## 存取範圍

- Open WebUI：綁 `127.0.0.1:8080`
- ComfyUI：綁 `127.0.0.1:8188`（start.sh 不加 `--listen`）
- 比較工具：綁 `0.0.0.0:8890` —— 同網段可直接連上。設 `COMPARE_HOST=127.0.0.1` 可限回本機。

若要從區網的別台電腦連：

- chatbot：把 start.sh 的 `-p 127.0.0.1:8080:8080` 改成 `-p 8080:8080`
- ComfyUI：start.sh 的 `python main.py` 改成 `python main.py --listen 0.0.0.0`
- 並自行設定防火牆，注意 **ComfyUI 預設無密碼**。

要對公網開放，請用比較工具的對外模式（`COMPARE_TOKEN`）搭配 `compare/tunnel.sh`，
不要直接 `--listen`。

## 疑難排解

- **`docker ps` 權限被拒**：使用者尚未在 docker 群組。執行 `sudo usermod -aG docker $USER`，
  然後**登出再登入**（或 `newgrp docker`）。
- **`torch.cuda.is_available()` 為 False**：確認裝的是 cu130 wheel、`nvidia-smi` 正常、venv 已 activate。
- **HuggingFace 下載 401/403**：執行 `hf auth login`；LTX-2.5 是 gated repo，
  需先到該 repo 頁面**接受授權**。
- **ComfyUI 找不到某模型節點**：`git -C comfyui/ComfyUI pull` 更新到最新版；或用 ComfyUI-Manager 補裝。
- **記憶體不足（OOM／很慢）**：改用更小的量化版、降低解析度／影格數，或先停掉另一個服務。
- **ComfyUI 生成報錯 `Python.h: No such file or directory`**：PyTorch/Triton 在執行時會用 gcc
  即時編譯 CUDA 小工具，需要 Python 開發標頭檔。裝好後重啟 ComfyUI 即可：
  ```bash
  sudo apt-get update && sudo apt-get install -y python3-dev build-essential
  ```
  這是本機生成能否成功的關鍵前置；未裝之前任何用到 Triton 的模型都會失敗。
- **Cloudflare 通道連不上**：確認本機網路沒有擋掉 outbound 7844。
- **`tunnel.sh start` 拒絕啟動**：代表比較工具不在對外模式。建立 `compare/.token` 後重跑
  `compare/start.sh`；這個連鎖鎖是為了避免機器在沒有認證的情況下裸露在公網上。

## 可選優化（先跑通再說）

- **SageAttention（sm_121a）**：社群 DGX Spark 專用建置（SparkyUI / AEON / dr-vij）可再加速；需自編 wheel。
- 參考：`awesome-dgx-spark` https://github.com/bidual/awesome-dgx-spark
