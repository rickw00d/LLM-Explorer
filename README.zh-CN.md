[English](README.md) · [繁體中文](README.zh-TW.md) · **简体中文**

# LLM Explorer — DGX Spark（GB10）本地 AI 工作站

在一台 **GB10 Grace Blackwell**（128GB 统一内存）上运行三套本地服务：多 LLM 聊天、
用 ComfyUI 生成图像／视频，以及「同一个 prompt、多模型并排对比」的网页工具。

| 服务 | 用途 | 网址 | 目录 |
|---|---|---|---|
| **Open WebUI + Ollama** | 多 LLM 聊天，可热切换模型 | http://localhost:8080 | [`chatbot/`](chatbot/) |
| **ComfyUI** | 图像／视频生成后端 | http://localhost:8188 | [`comfyui/`](comfyui/) |
| **模型对比工具** | 同一个 prompt，多模型并排对比（调用 ComfyUI API） | http://localhost:8890 | [`compare/`](compare/) |
| **HuggingFace Space 前端** | 可选的远程界面，通过隧道连回本机 | — | [`space/`](space/) |

> Open WebUI 与 ComfyUI **只绑定 127.0.0.1**。模型对比工具默认绑定
> **`0.0.0.0`（所有网络接口）**，同网段的其他设备可以直接访问；想限回本机，
> 设 `COMPARE_HOST=127.0.0.1`。没有密钥时，任何能访问 8890 的人都能把任意
> workflow 推进你的 ComfyUI —— 请设置密钥（见[对外开放](#4-对外开放可选)）或用防火墙挡掉这个端口。

硬件限制与内存管理见 [`docs/notes.zh-CN.md`](docs/notes.zh-CN.md)。

---

## 快速开始：一键安装

交互式安装脚本涵盖以下所有步骤：系统检查、ComfyUI 环境、模型下载、启动服务与 chatbot。

```bash
git clone https://github.com/rickw00d/LLM-Explorer.git
cd LLM-Explorer
./install.sh          # ↑↓ 移动 · Space 勾选 · Enter 开始
```

菜单项：

1. 系统初始化 — 软件包、Docker、CUDA 检查
2. ComfyUI 环境 — venv + PyTorch cu130
3. 视频模型 — LTX-2.5 / MiniMax H3 / Wan 2.2
4. 图像模型 — Flux.2 Klein / Qwen-Image / Z-Image Turbo
5. 启动 ComfyUI + 对比工具
6. Chatbot — Open WebUI + Ollama + LLM

全程记录在 `install.log`；默认全部不勾选，请用 Space 选取。

> 脚本的菜单与终端输出一律为英文，中文使用说明由本文档承担。

想手动安装的话，请看以下步骤。

---

## 0. 一次性前置

```bash
# 让当前用户能使用 docker（之后需注销再登录，或 newgrp docker）
sudo usermod -aG docker $USER

# Triton 运行期即时编译需要的开发头文件；没装的话 ComfyUI 生成会失败
sudo apt-get update && sudo apt-get install -y python3-dev build-essential

# 下载模型用的 HuggingFace CLI（ComfyUI 部分需要）
pip install -U "huggingface_hub[cli]"
hf auth login          # LTX-2.5 为 gated，需先到其 HF 页面接受授权
```

## 1. Chatbot（多 LLM）

```bash
cd chatbot
./start.sh             # 启动 Open WebUI（首次会拉取镜像）
./pull-models.sh       # 按 models.txt 下载模型
# 浏览器打开 http://localhost:8080 → 建本机管理员账号 → 在 UI 切换模型对话
./stop.sh              # 停止（加 --remove 连容器一起删除，模型／设置仍保留）
```

想增减模型：编辑 [`chatbot/models.txt`](chatbot/models.txt) 后再运行 `./pull-models.sh`；
也可以只拉取单个模型：`./pull-models.sh qwen3:8b`。

## 2. ComfyUI（图像／视频生成）

```bash
cd comfyui
./setup.sh             # 建 venv + 装 cu130 PyTorch + 最新 ComfyUI + Manager
./download-models.sh   # 下载全部；也可指定 ltx|wan|h3|flux2|qwen|zimage|video|image
./start.sh             # 后台启动 → http://localhost:8188
./stop.sh              # 停止
```

涵盖的模型：

| 模型 | 类型 | 备注 |
|---|---|---|
| LTX-2.5（Lightricks，22B int8） | 视频 | gated repo，需先接受授权 |
| MiniMax H3 / Hailuo 3.0（int8） | 视频 | 用**本地开放权重版**模板，不要用 API 版 |
| Wan 2.2 T2V 14B（fp8） | 视频 | 单张输出即等同文生图 |
| Flux.2 Klein（9B fp8） | 图像 | |
| Qwen-Image-2512（bf16） | 图像 | |
| Z-Image Turbo（6B bf16） | 图像 | 蒸馏版，较快 |

公平对比方法（同 prompt／同 seed）见
[`comfyui/workflows/README.zh-CN.md`](comfyui/workflows/README.zh-CN.md)。

## 3. 模型对比工具

一个网页：输入一个 prompt → 对选定的模型各运行一次 → 同页并排对比（含耗时）。
网页提供英文、繁体中文、简体中文三种语言，会按浏览器语言自动选择，
也会记住你在语言菜单中的选择。

```bash
cd compare && ./start.sh        # ComfyUI 没在运行的话会一并启动
                                # → http://localhost:8890
./stop.sh                       # 两个一起停
```

首次使用：在每个模型的卡片按 **🎯 从 ComfyUI 抓取**（先在 ComfyUI 打开该模型 Template 按一次 Run），
工具会自动抓取并识别模型。之后输入 prompt、选图像／视频、勾选模型，按「一次生成并对比」。

环境变量：

| 变量 | 默认值 | 含义 |
|---|---|---|
| `COMFY_URL` | `http://127.0.0.1:8188` | ComfyUI 后端地址 |
| `COMPARE_HOST` / `COMPARE_PORT` | `0.0.0.0` / `8890` | 绑定地址 —— `0.0.0.0` 是所有接口，只要本机请设 `127.0.0.1` |
| `COMPARE_TOKEN` | *(空)* | 设置后即进入对外模式 |
| `COMPARE_MAX_PENDING` / `COMPARE_MAX_MODELS` / `COMPARE_MAX_PROMPT` | `8` / `3` / `2000` | 对外模式上限 |

> ⚠️ 首次生成前必须先装 `python3-dev`（见 [docs/notes.zh-CN.md](docs/notes.zh-CN.md) 故障排查），
> 否则 ComfyUI 会因 Triton 缺头文件而失败。

## 4. 对外开放（可选）

对比工具内置对外模式：设置 `COMPARE_TOKEN` 之后，所有 `/api/*` 都要带
`X-Compare-Token` 头，管理端点（`/api/import`、`/api/savewf`、`/api/capture`、
`/api/uitpl`、`/api/stop`）全部封锁，并应用分辨率白名单与队列上限。

```bash
# 1. 创建共享密钥（绝对不进版本控制，.token 已在 .gitignore）
openssl rand -hex 32 > compare/.token

# 2. start.sh 会自动读取 .token，以对外模式启动
cd compare && ./start.sh

# 3. 开启 Cloudflare 隧道。未授权请求若不是返回 401 就拒绝启动，这个联锁是刻意的。
./tunnel.sh start | stop | status
```

[`space/`](space/) 是配套的 HuggingFace Space 远程前端，三层安全模型见
[`space/README.zh-CN.md`](space/README.zh-CN.md)。

---

## 重要提醒

- **架构是 aarch64 + Blackwell sm_121，只能用 CUDA 13 / cu130 的软件包**（详见 notes）。
- LLM 与视频模型**共用 128GB**，建议一次只跑一种重负载；视频模型优先用量化版（NVFP4 / int8 / fp8）。
- 这些模型是 2026-08 的新版本；若官方文件名／节点有变动，最稳妥的做法是让 **ComfyUI Template 自动下载**。

## 语言

文档维护英文、繁体中文（`*.zh-TW.md`）、简体中文（`*.zh-CN.md`）三个版本。
脚本、代码注释与终端输出刻意只用英文，让代码保持易读；面向用户的说明都放在翻译文档里。
对比工具的网页 UI 则在运行期支持三种语言，见 [`compare/i18n.js`](compare/i18n.js)
与 [`docs/i18n.js`](docs/i18n.js)。

要新增语言：在这两个文件的 `LANGS` 加一条、`I18N` 加一张表即可；缺失的 key 会自动回退到英文，
因此翻译到一半也能安全上线。运行 `python3 tools/check-i18n.py` 可检查字符串表、网页标记与
后端错误码三者是否一致。

## 目录结构

```
LLM-Explorer/
├── README.md                   # 英文（主）
├── README.zh-TW.md             # 繁体中文
├── README.zh-CN.md             # 本文件
├── install.sh                  # 交互式安装脚本
├── chatbot/                    # Open WebUI + Ollama（Docker）
│   ├── start.sh  stop.sh  pull-models.sh  models.txt
├── comfyui/                    # ComfyUI（原生 venv）
│   ├── setup.sh  start.sh  stop.sh  download-models.sh
│   └── workflows/              # 对比 workflow 说明 + 你导出的 .json
├── compare/                    # 对比工具
│   ├── server.py  index.html  i18n.js  start.sh  stop.sh  tunnel.sh
│   └── workflows/              # 抓取到的各模型 workflow
├── space/                      # HuggingFace Space 前端
└── docs/                       # 说明文档 + GitHub Pages（index.html、i18n.js）
```
