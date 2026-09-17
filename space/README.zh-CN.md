[English](README.md) · [繁體中文](README.zh-TW.md) · **简体中文**

# LLM Explorer — Space 前端

这个 Space 只是**界面**。实际的视频／图像生成跑在一台本地 NVIDIA GB10（DGX Spark）上，
通过隧道连过去。Space 本身不含任何模型权重。

## 安全模型

三层，缺一不可：

| 层 | 机制 | 挡住什么 |
|---|---|---|
| 1 | Space 设为 private + `SPACE_USERS` 账号密码 | 谁能打开这个 UI |
| 2 | 共享密钥 `COMPARE_TOKEN` | 只有这个 Space 能访问那台机器 |
| 3 | 机器端 `server.py` 的端点白名单 | 前两层泄露时，也只能生成，不能写文件或注入任意 workflow |

第 3 层是关键：机器端只要设了 `COMPARE_TOKEN` 就会自动封锁 `/api/import`、`/api/savewf`、
`/api/capture`、`/api/uitpl`、`/api/stop`，并应用分辨率白名单与队列上限。详见 `compare/server.py`。

## 配置

在 Space 的 **Settings → Variables and secrets** 中加入：

| 名称 | 类型 | 说明 |
|---|---|---|
| `COMPARE_URL` | Secret | 隧道网址，例如 `https://xxx.trycloudflare.com` |
| `COMPARE_TOKEN` | Secret | 与机器端 `server.py` 相同的密钥 |
| `SPACE_USERS` | Secret | 登录账号密码 `alice:pw1,bob:pw2`；Space 已是 private 时可省略 |

机器端对应的启动方式：

```bash
# 直接传入密钥：
COMPARE_TOKEN='与上面相同的密钥' ./compare/start.sh

# 或存成文件，start.sh 会自动读取：
echo '与上面相同的密钥' > compare/.token && ./compare/start.sh
```

## 已知限制

- **视频很慢**：HD 约 2~5 分钟一条，FHD 更久，主机一次只跑一个任务。
- 提交后必须保持标签页打开，关掉就收不到结果。
- 2K／4K 不开放：MiniMax H3 在该 token 数下会产生网格伪影，关掉稀疏注意力则直接 OOM。
- 主机关机时 Space 会显示生成主机离线。
- 这个 Space 的界面本身只有英文；三语界面在自建的对比页面（`compare/index.html`）上。
