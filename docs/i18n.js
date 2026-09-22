/* Runtime translations for the project landing page (GitHub Pages).
 *
 * Same shape and runtime as compare/i18n.js: one table per language, English as
 * the fallback, keys referenced from the markup with data-i18n attributes.
 */
const LANGS = [["en", "English"], ["zh-TW", "繁體中文"], ["zh-CN", "简体中文"]];

const I18N = {
  en: {
    "page.title": "LLM Explorer — AI model comparison tool",
    "lang.label": "Language",
    "hero.tagline": "Multi-model AI generation compared side by side — video &amp; images, fully local",
    "hero.badgeHw": "🖥️ NVIDIA GB10 · 128GB",

    "feat.heading": "Features",
    "feat.1.h": "⚡ Same prompt, side by side",
    "feat.1.p": "Same prompt and same seed, sent to several models in one click; results line up next to each other so quality differences are obvious.",
    "feat.2.h": "🎲 Prompt generator",
    "feat.2.p": "A built-in random prompt engine: 12 subject descriptions, 30 actions, 18 scenes with matching audio, and a range of camera styles.",
    "feat.3.h": "🔒 Fully offline",
    "feat.3.p": "Every model runs locally and nothing leaves the machine. Bound to localhost, so generation needs no internet connection.",
    "feat.4.h": "📐 Multiple resolutions",
    "feat.4.p": "Video: SD / HD / FHD / 2K. Images: 1:1 / 4:3 / 3:4 / 16:9 / 9:16, tuned to each model's native resolution.",
    "feat.5.h": "🚀 Tuned for GB10",
    "feat.5.p": "NVFP4 quantisation, Sol-Attn sparse attention, FirstBlockCache and TeaCache — H3 went from 1200s down to 298s.",
    "feat.6.h": "💾 Live monitoring",
    "feat.6.p": "Each finished run reports elapsed time and VRAM usage, so resource cost stays visible. Click an image to open the full-size version.",

    "models.heading": "Supported models",
    "tag.video": "video",
    "tag.image": "image",
    "spec.params": "Params",
    "spec.precision": "Precision",
    "spec.hdspeed": "HD speed",
    "spec.licence": "Licence",
    "spec.steps": "Steps",
    "spec.nvfp4mixed": "NVFP4 mixed",
    "spec.notMeasured": "not measured",
    "spec.minimaxOpen": "MiniMax open",
    "spec.speed144": "~144s / 5s",
    "spec.speed298": "~298s / 5s",

    "bench.heading": "Benchmarks",
    "bench.model": "Model",
    "bench.type": "Type",
    "bench.video5s": "video 5s",
    "bench.image": "image",
    "bench.flux": "~57s (NVFP4, 10 steps)",
    "bench.qwen": "~26s (int8, 25 steps, CFG=1)",
    "bench.hidream": "~35s (FP8, 20 steps, LCM)",
    "bench.note": "* Measured on NVIDIA GB10 (DGX Spark), 128 GB unified memory. Image timings are estimates.",

    "arch.heading": "Architecture",
    "arch.chatbot": "multi-LLM chat UI (Qwen3 / Gemma3)",
    "arch.models": "model list",
    "arch.setup": "PyTorch cu130 + aarch64 environment",
    "arch.workflows": "official templates + comparison notes",
    "arch.compare": "comparison tool (Python)",
    "arch.server": "API proxy + workflow injection",
    "arch.index": "comparison UI + inline help",
    "arch.cworkflows": "API-format workflows for 6 models",
    "arch.docs": "documentation + GitHub Pages",

    "hw.heading": "Hardware",
    "hw.gpu": "NVIDIA Blackwell GPU",
    "hw.mem": "Unified memory",
    "hw.disk": "NVMe SSD",

    "opt.heading": "Optimisations",
    "opt.1.h": "🔢 NVFP4 quantisation",
    "opt.1.p": "Blackwell's native 4-bit mixed-precision format. FLUX.2 drops from 34 GB to 22 GB, memory traffic falls by 35%, and throughput rises roughly 30-40%.",
    "opt.2.h": "⚡ Sol-Attn sparse attention",
    "opt.2.p": "H3-specific speed-up. tau=1.3 is stable at HD; at higher resolutions watch the token count.",
    "opt.3.h": "🧊 FirstBlockCache",
    "opt.3.p": "Caches the first transformer block's output to avoid recomputation. Threshold 0.1, at most 2 consecutive hits.",
    "opt.4.h": "🍵 TeaCache",
    "opt.4.p": "H3-specific temporal cache: when the difference between adjacent steps falls below the threshold, the step is skipped, speeding up the denoising loop.",

    "footer.built": "LLM Explorer — Built for <a href=\"https://www.nvidia.com/en-us/desktops/dgx-spark/\">NVIDIA DGX Spark</a> (GB10)"
  },

  "zh-TW": {
    "page.title": "LLM Explorer — AI 模型比較工具",
    "lang.label": "語言",
    "hero.tagline": "多模型 AI 生成並排比較 — 影片與圖片，完全在本機執行",
    "hero.badgeHw": "🖥️ NVIDIA GB10 · 128GB",

    "feat.heading": "功能特色",
    "feat.1.h": "⚡ 同一個 Prompt 並排比較",
    "feat.1.p": "相同提示詞加相同 Seed，一鍵送出多個模型同時生成，結果並排顯示，品質差異一目了然。",
    "feat.2.h": "🎲 提示詞產生器",
    "feat.2.p": "內建隨機提示詞引擎：12 種角色描述、30 種動作、18 種場景與對應音效，以及多種攝影風格。",
    "feat.3.h": "🔒 完全離線",
    "feat.3.p": "所有模型都在本機執行，資料不外流。綁定 localhost，無需網路連線即可生成。",
    "feat.4.h": "📐 多解析度支援",
    "feat.4.p": "影片：SD / HD / FHD / 2K。圖片：1:1 / 4:3 / 3:4 / 16:9 / 9:16，依各模型原生解析度最佳化。",
    "feat.5.h": "🚀 GB10 深度優化",
    "feat.5.p": "NVFP4 量化、Sol-Attn 稀疏注意力、FirstBlockCache、TeaCache — H3 從 1200s 加速到 298s。",
    "feat.6.h": "💾 即時監控",
    "feat.6.p": "每次生成完成都會顯示耗時與 VRAM 使用量，資源消耗一目了然。點擊圖片可開啟原始尺寸。",

    "models.heading": "支援模型",
    "tag.video": "影片",
    "tag.image": "圖片",
    "spec.params": "參數量",
    "spec.precision": "精度",
    "spec.hdspeed": "HD 速度",
    "spec.licence": "授權",
    "spec.steps": "步數",
    "spec.nvfp4mixed": "NVFP4 混合",
    "spec.notMeasured": "待測",
    "spec.minimaxOpen": "MiniMax 開放",
    "spec.speed144": "約 144s／5 秒",
    "spec.speed298": "約 298s／5 秒",

    "bench.heading": "效能基準",
    "bench.model": "模型",
    "bench.type": "類型",
    "bench.video5s": "影片 5 秒",
    "bench.image": "圖片",
    "bench.flux": "約 57s（NVFP4，10 步）",
    "bench.qwen": "約 26s（int8，25 步，CFG=1）",
    "bench.hidream": "約 35s（FP8，20 步，LCM）",
    "bench.note": "* 測試於 NVIDIA GB10 (DGX Spark)，128GB 統一記憶體。圖片速度為預估值。",

    "arch.heading": "系統架構",
    "arch.chatbot": "多 LLM 聊天介面（Qwen3 / Gemma3）",
    "arch.models": "模型清單",
    "arch.setup": "PyTorch cu130 + aarch64 環境",
    "arch.workflows": "官方模板 + 比對說明",
    "arch.compare": "模型比較工具（Python）",
    "arch.server": "API proxy + workflow 注入引擎",
    "arch.index": "比較介面 + 內嵌說明",
    "arch.cworkflows": "6 個模型的 API 格式 workflow",
    "arch.docs": "說明文件 + GitHub Pages",

    "hw.heading": "硬體環境",
    "hw.gpu": "NVIDIA Blackwell GPU",
    "hw.mem": "統一記憶體",
    "hw.disk": "NVMe SSD",

    "opt.heading": "優化技術",
    "opt.1.h": "🔢 NVFP4 量化",
    "opt.1.p": "Blackwell 原生的 4-bit 混合精度格式。FLUX.2 從 34GB 降到 22GB，記憶體搬運減少 35%，速度提升約 30-40%。",
    "opt.2.h": "⚡ Sol-Attn 稀疏注意力",
    "opt.2.p": "H3 專用加速。tau=1.3 在 HD 解析度下穩定運作；解析度更高時要注意 token 數。",
    "opt.3.h": "🧊 FirstBlockCache",
    "opt.3.p": "快取第一層 transformer block 的運算結果以避免重算。閾值 0.1，最多連續命中 2 次。",
    "opt.4.h": "🍵 TeaCache",
    "opt.4.p": "H3 專用的時序快取：相鄰步之間的差異小於閾值時就跳過該步，加速 denoising 迴圈。",

    "footer.built": "LLM Explorer — 為 <a href=\"https://www.nvidia.com/en-us/desktops/dgx-spark/\">NVIDIA DGX Spark</a>（GB10）打造"
  },

  "zh-CN": {
    "page.title": "LLM Explorer — AI 模型对比工具",
    "lang.label": "语言",
    "hero.tagline": "多模型 AI 生成并排对比 — 视频与图像，完全在本机运行",
    "hero.badgeHw": "🖥️ NVIDIA GB10 · 128GB",

    "feat.heading": "功能特色",
    "feat.1.h": "⚡ 同一个 Prompt 并排对比",
    "feat.1.p": "相同提示词加相同 Seed，一键提交多个模型同时生成，结果并排显示，质量差异一目了然。",
    "feat.2.h": "🎲 提示词生成器",
    "feat.2.p": "内置随机提示词引擎：12 种角色描述、30 种动作、18 种场景与对应音效，以及多种摄影风格。",
    "feat.3.h": "🔒 完全离线",
    "feat.3.p": "所有模型都在本机运行，数据不外泄。绑定 localhost，无需联网即可生成。",
    "feat.4.h": "📐 多分辨率支持",
    "feat.4.p": "视频：SD / HD / FHD / 2K。图像：1:1 / 4:3 / 3:4 / 16:9 / 9:16，按各模型原生分辨率优化。",
    "feat.5.h": "🚀 GB10 深度优化",
    "feat.5.p": "NVFP4 量化、Sol-Attn 稀疏注意力、FirstBlockCache、TeaCache — H3 从 1200s 加速到 298s。",
    "feat.6.h": "💾 实时监控",
    "feat.6.p": "每次生成完成都会显示耗时与显存使用量，资源消耗一目了然。点击图像可打开原始尺寸。",

    "models.heading": "支持模型",
    "tag.video": "视频",
    "tag.image": "图像",
    "spec.params": "参数量",
    "spec.precision": "精度",
    "spec.hdspeed": "HD 速度",
    "spec.licence": "许可",
    "spec.steps": "步数",
    "spec.nvfp4mixed": "NVFP4 混合",
    "spec.notMeasured": "待测",
    "spec.minimaxOpen": "MiniMax 开放",
    "spec.speed144": "约 144s／5 秒",
    "spec.speed298": "约 298s／5 秒",

    "bench.heading": "性能基准",
    "bench.model": "模型",
    "bench.type": "类型",
    "bench.video5s": "视频 5 秒",
    "bench.image": "图像",
    "bench.flux": "约 57s（NVFP4，10 步）",
    "bench.qwen": "约 26s（int8，25 步，CFG=1）",
    "bench.hidream": "约 35s（FP8，20 步，LCM）",
    "bench.note": "* 测试于 NVIDIA GB10 (DGX Spark)，128GB 统一内存。图像速度为预估值。",

    "arch.heading": "系统架构",
    "arch.chatbot": "多 LLM 聊天界面（Qwen3 / Gemma3）",
    "arch.models": "模型清单",
    "arch.setup": "PyTorch cu130 + aarch64 环境",
    "arch.workflows": "官方模板 + 对比说明",
    "arch.compare": "模型对比工具（Python）",
    "arch.server": "API proxy + workflow 注入引擎",
    "arch.index": "对比界面 + 内嵌说明",
    "arch.cworkflows": "6 个模型的 API 格式 workflow",
    "arch.docs": "说明文档 + GitHub Pages",

    "hw.heading": "硬件环境",
    "hw.gpu": "NVIDIA Blackwell GPU",
    "hw.mem": "统一内存",
    "hw.disk": "NVMe SSD",

    "opt.heading": "优化技术",
    "opt.1.h": "🔢 NVFP4 量化",
    "opt.1.p": "Blackwell 原生的 4-bit 混合精度格式。FLUX.2 从 34GB 降到 22GB，内存搬运减少 35%，速度提升约 30-40%。",
    "opt.2.h": "⚡ Sol-Attn 稀疏注意力",
    "opt.2.p": "H3 专用加速。tau=1.3 在 HD 分辨率下稳定运行；分辨率更高时要注意 token 数。",
    "opt.3.h": "🧊 FirstBlockCache",
    "opt.3.p": "缓存第一层 transformer block 的运算结果以避免重算。阈值 0.1，最多连续命中 2 次。",
    "opt.4.h": "🍵 TeaCache",
    "opt.4.p": "H3 专用的时序缓存：相邻步之间的差异小于阈值时就跳过该步，加速 denoising 循环。",

    "footer.built": "LLM Explorer — 为 <a href=\"https://www.nvidia.com/en-us/desktops/dgx-spark/\">NVIDIA DGX Spark</a>（GB10）打造"
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
