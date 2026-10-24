# 架构说明

[English](ARCHITECTURE.md) · [繁體中文](ARCHITECTURE.zh-TW.md) · **简体中文**

三个各自独立的本地服务，外加一个可选的远程前端。这里没有任何分布式系统：所有进程都运行在
同一台 DGX Spark 上，彼此通过 loopback 通信。

## 服务拓扑

```
                         ┌─────────────────────────────┐
  浏览器  ───────────────▶  Open WebUI + Ollama  :8080 │  Docker，自带认证
                         └─────────────────────────────┘

                         ┌─────────────────────────────┐
  浏览器  ───────────────▶  对比服务器          :8890  │  python3，仅标准库
                         └──────────────┬──────────────┘
                                        │ HTTP，loopback
                         ┌──────────────▼──────────────┐
  浏览器  ───────────────▶  ComfyUI             :8188  │  venv，无认证
                         └─────────────────────────────┘
                                        │
                                   GPU：GB10

  HuggingFace Space ──── cloudflared 隧道 ───▶ :8890  （仅对外模式）
```

| 服务 | 端口 | 绑定 | 进程模型 |
|---|---|---|---|
| Open WebUI + Ollama | 8080 | `127.0.0.1` | Docker，`--restart unless-stopped` |
| ComfyUI | 8188 | `127.0.0.1` | venv Python，`comfyui/run.sh` |
| 对比服务器 | 8890 | `0.0.0.0` | 标准库 Python，`compare/run.sh` |

对比服务器**完全不依赖标准库以外的包**，建在 `http.server` 上，并代理 ComfyUI。
这是刻意的：即使 ComfyUI 的 venv 坏掉，它也必须能启动，网页才有办法告诉你坏在哪。

## 一次生成的完整流程

1. 浏览器 POST 到 `/api/generate`，带上 prompt、seed、类型（`image`／`video`）、
   勾选的模型 id 与分辨率。
2. 服务器为每个模型加载 `compare/workflows/<id>.<type>.json`——先前捕获下来的 ComfyUI
   API 格式图——并改写其中两样东西：正向 prompt 节点，以及所有字面上的 `seed` / `noise_seed`。
3. 把每张图 POST 到 ComfyUI 的 `/prompt`，取回 prompt id。
4. 浏览器针对每个模型轮询 `/api/status?id=…`。服务器向 ComfyUI 查询 history 与队列状态，
   回答 `queued`、`running` 或完成的结果。
5. 完成的输出通过 `/api/view` 取回，它代理 ComfyUI 的 view 端点，所以浏览器完全不需要
   自己连到 8188。

同一个 seed、同一个 prompt 发给每个选中的模型——这正是重点：其他变量都一样，比较才公平。

### 怎么找到 prompt 节点

捕获到的 workflow 是别人的图，所以服务器必须**找出** prompt 输入在哪，而不能假设节点 id。
`find_positive_node()` 依次尝试：从 sampler 的 `positive` 连线往回走；再找输入名称就叫
`prompt` 或 `text` 的节点，优先挑 `_meta` 标题里没有 "negative" 的文本编码类与视频包装类节点。
都找不到时，退而寻找字面上的 `__PROMPT__` 占位字符串。

## 捕获 workflow

没有可执行的图，卡片就毫无用处。捕获流程是：

1. 在 ComfyUI 里打开该模型的官方模板，执行一次。
2. 回到卡片上按 **🎯 Capture from ComfyUI**。服务器读取 ComfyUI 的 history，取最近一张图，
   从图中的文件名识别出是哪个模型（`compare/server.py` 里的 `SIGNATURES`），然后写出
   `compare/workflows/<id>.<type>.json` 以及旁边的 `.meta.json`。

这也是为什么 `/api/capture`、`/api/import`、`/api/savewf`、`/api/uitpl` 在对外模式下被封锁：
它们合起来可以写入文件、把任意图推进 ComfyUI，等同于对这台机器的读写权限。

## 让三份清单保持同步

「卡片提供什么」「它的 workflow 加载什么」「下载器抓什么」三者之间的落差，既安静又昂贵。
`tools/check-models.py` 会比对这三者，不一致就失败。它**只读节点 `inputs` 下的值**：
widget 的下拉菜单也会列出磁盘上存在的其他文件，拿那些去比对会用假的匹配掩盖真正的缺口。

