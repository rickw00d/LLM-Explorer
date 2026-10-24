# 参与贡献

[English](CONTRIBUTING.md) · [繁體中文](CONTRIBUTING.zh-TW.md) · **简体中文**

感谢你抽空看这份文档。这个项目是在单台 DGX Spark（GB10）上运行多个生成式模型的工具集，
大部分贡献不外乎三类：新增一张模型卡片、修一个脚本、或更正文档。

## 动手之前

这里没有构建步骤。你需要 `bash`、`python3`，若要改网页 UI 则需要 `node` 做语法检查。

```bash
git clone https://github.com/rickw00d/LLM-Explorer.git
cd LLM-Explorer
python3 tools/check-i18n.py     # 三语字符串表是否一致
python3 tools/check-models.py   # 卡片、workflow、下载目标是否一致
```

干净的 checkout 上这两个都该通过。若没通过，那本身就是值得报告的 bug。

## 检查项

这个项目没有 CI，也没有测试套件。以下四条命令就是约定：

```bash
for f in $(git ls-files '*.sh'); do bash -n "$f" || echo "FAIL $f"; done
python3 -m py_compile $(git ls-files '*.py')
node --check compare/i18n.js && node --check docs/i18n.js
python3 tools/check-i18n.py && python3 tools/check-models.py
```

开 PR 前请先跑一遍，并在 PR 里写明你实际执行了什么。**语法检查不等于测试**：如果你改了
`compare/start.sh`，就要真的把服务启动起来确认。

## 语言

本项目采用**英文为主、中文为辅**。所有用户可见的字符串都有三种语言：英文、繁体中文
（`zh-TW`）、简体中文（`zh-CN`）。

- **Markdown** —— 一种语言一个文件：`README.md`、`README.zh-TW.md`、`README.zh-CN.md`。
  改一个就要三个一起改，并保留开头的互链那一行。
- **网页 UI** —— 运行时 i18n，不依赖任何框架。标记上挂 `data-i18n="key"`，字符串放在
  `compare/i18n.js` 与 `docs/i18n.js`。新增 key 时三份表都要加。英文是 fallback，
  所以漏翻会退回英文，而不是显示原始 key。
- **Shell 脚本、Python、代码注释** —— **只用英文**。凌晨两点排障的人在读这些，一种语言就够了。
- **`compare/server.py`** —— 绝对不要返回翻译过的句子。用 `err("CODE", **params)` 返回
  **错误码**，由前端以 `err.CODE` 这个 key 翻译。响应同时带一个纯英文的 `error` 字段，
  给不做翻译的客户端使用，例如 `curl` 和 HuggingFace Space 前端。

`tools/check-i18n.py` 会检查：三语 key 是否对齐、标记里用到的 key 是否都存在、每个
`err("CODE")` 是否都有对应的 `ERROR_TEXT` 与 `err.CODE` 翻译、以及 `docs/index.html`
里的英文默认值是否仍与字符串表相符。

### 台湾用语与大陆用语

`zh-TW` 用台湾惯用语，`zh-CN` 用大陆惯用语。两者**不是**互相做字符转换就行——
影片／视频、檔案／文件、記憶體／内存等等都不同。请分别认真写，不要拿繁简转换工具套。

## 新增一个模型到对比工具

一张卡片要五件事都成立才算完成，其中后三项 `tools/check-models.py` 会帮你把关：

1. **权重能抓到。** 在 `comfyui/download-models.sh` 加一个 `get_<name>()`，并接到 `case`
   分派。`dl()` 是用文件名 glob 匹配，所以你只需要 repo id 和文件名，不需要 repo 内部路径。
   记得一并加进 `video` 或 `image` 分组以及 `all`。
2. **模型能被识别。** 在 `compare/server.py` 的 `SIGNATURES` 加一条，让导入的 workflow
   能从文件名被识别出来。
3. **卡片存在。** 在 `compare/server.py` 的 `MODELS` 加 id、`MODEL_LABEL` 加标签。
4. **workflow 已捕获。** 在 ComfyUI 里打开该模型的官方模板、跑一次，然后回到卡片上按
   **🎯 Capture from ComfyUI**，会写出 `compare/workflows/<id>.<type>.json`。
5. **规格卡已翻译。** 在 `compare/index.html` 用 `data-i18n` 加上 `info-card` 标记，
   并把字符串加进 `compare/i18n.js` 的三份表。

有一条规则能避免这一切腐化：**下载目标抓的，必须就是捕获到的 workflow 加载的那些文件。**
一张卡片的 workflow 要 NVFP4、下载器却抓 int8——在你机器上看起来一切正常，直到别人重新安装。

## Shell 脚本约定

- 开头一律 `set -euo pipefail`。某个命令允许失败的话，用 `|| true` 明说，不要整个去掉 `-e`。
- 小心 `set -e` 遇到管道：`grep` 找不到东西会返回 1，脚本就无声中止。这类管道结尾要加 `|| true`。
- 长时间运行的服务要有一个 **`run.sh`**，在前台运行并以 `exec` 收尾。`start.sh` 负责丢到后台，
  systemd 则直接监管它。启动参数只有一份定义，而 `exec` 让 PID 是真的。
- 不要只信 PID 文件。重启会重新发小号 PID，判定「已在运行」之前要比对 `/proc/<pid>/cmdline`。
- 路径要加引号。参考安装位置的目录名含空格，而 systemd unit 的 `ExecStart=` 是以空白切分的。

## 机密数据

绝对不要提交 `compare/.token`、`compare/.env`、`Secret/` 下任何东西，或 HuggingFace token。
它们都在 `.gitignore` 里，请保持原状。也不要贴到 issue 里——bug 报告模板会请你确认这一点。

对比工具的对外模式之所以存在，就是为了确保隧道不会在没有共享密钥的情况下被打开：
`tunnel.sh` 在未认证请求没有返回 401 之前会拒绝启动。请不要削弱这个互锁。

## Commit 与 Pull Request

- Commit 标题写「改了什么」，用祈使语气：*Fix the HuggingFace login check*，而不是 *fixed stuff*。
- 在正文解释**为什么**。「做了什么」看 diff 就知道。
- 一个 PR 处理一件事。
- 诚实填写 PR 模板，包括你**没有**验证的部分。

## 报告问题

请使用 issue 模板，并先跑那两个一致性检查。如果是模型下载失败，请附上确切的错误信息：
下载器会区分「未登录」「未接受授权」与「确实失败」三种情况，而那个区分往往就是答案。
