/* Runtime translations for the comparison page.
 *
 * Every user-visible string lives here, keyed the same way in each language.
 * Markup inside a string is intentional (the strings are static, never user input)
 * and is inserted with innerHTML by applyI18n().
 *
 * Adding a language: add one entry to LANGS and one table to I18N. Missing keys
 * fall back to English, so a partial translation is safe to ship.
 */
const LANGS = [["en", "English"], ["zh-TW", "繁體中文"], ["zh-CN", "简体中文"]];

const I18N = {
  en: {
    "page.title": "Model comparison · video & image generation",
    "app.title": "Model Comparison",
    "app.sub": "One prompt, many models · video: LTX-2.5 / H3 / Wan · images: FLUX.2 / Qwen / HiDream · local ComfyUI",
    "lang.label": "Language",

    "queue.title": "ComfyUI queue status",
    "queue.dash": "queue —",
    "queue.busy": "running {running} · queued {pending}",
    "queue.idle": "queue idle",
    "queue.offline": "ComfyUI offline",
    "queue.connfail": "connection failed",
    "queue.tokenRequired": "token required",
    "queue.tokenEnter": "enter",
    "token.prompt": "This host is in public mode and needs an access token.\nThe token lives in compare/.token on the host.",

    "setup.summary": "⚙️ Workflow setup — once per model on first use",
    "setup.help": "<b>Easiest route:</b> open that model's official template in <a id=\"comfyLink\" href=\"http://localhost:8188\" target=\"_blank\">ComfyUI</a> (<i>Workflow → Browse Templates</i>) → press <b>Run</b> once → come back and press <b>🎯 Capture from ComfyUI</b> below. The workflow is captured and the model identified (that run is cancelled in the process). Do this once per model.",
    "setup.capture": "🎯 Capture from ComfyUI",
    "setup.byFile": "Or by file: enable <code>Dev mode</code> in ComfyUI, export with <b>Save (API Format)</b>, then drop the JSON onto a card below.",
    "setup.drop": "Drop an API workflow JSON here<br>or click to choose a file",
    "setup.ready": "Ready to compare",
    "setup.notImported": "No “{type}” workflow imported yet",

    "ctl.promptLabel": "Prompt — shared by all models",
    "ctl.random": "🎲 Random",
    "ctl.randomTitle": "Generate a random prompt",
    "ctl.promptHelp": "Describe the shot you want. Include the <b>subject</b>, the <b>action</b>, the <b>scene</b>, the <b>lighting</b> and a <b>style</b>. English prompts work better. 🎲 Random composes a detailed prompt for you.",
    "ctl.promptPh": "e.g. A red fox running through a snowy forest at sunrise, cinematic",
    "ctl.seed": "Seed",
    "ctl.seedHelp": "Same seed + same prompt = same result, which is what makes the comparison fair",
    "ctl.diceTitle": "Random",
    "ctl.resolution": "Resolution",
    "ctl.output": "Output",
    "ctl.image": "🖼️ Image",
    "ctl.video": "🎞️ Video",
    "ctl.models": "Models to compare",
    "ctl.go": "▶ Generate & compare",
    "ctl.stopAll": "■ Stop all",

    "msg.importing": "Importing…",
    "msg.importFailed": "Import failed: {error}",
    "msg.imported": "Imported: {label} · {type}",
    "msg.promptNodeFound": " (prompt node found)",
    "msg.promptNodeMissing": " (no prompt node — set the positive prompt to __PROMPT__ in the workflow)",
    "msg.capturing": "Capturing…",
    "msg.captured": "✅ Captured <b>{label}</b> ({type})",
    "msg.capturedPromptOk": " · prompt node found",
    "msg.capturedPromptMissing": " · <span class=\"err\">no prompt node</span>",
    "msg.captureFailed": "Capture failed — is ComfyUI running?",
    "msg.stopped": "All jobs stopped",
    "msg.stopFailed": "Stop failed",
    "msg.needPrompt": "Enter a prompt first",
    "msg.needModel": "Select at least one model",
    "msg.submitting": "Submitting…",
    "msg.queued": "Queued…",
    "msg.generating": "Generating… {secs}s",
    "msg.genFailed": "Generation failed",
    "msg.noOutput": "Finished, but no output file ({took}s)",
    "msg.noResponse": "No response",
    "msg.mediaFailed": "Failed to load the output file: {error}",
    "msg.clickFull": "Click to open the full-size file",
    "msg.tokens": "🧮 {width}×{height} · {frames} frames{fps} · {mark}{tokens} tokens",

    "err.UNAUTHORIZED": "Not authorised — check the access token",
    "err.ENDPOINT_DISABLED": "This endpoint is disabled in public mode",
    "err.NOT_A_WORKFLOW": "Not a valid workflow",
    "err.UI_FORMAT": "This is the editor (UI) format; the API format is required",
    "err.IMPORT_UI_FORMAT": "This is the editor (UI) format. Export it from ComfyUI with “Save (API Format)” and upload that file.",
    "err.UNKNOWN_MODEL": "Could not identify the model",
    "err.TEMPLATE_DIR_MISSING": "Template directory not found",
    "err.COMFY_UNREACHABLE": "Cannot reach ComfyUI: {detail}",
    "err.COMFY_EXEC": "ComfyUI execution error (see the ComfyUI log)",
    "err.COMFY_STATUS": "ComfyUI returned {code}: {detail}",
    "err.NOTHING_TO_CAPTURE": "Nothing to capture — open a template in ComfyUI and press Run first",
    "err.PROMPT_REQUIRED": "Enter a prompt",
    "err.PROMPT_TOO_LONG": "Prompt too long (max {max} characters)",
    "err.TOO_MANY_MODELS": "At most {max} models per run",
    "err.BAD_TYPE": "Unsupported output type: {type}",
    "err.BAD_RESOLUTION": "Unsupported resolution: {resolution}",
    "err.QUEUE_FULL": "Queue full ({depth}/{max}), try again later",
    "err.NO_WORKFLOW": "No “{type}” workflow imported for {label}",
    "err.NODE_ERROR": "Workflow node error: {detail}",

    "info.summary": "📋 Model specs & usage notes",
    "spec.params": "Params",
    "spec.precision": "Precision",
    "spec.vram": "VRAM",
    "spec.hdspeed": "HD speed",
    "spec.steps": "Steps",
    "spec.textenc": "Text encoder",
    "spec.maxres": "Max resolution",
    "spec.bestres": "Best resolution",
    "spec.trainedres": "Trained at",
    "spec.licence": "Licence",
    "spec.optim": "Optimisations",
    "spec.badgeVideo": "video",
    "nav.chat": "💬 AI Chat",
    "spec.base": "Base",
    "spec.source": "Source",
    "spec.quality": "Quality",
    "spec.h3tBase": "MiniMax H3 + distilled LoRA",
    "spec.h3t8Steps": "8 (14 in the original)",
    "spec.h3t4Steps": "4 (14 in the original)",
    "spec.h3tSource": "ModelTC (third party)",
    "spec.h3t8Quality": "Close to the original, slightly less detail",
    "spec.h3t4Quality": "Fast drafts; faces and hands lose detail",
    "msg.tokenInvalid": "Token invalid or changed.",
    "msg.reenterToken": "Enter it again",
    "spec.badgeImage": "image",
    "spec.fp8w": "FP8 weights",
    "spec.nvfp4mixed": "NVFP4 mixed",
    "spec.notMeasured": "not measured",
    "spec.minimaxOpen": "MiniMax open",
    "spec.perClip144": "~144s per 5s clip",
    "spec.perClip298": "~298s per 5s clip",
    "spec.h3note": "⚠️ 2K and above is not recommended — at high token counts Sol-Attn can produce grid artefacts, and full attention runs out of memory.",

    "res.heading": "📐 Resolution guidance",
    "res.video": "<b>Video</b>: HD (1376×768) is the sweet spot; FHD (1920×1080) looks better but takes twice as long; 2K is only advisable on LTX.",
    "res.image": "<b>Images</b>: 1024×1024 is the safe default; FLUX.2 goes up to 2048×2048; Qwen is best at 1328×1328 or 1664×928.",

    "tips.heading": "💡 Tips",
    "tips.1": "On first use, import each model's ComfyUI workflow under “Workflow setup” above.",
    "tips.2": "🎲 Random builds a prompt with subject, scene, lighting and camera style.",
    "tips.3": "The same seed and prompt makes the comparison across models fair.",
    "tips.4": "Click a generated image to open the full-size version in a new tab.",
    "tips.5": "Elapsed time and current VRAM usage appear at the bottom right of each output.",
    "tips.6": "Running one model at a time keeps memory pressure down and avoids OOM.",

    "hw.heading": "🖥️ Hardware",
    "hw.gpu": "<b>GPU</b>: NVIDIA GB10 (Blackwell) — 128 GB unified memory",
    "hw.cuda": "<b>CUDA</b>: 13.0 · Driver 580.173",
    "hw.comfy": "<b>ComfyUI</b>: latest + ComfyUI-Manager · bound to localhost:8188",
    "hw.quant": "<b>Quantisation</b>: NVFP4 (Blackwell-native) · FP8 · INT8, chosen per model"
  },

  "zh-TW": {
    "page.title": "模型比較 · 影片與圖片生成",
    "app.title": "模型比較",
    "app.sub": "同一個 prompt，多個模型 · 影片：LTX-2.5 / H3 / Wan · 圖片：FLUX.2 / Qwen / HiDream · 本機 ComfyUI",
    "lang.label": "語言",

    "queue.title": "ComfyUI 佇列狀態",
    "queue.dash": "佇列 —",
    "queue.busy": "執行中 {running} · 排隊 {pending}",
    "queue.idle": "佇列閒置",
    "queue.offline": "ComfyUI 離線",
    "queue.connfail": "連線失敗",
    "queue.tokenRequired": "需要密鑰",
    "queue.tokenEnter": "輸入",
    "token.prompt": "這台主機處於對外模式，需要存取密鑰。\n密鑰在主機的 compare/.token。",

    "setup.summary": "⚙️ workflow 設定 — 每個模型首次使用各設定一次",
    "setup.help": "<b>最簡單：</b>在 <a id=\"comfyLink\" href=\"http://localhost:8188\" target=\"_blank\">ComfyUI</a> 開啟該模型的官方 Template（<i>Workflow → Browse Templates</i>）→ 按一次 <b>Run</b> → 回到這裡按下方的 <b>🎯 從 ComfyUI 擷取</b>，即可自動抓取並辨識模型（會順手中斷該次生成）。每個模型各做一次。",
    "setup.capture": "🎯 從 ComfyUI 擷取",
    "setup.byFile": "或用檔案：在 ComfyUI 開啟 <code>Dev mode</code> 後用 <b>Save (API Format)</b> 匯出 JSON，拖到下方卡片。",
    "setup.drop": "拖入 API 格式的 workflow JSON<br>或點此選擇檔案",
    "setup.ready": "已可比較",
    "setup.notImported": "尚未匯入「{type}」的 workflow",

    "ctl.promptLabel": "Prompt — 所有模型共用",
    "ctl.random": "🎲 隨機",
    "ctl.randomTitle": "隨機產生 prompt",
    "ctl.promptHelp": "描述你想生成的畫面，建議包含：<b>主體</b>、<b>動作</b>、<b>場景</b>、<b>光線</b>、<b>風格</b>。英文 prompt 效果較佳。按 🎲 隨機可自動組合豐富的提示詞。",
    "ctl.promptPh": "例：A red fox running through a snowy forest at sunrise, cinematic",
    "ctl.seed": "Seed",
    "ctl.seedHelp": "相同 Seed + 相同 Prompt = 相同結果，這才是公平比較的前提",
    "ctl.diceTitle": "隨機",
    "ctl.resolution": "解析度",
    "ctl.output": "輸出形式",
    "ctl.image": "🖼️ 圖片",
    "ctl.video": "🎞️ 影片",
    "ctl.models": "要比較的模型",
    "ctl.go": "▶ 一次生成並比較",
    "ctl.stopAll": "■ 停止全部",

    "msg.importing": "匯入中…",
    "msg.importFailed": "匯入失敗：{error}",
    "msg.imported": "已匯入：{label} · {type}",
    "msg.promptNodeFound": "（已找到提示詞節點）",
    "msg.promptNodeMissing": "（未找到提示詞節點，請在 workflow 內把正向提示詞設為 __PROMPT__）",
    "msg.capturing": "擷取中…",
    "msg.captured": "✅ 已擷取 <b>{label}</b>（{type}）",
    "msg.capturedPromptOk": " · 已找到提示詞節點",
    "msg.capturedPromptMissing": " · <span class=\"err\">未找到提示詞節點</span>",
    "msg.captureFailed": "擷取失敗 — ComfyUI 有在跑嗎？",
    "msg.stopped": "已停止所有任務",
    "msg.stopFailed": "停止失敗",
    "msg.needPrompt": "請先輸入 prompt",
    "msg.needModel": "請至少選一個模型",
    "msg.submitting": "送出中…",
    "msg.queued": "排隊中…",
    "msg.generating": "生成中… {secs}s",
    "msg.genFailed": "生成失敗",
    "msg.noOutput": "完成，但沒有輸出檔（{took}s）",
    "msg.noResponse": "無回應",
    "msg.mediaFailed": "產出檔載入失敗：{error}",
    "msg.clickFull": "點擊開啟原始檔",
    "msg.tokens": "🧮 {width}×{height} · {frames} 格{fps} · {mark}{tokens} tokens",

    "err.UNAUTHORIZED": "未通過認證 — 請確認存取密鑰",
    "err.ENDPOINT_DISABLED": "此端點在對外模式已停用",
    "err.NOT_A_WORKFLOW": "不是有效的 workflow",
    "err.UI_FORMAT": "這是編輯器（UI）格式，需要 API 格式",
    "err.IMPORT_UI_FORMAT": "這是編輯器（UI）格式。請在 ComfyUI 用「Save (API Format)」匯出後再上傳。",
    "err.UNKNOWN_MODEL": "無法辨識模型",
    "err.TEMPLATE_DIR_MISSING": "找不到範本目錄",
    "err.COMFY_UNREACHABLE": "無法連到 ComfyUI：{detail}",
    "err.COMFY_EXEC": "ComfyUI 執行錯誤（見 ComfyUI log）",
    "err.COMFY_STATUS": "ComfyUI 回應 {code}：{detail}",
    "err.NOTHING_TO_CAPTURE": "目前沒有可擷取的 workflow — 請先在 ComfyUI 開啟範本並按 Run",
    "err.PROMPT_REQUIRED": "請輸入 prompt",
    "err.PROMPT_TOO_LONG": "prompt 太長（上限 {max} 字）",
    "err.TOO_MANY_MODELS": "一次最多比較 {max} 個模型",
    "err.BAD_TYPE": "不支援的輸出型態：{type}",
    "err.BAD_RESOLUTION": "不支援的解析度：{resolution}",
    "err.QUEUE_FULL": "佇列已滿（{depth}/{max}），請稍後再試",
    "err.NO_WORKFLOW": "{label} 尚未匯入「{type}」的 workflow",
    "err.NODE_ERROR": "workflow 有節點錯誤：{detail}",

    "info.summary": "📋 模型規格與使用說明",
    "spec.params": "參數量",
    "spec.precision": "精度",
    "spec.vram": "VRAM 用量",
    "spec.hdspeed": "HD 速度",
    "spec.steps": "步數",
    "spec.textenc": "文字編碼器",
    "spec.maxres": "最大解析度",
    "spec.bestres": "最佳解析度",
    "spec.trainedres": "訓練解析度",
    "spec.licence": "授權",
    "spec.optim": "優化",
    "spec.badgeVideo": "影片",
    "nav.chat": "💬 AI 對話",
    "spec.base": "基底",
    "spec.source": "來源",
    "spec.quality": "品質",
    "spec.h3tBase": "MiniMax H3 + 蒸餾 LoRA",
    "spec.h3t8Steps": "8（原版 14）",
    "spec.h3t4Steps": "4（原版 14）",
    "spec.h3tSource": "ModelTC（第三方）",
    "spec.h3t8Quality": "接近原版，細節略減",
    "spec.h3t4Quality": "快速草稿，臉部、手部細節有損失",
    "msg.tokenInvalid": "密鑰無效或已更換。",
    "msg.reenterToken": "重新輸入",
    "spec.badgeImage": "圖片",
    "spec.fp8w": "FP8 權重",
    "spec.nvfp4mixed": "NVFP4 混合",
    "spec.notMeasured": "待測",
    "spec.minimaxOpen": "MiniMax 開放",
    "spec.perClip144": "約 144s／5 秒影片",
    "spec.perClip298": "約 298s／5 秒影片",
    "spec.h3note": "⚠️ 不建議 2K 以上：token 數一高，Sol-Attn 可能產生網格偽影，改用全量 attention 則會 OOM。",

    "res.heading": "📐 解析度建議",
    "res.video": "<b>影片</b>：HD (1376×768) 性價比最好；FHD (1920×1080) 品質更佳但耗時加倍；2K 只建議用在 LTX。",
    "res.image": "<b>圖片</b>：1024×1024 是安全的預設值；FLUX.2 最高可到 2048×2048；Qwen 最佳為 1328×1328 或 1664×928。",

    "tips.heading": "💡 使用技巧",
    "tips.1": "首次使用請先在上方「workflow 設定」匯入各模型的 ComfyUI workflow。",
    "tips.2": "🎲 隨機會組出包含主體、場景、光線與攝影風格的完整提示詞。",
    "tips.3": "同一個 Seed 加同一段 Prompt，跨模型的比較才公平。",
    "tips.4": "點擊生成的圖片可在新分頁開啟原始尺寸。",
    "tips.5": "每個輸出的右下角會顯示耗時與當下的 VRAM 使用量。",
    "tips.6": "一次只跑一個模型可降低記憶體壓力，避免 OOM。",

    "hw.heading": "🖥️ 硬體環境",
    "hw.gpu": "<b>GPU</b>：NVIDIA GB10 (Blackwell) — 128GB 統一記憶體",
    "hw.cuda": "<b>CUDA</b>：13.0 · Driver 580.173",
    "hw.comfy": "<b>ComfyUI</b>：最新版 + ComfyUI-Manager · 綁定 localhost:8188",
    "hw.quant": "<b>量化格式</b>：NVFP4（Blackwell 原生）· FP8 · INT8，依模型選用"
  },

  "zh-CN": {
    "page.title": "模型对比 · 视频与图像生成",
    "app.title": "模型对比",
    "app.sub": "同一个 prompt，多个模型 · 视频：LTX-2.5 / H3 / Wan · 图像：FLUX.2 / Qwen / HiDream · 本机 ComfyUI",
    "lang.label": "语言",

    "queue.title": "ComfyUI 队列状态",
    "queue.dash": "队列 —",
    "queue.busy": "运行中 {running} · 排队 {pending}",
    "queue.idle": "队列空闲",
    "queue.offline": "ComfyUI 离线",
    "queue.connfail": "连接失败",
    "queue.tokenRequired": "需要密钥",
    "queue.tokenEnter": "输入",
    "token.prompt": "这台主机处于对外模式，需要访问密钥。\n密钥在主机的 compare/.token 中。",

    "setup.summary": "⚙️ workflow 设置 — 每个模型首次使用各设置一次",
    "setup.help": "<b>最简单：</b>在 <a id=\"comfyLink\" href=\"http://localhost:8188\" target=\"_blank\">ComfyUI</a> 打开该模型的官方 Template（<i>Workflow → Browse Templates</i>）→ 按一次 <b>Run</b> → 回到这里按下方的 <b>🎯 从 ComfyUI 抓取</b>，即可自动抓取并识别模型（会顺带中断这次生成）。每个模型各做一次。",
    "setup.capture": "🎯 从 ComfyUI 抓取",
    "setup.byFile": "或用文件：在 ComfyUI 打开 <code>Dev mode</code> 后用 <b>Save (API Format)</b> 导出 JSON，拖到下方卡片。",
    "setup.drop": "拖入 API 格式的 workflow JSON<br>或点此选择文件",
    "setup.ready": "已可对比",
    "setup.notImported": "尚未导入「{type}」的 workflow",

    "ctl.promptLabel": "Prompt — 所有模型共用",
    "ctl.random": "🎲 随机",
    "ctl.randomTitle": "随机生成 prompt",
    "ctl.promptHelp": "描述你想生成的画面，建议包含：<b>主体</b>、<b>动作</b>、<b>场景</b>、<b>光线</b>、<b>风格</b>。英文 prompt 效果更好。点 🎲 随机可自动组合丰富的提示词。",
    "ctl.promptPh": "例：A red fox running through a snowy forest at sunrise, cinematic",
    "ctl.seed": "Seed",
    "ctl.seedHelp": "相同 Seed + 相同 Prompt = 相同结果，这才是公平对比的前提",
    "ctl.diceTitle": "随机",
    "ctl.resolution": "分辨率",
    "ctl.output": "输出形式",
    "ctl.image": "🖼️ 图像",
    "ctl.video": "🎞️ 视频",
    "ctl.models": "要对比的模型",
    "ctl.go": "▶ 一次生成并对比",
    "ctl.stopAll": "■ 全部停止",

    "msg.importing": "导入中…",
    "msg.importFailed": "导入失败：{error}",
    "msg.imported": "已导入：{label} · {type}",
    "msg.promptNodeFound": "（已找到提示词节点）",
    "msg.promptNodeMissing": "（未找到提示词节点，请在 workflow 内把正向提示词设为 __PROMPT__）",
    "msg.capturing": "抓取中…",
    "msg.captured": "✅ 已抓取 <b>{label}</b>（{type}）",
    "msg.capturedPromptOk": " · 已找到提示词节点",
    "msg.capturedPromptMissing": " · <span class=\"err\">未找到提示词节点</span>",
    "msg.captureFailed": "抓取失败 — ComfyUI 在运行吗？",
    "msg.stopped": "已停止所有任务",
    "msg.stopFailed": "停止失败",
    "msg.needPrompt": "请先输入 prompt",
    "msg.needModel": "请至少选择一个模型",
    "msg.submitting": "提交中…",
    "msg.queued": "排队中…",
    "msg.generating": "生成中… {secs}s",
    "msg.genFailed": "生成失败",
    "msg.noOutput": "完成，但没有输出文件（{took}s）",
    "msg.noResponse": "无响应",
    "msg.mediaFailed": "输出文件加载失败：{error}",
    "msg.clickFull": "点击打开原始文件",
    "msg.tokens": "🧮 {width}×{height} · {frames} 帧{fps} · {mark}{tokens} tokens",

    "err.UNAUTHORIZED": "未通过认证 — 请检查访问密钥",
    "err.ENDPOINT_DISABLED": "该端点在对外模式已停用",
    "err.NOT_A_WORKFLOW": "不是有效的 workflow",
    "err.UI_FORMAT": "这是编辑器（UI）格式，需要 API 格式",
    "err.IMPORT_UI_FORMAT": "这是编辑器（UI）格式。请在 ComfyUI 用「Save (API Format)」导出后再上传。",
    "err.UNKNOWN_MODEL": "无法识别模型",
    "err.TEMPLATE_DIR_MISSING": "找不到模板目录",
    "err.COMFY_UNREACHABLE": "无法连接 ComfyUI：{detail}",
    "err.COMFY_EXEC": "ComfyUI 执行错误（见 ComfyUI log）",
    "err.COMFY_STATUS": "ComfyUI 返回 {code}：{detail}",
    "err.NOTHING_TO_CAPTURE": "目前没有可抓取的 workflow — 请先在 ComfyUI 打开模板并按 Run",
    "err.PROMPT_REQUIRED": "请输入 prompt",
    "err.PROMPT_TOO_LONG": "prompt 太长（上限 {max} 字）",
    "err.TOO_MANY_MODELS": "一次最多对比 {max} 个模型",
    "err.BAD_TYPE": "不支持的输出类型：{type}",
    "err.BAD_RESOLUTION": "不支持的分辨率：{resolution}",
    "err.QUEUE_FULL": "队列已满（{depth}/{max}），请稍后再试",
    "err.NO_WORKFLOW": "{label} 尚未导入「{type}」的 workflow",
    "err.NODE_ERROR": "workflow 有节点错误：{detail}",

    "info.summary": "📋 模型规格与使用说明",
    "spec.params": "参数量",
    "spec.precision": "精度",
    "spec.vram": "显存用量",
    "spec.hdspeed": "HD 速度",
    "spec.steps": "步数",
    "spec.textenc": "文本编码器",
    "spec.maxres": "最大分辨率",
    "spec.bestres": "最佳分辨率",
    "spec.trainedres": "训练分辨率",
    "spec.licence": "许可",
    "spec.optim": "优化",
    "spec.badgeVideo": "视频",
    "nav.chat": "💬 AI 对话",
    "spec.base": "基底",
    "spec.source": "来源",
    "spec.quality": "质量",
    "spec.h3tBase": "MiniMax H3 + 蒸馏 LoRA",
    "spec.h3t8Steps": "8（原版 14）",
    "spec.h3t4Steps": "4（原版 14）",
    "spec.h3tSource": "ModelTC（第三方）",
    "spec.h3t8Quality": "接近原版，细节略减",
    "spec.h3t4Quality": "快速草稿，面部、手部细节有损失",
    "msg.tokenInvalid": "密钥无效或已更换。",
    "msg.reenterToken": "重新输入",
    "spec.badgeImage": "图像",
    "spec.fp8w": "FP8 权重",
    "spec.nvfp4mixed": "NVFP4 混合",
    "spec.notMeasured": "待测",
    "spec.minimaxOpen": "MiniMax 开放",
    "spec.perClip144": "约 144s／5 秒视频",
    "spec.perClip298": "约 298s／5 秒视频",
    "spec.h3note": "⚠️ 不建议 2K 以上：token 数一高，Sol-Attn 可能产生网格伪影，改用全量 attention 则会 OOM。",

    "res.heading": "📐 分辨率建议",
    "res.video": "<b>视频</b>：HD (1376×768) 性价比最好；FHD (1920×1080) 质量更佳但耗时加倍；2K 只建议用在 LTX。",
    "res.image": "<b>图像</b>：1024×1024 是安全的默认值；FLUX.2 最高可到 2048×2048；Qwen 最佳为 1328×1328 或 1664×928。",

    "tips.heading": "💡 使用技巧",
    "tips.1": "首次使用请先在上方「workflow 设置」导入各模型的 ComfyUI workflow。",
    "tips.2": "🎲 随机会组出包含主体、场景、光线与摄影风格的完整提示词。",
    "tips.3": "同一个 Seed 加同一段 Prompt，跨模型的对比才公平。",
    "tips.4": "点击生成的图像可在新标签页打开原始尺寸。",
    "tips.5": "每个输出的右下角会显示耗时与当前的显存使用量。",
    "tips.6": "一次只跑一个模型可降低内存压力，避免 OOM。",

    "hw.heading": "🖥️ 硬件环境",
    "hw.gpu": "<b>GPU</b>：NVIDIA GB10 (Blackwell) — 128GB 统一内存",
    "hw.cuda": "<b>CUDA</b>：13.0 · Driver 580.173",
    "hw.comfy": "<b>ComfyUI</b>：最新版 + ComfyUI-Manager · 绑定 localhost:8188",
    "hw.quant": "<b>量化格式</b>：NVFP4（Blackwell 原生）· FP8 · INT8，按模型选用"
  }
};

