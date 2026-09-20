[English](notes.md) · [繁體中文](notes.zh-TW.md) · **简体中文**

# 硬件限制、内存管理与故障排查

## 本机环境（已验证）

- 机型：GB10 Grace Blackwell（实机 MSI EdgeXpert，与 NVIDIA DGX Spark 同芯片）
- 架构：aarch64 (ARM64)，Ubuntu 24.04，kernel 6.17.0-nvidia
- GPU：NVIDIA GB10，compute capability **sm_121**，Driver 580，**CUDA 13.0**
- 内存：128GB 统一内存（CPU/GPU 共用），可见约 121GiB + 15GiB swap
- 硬盘：NVMe 916GB，可用约 830GB

## 为什么只能用 CUDA 13 / cu130 的软件包

- **只有 CUDA 13.0 起才支持 sm_121**；CUDA 12.8 最高只到 sm_120。
- PyTorch 一定要装 **cu130 + aarch64** wheel：
  `pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130`
- 一般 x86 或 cu12x 的 wheel／镜像在这台机器上**跑不起来**。

## 内存管理（重点）

- LLM 与视频模型**共用同一块 128GB**，建议一次只跑一种重负载。
- Ollama 闲置一段时间会**自动卸载**模型，释放内存。
- 视频模型优先用**量化版**（NVFP4 / int8 / fp8）：NVFP4 是 Blackwell 原生格式，
  官方称视频生成最高 3x 速度、-60% 内存。
- 监看：`watch -n2 nvidia-smi` 看 GPU、`watch -n2 free -h` 看统一内存。

## 访问范围

- Open WebUI：绑定 `127.0.0.1:8080`
- ComfyUI：绑定 `127.0.0.1:8188`（start.sh 不加 `--listen`）
- 对比工具：绑定 `0.0.0.0:8890` —— 同网段可直接访问。设 `COMPARE_HOST=127.0.0.1` 可限回本机。

若要从局域网的其他机器连接：

- chatbot：把 start.sh 的 `-p 127.0.0.1:8080:8080` 改成 `-p 8080:8080`
- ComfyUI：start.sh 的 `python main.py` 改成 `python main.py --listen 0.0.0.0`
- 并自行配置防火墙，注意 **ComfyUI 默认无密码**。

要对公网开放，请用对比工具的对外模式（`COMPARE_TOKEN`）配合 `compare/tunnel.sh`，
不要直接 `--listen`。

## 故障排查

- **`docker ps` 权限被拒**：用户尚未加入 docker 用户组。执行 `sudo usermod -aG docker $USER`，
  然后**注销再登录**（或 `newgrp docker`）。
- **`torch.cuda.is_available()` 为 False**：确认装的是 cu130 wheel、`nvidia-smi` 正常、venv 已 activate。
- **HuggingFace 下载 401/403**：执行 `hf auth login`；LTX-2.5 是 gated repo，
  需先到该 repo 页面**接受授权**。
- **ComfyUI 找不到某模型节点**：`git -C comfyui/ComfyUI pull` 更新到最新版；或用 ComfyUI-Manager 补装。
- **内存不足（OOM／很慢）**：改用更小的量化版、降低分辨率／帧数，或先停掉另一个服务。
- **ComfyUI 生成报错 `Python.h: No such file or directory`**：PyTorch/Triton 在运行时会用 gcc
  即时编译 CUDA 小工具，需要 Python 开发头文件。装好后重启 ComfyUI 即可：
  ```bash
  sudo apt-get update && sudo apt-get install -y python3-dev build-essential
  ```
  这是本机生成能否成功的关键前置；未安装之前任何用到 Triton 的模型都会失败。
- **Cloudflare 隧道连不上**：确认本机网络没有屏蔽 outbound 7844。
- **`tunnel.sh start` 拒绝启动**：说明对比工具不在对外模式。创建 `compare/.token` 后重新运行
  `compare/start.sh`；这个联锁是为了避免机器在没有认证的情况下暴露在公网上。

## 可选优化（先跑通再说）

- **SageAttention（sm_121a）**：社区 DGX Spark 专用构建（SparkyUI / AEON / dr-vij）可进一步加速；需自行编译 wheel。
- 参考：`awesome-dgx-spark` https://github.com/bidual/awesome-dgx-spark
