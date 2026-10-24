# 安全策略

[English](SECURITY.md) · [繁體中文](SECURITY.zh-TW.md) · **简体中文**

## 报告安全漏洞

请通过 GitHub 的私密通报表单报告，不要开公开 issue：

**<https://github.com/rickw00d/LLM-Explorer/security/advisories/new>**

请说明攻击者能触及什么、复现步骤、以及你测试的 commit。切勿附上任何 token、`.env`
或 `Secret/` 里的内容。

这是个人项目，不是有轮值待命的商业产品，大约一周内会收到回复。

只支持 `main` 分支，没有需要回溯修补的发行版本。

## 这套软件会暴露什么

在把这台机器接入你无法完全掌控的网络之前，请先读这一段。三个服务的暴露程度不同，
而且其中一个**默认就能从局域网访问**。

| 服务 | 端口 | 绑定地址 | 认证 |
|---|---|---|---|
| Open WebUI + Ollama | 8080 | `127.0.0.1` | 自带账号系统 |
| ComfyUI | 8188 | `127.0.0.1` | **完全没有** |
| 模型对比工具 | 8890 | **`0.0.0.0`**（所有接口） | 没有，除非设了密钥 |

有两点必须讲清楚：

- **ComfyUI 没有任何认证。** 任何能访问 8188 的人都能排入任意 workflow，等同于在
  ComfyUI 进程权限范围内读写本机文件。它绑在 loopback 正是因为这个原因，请不要对外开放。
- **对比工具绑定所有网络接口。** 默认状态下，同网段的任何设备都能打开它；在本机模式
  （无密钥）下，也没有任何东西能阻止他们通过它操作你的 ComfyUI。设
  `COMPARE_HOST=127.0.0.1` 可限回本机，或者设一组密钥。

## 对外模式

设置 `COMPARE_TOKEN`（或创建 `compare/.token`）会让对比服务器切换到对外模式：

1. 每个 `/api/*` 调用都必须带上匹配的 `X-Compare-Token` 头。比对采用
   `hmac.compare_digest`，是常数时间比较。
2. 管理端点 —— `/api/import`、`/api/savewf`、`/api/capture`、`/api/uitpl` —— 全部封锁。
   它们会写入文件或把任意 workflow 推进 ComfyUI，等同于对本机的读写权限。
   `COMPARE_ADMIN=1` 可以解除封锁，但只应在可信任的网络上这么做。
3. 分辨率白名单、队列数上限、模型数上限、prompt 长度上限同时生效。

`/api/stop` **刻意不列为**管理端点：中断自己提交的任务不是写入操作，而且远程界面需要它。

### 隧道互锁

`compare/tunnel.sh` 在「未认证请求返回 401」之前会拒绝开启 Cloudflare 隧道。这个检查
存在的目的，就是让隧道不可能被开到一台没设密钥的服务器上。请不要去掉它。

```bash
openssl rand -hex 32 > compare/.token   # 绝对不要提交这个文件
cd compare && ./start.sh                # 会自动读取密钥
./tunnel.sh start
```

## 加固检查清单

- [ ] 不需要局域网访问的话，设 `COMPARE_HOST=127.0.0.1`
- [ ] 需要的话，在 `compare/.token` 放一组密钥
- [ ] 对外模式下不要设 `COMPARE_ADMIN`
- [ ] ComfyUI 保持在 loopback，不要加 `--listen`
- [ ] 用防火墙把 8188 对局域网挡掉
- [ ] `compare/.token`、`compare/.env`、`Secret/` 三者均未进版本控制——它们都在 `.gitignore` 里，
      用 `git status --porcelain --ignored` 可以确认

## 不在范围内

以下是已知且刻意为之，不算漏洞：

- ComfyUI 本身不带认证。那是上游的设计，本项目的应对方式是把它绑在 loopback。
- 因为你自己改了绑定地址、开了防火墙端口、或设了 `COMPARE_ADMIN=1` 才能访问到的东西。
- 从 HuggingFace 下载的权重。要不要信任某个模型库是你的判断；`download-models.sh`
  抓的是 `.safetensors`，加载时不会执行代码，但恶意的 workflow 仍然可以。