/* ---------- runtime ---------- */

// Browser language → one of our tables. Any zh-Hant/TW/HK/MO tag maps to zh-TW,
// every other zh tag to zh-CN; anything else falls back to English.
function detectLang() {
  try {
    const saved = localStorage.getItem("lang");
    if (saved && I18N[saved]) return saved;
  } catch (e) { /* storage blocked — fall through to the browser language */ }
  const tags = navigator.languages && navigator.languages.length
    ? navigator.languages : [navigator.language || "en"];
  for (const tag of tags) {
    const t = String(tag).toLowerCase();
    if (t.startsWith("zh")) return /hant|tw|hk|mo/.test(t) ? "zh-TW" : "zh-CN";
    if (t.startsWith("en")) return "en";
  }
  return "en";
}

let LANG = detectLang();

function t(key, vars) {
  const table = I18N[LANG] || I18N.en;
  let s = table[key];
  if (s === undefined) s = I18N.en[key];
  if (s === undefined) return key;
  return vars ? s.replace(/\{(\w+)\}/g, (_, k) => (vars[k] === undefined ? "" : vars[k])) : s;
}

// Translate every [data-i18n*] element under root. Strings are static and may
// contain markup, so innerHTML is intended here.
function applyI18n(root) {
  root = root || document;
  root.querySelectorAll("[data-i18n]").forEach(el => { el.innerHTML = t(el.dataset.i18n); });
  root.querySelectorAll("[data-i18n-title]").forEach(el => { el.title = t(el.dataset.i18nTitle); });
  root.querySelectorAll("[data-i18n-ph]").forEach(el => { el.placeholder = t(el.dataset.i18nPh); });
  if (root === document) {
    document.documentElement.lang = LANG;
    document.title = t("page.title");
  }
}

// Called after the language changes so views built in JS are rebuilt too.
const I18N_LISTENERS = [];
function onLangChange(fn) { I18N_LISTENERS.push(fn); }

function setLang(lang) {
  if (!I18N[lang]) return;
  LANG = lang;
  try { localStorage.setItem("lang", lang); } catch (e) { /* ignore */ }
  applyI18n();
  I18N_LISTENERS.forEach(fn => fn());
}

// Renders the language <select> into the element with the given id.
function mountLangPicker(id) {
  const sel = document.getElementById(id);
  if (!sel) return;
  sel.innerHTML = "";
  LANGS.forEach(([code, name]) => {
    const o = document.createElement("option");
    o.value = code; o.textContent = name; o.selected = code === LANG;
    sel.appendChild(o);
  });
  sel.onchange = () => setLang(sel.value);
  // The markup ships it hidden: an empty dropdown is worse than none at all on
  // a page rendered without JavaScript.
  sel.hidden = false;
}

// Turns an API error payload into a localised message. The server sends a stable
// error_code plus parameters; `error` is the English fallback for other clients.
function apiError(d) {
  if (!d) return t("msg.noResponse");
  if (d.error_code) return t("err." + d.error_code, d.error_params || {});
  return d.error || t("msg.noResponse");
}