## 国际化

不用框架。标记上挂 `data-i18n`、`data-i18n-title`、`data-i18n-ph`；`i18n.js` 每种语言
一份字符串表，负责把文字换上去。

```
detectLang()   localStorage 'lang' → navigator.languages → en
               zh-Hant|tw|hk|mo → zh-TW · 其他 zh → zh-CN · 其余 → en
t(key, vars)   查表 → 退回英文 → 最后退回 key 本身；支持 {param} 代入
applyI18n()    填入所有 [data-i18n*] 节点，并同步 <html lang> 与 document.title
setLang()      记住选择并重新执行所有监听器
```

每一层的 fallback 都是英文，所以翻到一半只会退回英文，不会冒出原始 key。
`docs/index.html` 更进一步：首页在每个待翻译元素里内嵌英文默认值，所以**禁用 JavaScript
也能读懂**，而语言选单默认带 `hidden`，由运行时才显示出来。

### 错误以「代码」跨越网络

服务器从不返回翻译过的句子。`err("CODE", **params)` 产生的是：

```json
{"error_code": "PROMPT_TOO_LONG", "error_params": {"max": 2000},
 "error": "Prompt too long (max 2000 characters)"}
```

浏览器渲染的是 `t("err.PROMPT_TOO_LONG", {max: 2000})`。那个英文 `error` 字段是给不做翻译的
客户端用的——`curl`，以及 `space/` 里的 Gradio 前端。两个方向都保持兼容：旧客户端忽略代码、
直接打印 `error`；新客户端遇到不认识的代码时退回 `error`。

`tools/check-i18n.py` 会在某个 `err("CODE")` 缺少 `ERROR_TEXT` 条目或 `err.CODE` 翻译时失败。

## 进程监管

每个长时间运行的服务都有三层：

```
run.sh     前台运行，持有启动参数，以 exec 收尾   ← 真正的进程
start.sh   nohup run.sh &，写 PID 文件            ← 交互使用
*.service  Type=simple，ExecStart=run.sh          ← 开机、重启、journal
```

`exec` 很关键：少了它，PID 文件和 systemd 追踪到的都会是外层的 shell，而不是真正占住端口的那个进程。

PID 文件会比对 `/proc/<pid>/cmdline`，不只是 `kill -0`。重启后内核会重新发放小号 PID，
所以残留的 PID 往往属于某个不相干的 daemon——而天真的检查会报告「已在运行」然后什么都不启动。

systemd unit 设了 `StartLimitIntervalSec=300` / `StartLimitBurst=5`。默认限制是「10 秒内 5 次」，
而 `RestartSec=10` 的 unit 永远碰不到那个门槛，于是坏掉的服务会无限重试而没人发现。

## 状态存放位置

| 内容 | 位置 | 进版本控制？ |
|---|---|---|
| 模型权重 | `comfyui/ComfyUI/models/` | 否 |
| 下载来源记录 | `…/models/<sub>/.<file>.from` | 否 |
| 捕获到的 workflow | `compare/workflows/*.json` | **是** |
| 对外模式密钥 | `compare/.token` | 否，而且永远不要 |
| 本机环境覆盖 | `compare/.env` | 否 |
| 日志、PID 文件 | `*/\*.log`、`*/\*.pid` | 否 |
| 生成输出 | ComfyUI 自己的 output 目录 | 否 |

捕获到的 workflow 刻意进版本控制：它们就是「每张卡片实际运行什么」的定义，而
`tools/check-models.py` 要读它们。

## 对外开放

可选、默认关闭、而且有互锁。`compare/tunnel.sh` 在「未认证请求返回 401」之前会拒绝开启
Cloudflare 隧道——所以隧道不可能被开到一台没设密钥的服务器上。`space/` 里的 Space 前端是
一个 Gradio 应用，带着共享密钥调用隧道网址。

完整的安全态势见 [SECURITY.zh-CN.md](../SECURITY.zh-CN.md)，包含把 8890 绑在 `0.0.0.0`
对你的网络意味着什么。
