#!/usr/bin/env python3
"""
LLM Explorer —— HuggingFace Space 前端。

這支程式跑在 HF Space 上，透過通道把生成請求轉給家裡那台 GB10。
安全模型分三層：
  1. Space 本身 private + 帳號登入  → 誰能用這個 UI
  2. 共享密鑰 (COMPARE_TOKEN)       → 只有這個 Space 打得進那台機器
  3. 機器端 server.py 的端點白名單   → 就算前兩層外洩，也只能生成，不能寫檔

必要的環境變數（在 HF Space 的 Settings → Secrets 設定）：
  COMPARE_URL    通道網址，例如 https://xxx.trycloudflare.com
  COMPARE_TOKEN  與機器端 server.py 相同的密鑰
選用：
  SPACE_USERS    登入帳密，格式 "alice:pw1,bob:pw2"。沒設就不要求登入
                 （僅在 Space 已設為 private 時才可省略）
"""
import os, time, json, random, tempfile
import requests
import gradio as gr

COMPARE_URL = os.environ.get("COMPARE_URL", "http://127.0.0.1:8890").rstrip("/")
COMPARE_TOKEN = os.environ.get("COMPARE_TOKEN", "")
POLL_SECS = 3.0
REQ_TIMEOUT = 30

MODELS = {
    "video": [("ltx", "LTX-2.5"), ("h3", "MiniMax H3"), ("wan", "Wan 2.2")],
    "image": [("flux2", "FLUX.2 Dev"), ("qwen", "Qwen-Image"), ("hidream", "HiDream-I1")],
}
LABEL = {k: v for lst in MODELS.values() for k, v in lst}
MAX_MODELS = 3  # 與 server.py 的 COMPARE_MAX_MODELS 一致

RES = {
    "video": [("860x480", "860×480 (SD)"),
              ("1376x768", "1376×768 (HD)"),
              ("1920x1080", "1920×1080 (FHD)")],
    "image": [("1024x1024", "1024×1024 (1:1)"),
              ("1152x896", "1152×896 (4:3)"),
              ("896x1152", "896×1152 (3:4)"),
              ("1344x768", "1344×768 (16:9)"),
              ("768x1344", "768×1344 (9:16)")],
}
DEFAULT_RES = {"video": "1376x768", "image": "1024x1024"}

# 各模型在基準解析度下的實測秒數（影片 = HD 5 秒片；圖片 = 1024²）。
# 圖片這幾個含冷啟動載入權重的時間——HiDream 實測 60 秒，其中純取樣只佔一半左右，
# 剩下是把 16~22GB 權重搬進 VRAM。連續跑同一個模型會比這裡快。
BASE_SECS = {"ltx": 144, "h3": 298, "wan": 200,
             "flux2": 85, "qwen": 70, "hidream": 60}
BASE_MP = {"video": 1376 * 768 / 1e6, "image": 1024 * 1024 / 1e6}
# attention 隨 token 數超線性成長：H3 在 HD→FHD（1.96x 畫素）實測慢 2.59x → 指數約 1.4
SCALE_EXP = {"video": 1.4, "image": 1.2}


# ---------- 與家裡機器溝通 ----------
def _hdr():
    return {"X-Compare-Token": COMPARE_TOKEN} if COMPARE_TOKEN else {}


def api_get(path, **params):
    r = requests.get(COMPARE_URL + path, params=params or None,
                     headers=_hdr(), timeout=REQ_TIMEOUT)
    r.raise_for_status()
    return r


def api_post(path, body):
    r = requests.post(COMPARE_URL + path, json=body,
                      headers={**_hdr(), "Content-Type": "application/json"},
                      timeout=REQ_TIMEOUT)
    r.raise_for_status()
    return r.json()


def queue_depth():
    """回傳 (running, pending)，連不上時回 None。"""
    try:
        d = api_get("/api/queue").json()
        if not d.get("ok"):
            return None
        return d.get("running", 0), d.get("pending", 0)
    except Exception:
        return None


def estimate_secs(models, otype, resolution):
    """粗估這批工作要跑多久（秒）。"""
    try:
        w, h = (int(x) for x in resolution.split("x"))
        mp = w * h / 1e6
    except Exception:
        mp = BASE_MP[otype]
    scale = (mp / BASE_MP[otype]) ** SCALE_EXP[otype]
    return sum(BASE_SECS.get(m, 150) * scale for m in models)


def fmt_dur(secs):
    secs = int(max(secs, 0))
    if secs < 60:
        return f"{secs} 秒"
    m, s = divmod(secs, 60)
    return f"{m} 分 {s} 秒" if s else f"{m} 分"


def queue_text():
    q = queue_depth()
    if q is None:
        return "🔴 **生成主機離線** —— 家裡那台機器目前連不上，請稍後再試。"
    running, pending = q
    total = running + pending
    if total == 0:
        return "🟢 **佇列閒置** —— 現在送出會立刻開始。"
    # 用最慢的影片模型當保守估計
    wait = fmt_dur(total * BASE_SECS["h3"])
    return (f"🟠 **執行中 {running} · 排隊 {pending}** —— "
            f"你的工作前面還有 {total} 個，預估等待約 {wait}。")


# ---------- 隨機提示詞 ----------
CHARS = [
    "a weathered fisherman in his sixties, deep-set eyes, salt-crusted wool sweater",
    "a young dancer with cropped black hair, freckled shoulders, worn practice clothes",
    "an elderly calligrapher, thin silver beard, ink-stained fingers, indigo robe",
    "a teenage cyclist in a rain-soaked yellow jacket, hair plastered to her forehead",
    "a broad-shouldered blacksmith, soot on his forearms, leather apron",
    "a librarian in a moss-green cardigan, round glasses, chalk dust on her sleeve",
    "a street violinist with a scarred chin, threadbare coat, fingerless gloves",
    "a botanist kneeling in mud, canvas hat, magnifying loupe on a cord",
]
ACTIONS = [
    "mending a net with slow, practiced hands", "stretching at a barre before dawn",
    "grinding ink in a shallow stone well", "coasting downhill through standing water",
    "hammering glowing metal in steady rhythm", "reshelving books by lamplight",
    "tuning strings with head tilted, listening", "pressing a leaf between glass plates",
    "laughing at something just out of frame", "pulling a coat tighter against the wind",
    "tracing a map with one finger", "watching rain gather at a windowsill",
]
ENVS = [
    ("a harbour at low tide, hulls tilted in the mud", "gulls calling, rigging clinking, water lapping against stone"),
    ("an empty rehearsal studio with tall dusty windows", "a piano tuning up faintly, floorboards creaking"),
    ("a bamboo forest after rain", "leaves dripping, stalks knocking together, distant birdsong"),
    ("a neon-lit alley slick with rain", "tyres hissing on wet asphalt, a vent humming, muffled music"),
    ("a forge at dusk, embers drifting", "hammer strikes ringing, bellows breathing, coals settling"),
    ("a reading room lined with oak shelves", "pages turning, a clock ticking, a chair scraping"),
    ("a train platform in thick fog", "rails humming, an announcement echoing, footsteps receding"),
    ("a greenhouse crowded with ferns", "condensation dripping, a fan turning, glass creaking in the heat"),
    ("a salt flat under an enormous sky", "wind over open ground, crust crunching underfoot"),
    ("a rooftop above a sleeping city", "distant traffic, a flag snapping, an aircraft passing over"),
]
LIGHTS = ["low golden hour light raking across the frame", "overcast diffused light, soft shadows",
          "single hard key light from a window", "cool blue pre-dawn light",
          "warm tungsten glow against deep shadow", "dappled light through moving leaves"]
STYLES = ["shot on 35mm film, fine grain", "cinematic anamorphic, shallow depth of field",
          "documentary handheld realism", "muted desaturated palette, high contrast",
          "rich saturated colour, crisp detail", "soft focus, painterly tonality"]
CAM_V = ["slow dolly in", "steady tracking shot alongside", "locked-off wide shot",
         "gentle handheld push", "slow crane rising", "static medium close-up"]
CAM_I = ["tight portrait composition", "wide environmental framing", "low angle looking up",
         "overhead flat-lay composition", "off-centre rule-of-thirds framing", "intimate close-up"]


def random_prompt(otype):
    env, audio = random.choice(ENVS)
    cam = random.choice(CAM_V if otype == "video" else CAM_I)
    parts = [f"{cam}: {random.choice(CHARS)}, {random.choice(ACTIONS)}",
             f"in {env}", random.choice(LIGHTS), random.choice(STYLES)]
    if otype == "video":
        parts.append(f"Sound: {audio}")
    return ". ".join(parts) + "."


# ---------- 生成 ----------
def _download(media):
    """把產出檔抓回 Space 本機（瀏覽器無法自己帶認證標頭，所以必須由伺服器代抓）。"""
    r = api_get("/api/view", filename=media["filename"],
                subfolder=media.get("subfolder", ""), type=media.get("type", "output"))
    suffix = os.path.splitext(media["filename"])[1] or ".bin"
    fd, path = tempfile.mkstemp(suffix=suffix)
    with os.fdopen(fd, "wb") as f:
        f.write(r.content)
    return path


def _slots(states):
    """把每個模型的狀態攤平成 Gradio 輸出（3 組：標題 / 影片 / 圖片）。"""
    out = []
    for i in range(MAX_MODELS):
        if i < len(states):
            name, note, vid, img = states[i]
            out += [gr.update(value=f"### {name}\n{note}", visible=True),
                    gr.update(value=vid, visible=vid is not None),
                    gr.update(value=img, visible=img is not None)]
        else:
            out += [gr.update(visible=False),
                    gr.update(value=None, visible=False),
                    gr.update(value=None, visible=False)]
    return out


def generate(prompt, seed, otype, models, resolution):
    prompt = (prompt or "").strip()
    if not prompt:
        raise gr.Error("請先輸入 prompt。")
    if not models:
        raise gr.Error("請至少選一個模型。")
    if len(models) > MAX_MODELS:
        raise gr.Error(f"一次最多比較 {MAX_MODELS} 個模型。")

    eta = estimate_secs(models, otype, resolution)
    yield (f"送出中…（{len(models)} 個模型，預估約 {fmt_dur(eta)}）", *_slots([]))

    try:
        resp = api_post("/api/generate", {
            "prompt": prompt, "seed": int(seed), "type": otype,
            "models": list(models), "resolution": resolution,
        })
    except requests.HTTPError as e:
        detail = ""
        try:
            detail = e.response.json().get("error", "")
        except Exception:
            detail = e.response.text[:200]
        if e.response.status_code == 429:
            raise gr.Error(f"主機忙碌：{detail}")
        if e.response.status_code in (401, 403):
            raise gr.Error("Space 無法通過主機認證，請檢查 COMPARE_TOKEN 設定。")
        raise gr.Error(f"送出失敗（HTTP {e.response.status_code}）：{detail}")
    except Exception as e:
        raise gr.Error(f"連不上生成主機：{e}")

    results = resp.get("results", {})
    jobs, states = [], []
    for m in models:
        r = results.get(m, {})
        if r.get("error"):
            states.append((LABEL.get(m, m), f"❌ {r['error']}", None, None))
        elif r.get("prompt_id"):
            jobs.append((m, r["prompt_id"], len(states)))
            states.append((LABEL.get(m, m), "⏳ 排隊中…", None, None))
        else:
            states.append((LABEL.get(m, m), "❌ 主機沒有回傳工作編號", None, None))

    if not jobs:
        yield ("全部送出失敗。", *_slots(states))
        return

    t0 = time.time()
    pending = dict((pid, (m, idx)) for m, pid, idx in jobs)
    while pending:
        time.sleep(POLL_SECS)
        elapsed = time.time() - t0
        for pid in list(pending):
            m, idx = pending[pid]
            try:
                d = api_get("/api/status", id=pid).json()
            except Exception:
                continue
            st = d.get("state")
            if st == "queued":
                states[idx] = (LABEL.get(m, m), "⏳ 排隊中…", None, None)
            elif st == "running":
                states[idx] = (LABEL.get(m, m), f"🎬 生成中… {int(elapsed)}s", None, None)
            elif st == "error":
                states[idx] = (LABEL.get(m, m), f"❌ {d.get('error', '生成失敗')}", None, None)
                pending.pop(pid)
            elif st == "done":
                media = d.get("media") or []
                vid = img = None
                for mm in media:
                    try:
                        p = _download(mm)
                    except Exception as e:
                        states[idx] = (LABEL.get(m, m), f"❌ 取檔失敗：{e}", None, None)
                        break
                    if mm.get("kind") == "video":
                        vid = p
                    else:
                        img = p
                else:
                    took = fmt_dur(elapsed)
                    vram = d.get("vram_gb")
                    note = f"✅ {took}" + (f" · 💾 {vram} GB" if vram else "")
                    if not media:
                        note = "⚠️ 完成但沒有輸出檔"
                    states[idx] = (LABEL.get(m, m), note, vid, img)
                pending.pop(pid)

        done = len(jobs) - len(pending)
        head = (f"完成 {done}/{len(jobs)} · 已耗時 {fmt_dur(elapsed)}"
                f"（預估總長約 {fmt_dur(eta)}）")
        yield (head, *_slots(states))

    yield (f"✅ 全部完成，共 {fmt_dur(time.time() - t0)}。", *_slots(states))


# ---------- 介面 ----------
def on_type_change(otype):
    choices = [(lbl, val) for val, lbl in MODELS[otype]]
    res_choices = [(lbl, val) for val, lbl in RES[otype]]
    return (gr.update(choices=choices, value=[c[1] for c in choices][:2]),
            gr.update(choices=res_choices, value=DEFAULT_RES[otype]))


with gr.Blocks(title="LLM Explorer") as demo:
    gr.Markdown("# 🎬 LLM Explorer\n"
                "同一個 prompt、同一個 seed，並排比較多個生成模型。"
                "所有運算都在一台本地 NVIDIA GB10 上完成。")

    qbox = gr.Markdown(queue_text())

    with gr.Row():
        with gr.Column(scale=3):
            prompt = gr.Textbox(label="Prompt", lines=3,
                                placeholder="例：A red fox running through a snowy forest at sunrise, cinematic")
        with gr.Column(scale=1, min_width=140):
            rand_btn = gr.Button("🎲 隨機 Prompt")
            gr.Markdown("<small>建議包含主體、動作、場景、光線、風格。英文效果較佳。</small>")

    with gr.Row():
        otype = gr.Radio([("🎞️ 影片", "video"), ("🖼️ 圖片", "image")],
                         value="video", label="輸出形式")
        resolution = gr.Dropdown([(lbl, val) for val, lbl in RES["video"]],
                                 value=DEFAULT_RES["video"], label="解析度")
        with gr.Column(min_width=180):
            seed = gr.Number(value=lambda: random.randint(0, 2**31), precision=0, label="Seed")
            gr.Markdown("<small>相同 Seed + Prompt = 相同結果</small>")

    models = gr.CheckboxGroup([(lbl, val) for val, lbl in MODELS["video"]],
                              value=["ltx", "h3"],
                              label=f"要比較的模型（最多 {MAX_MODELS} 個）")

    go = gr.Button("▶ 開始生成", variant="primary")
    head = gr.Markdown()

    slots = []
    with gr.Row():
        for _ in range(MAX_MODELS):
            with gr.Column():
                title = gr.Markdown(visible=False)
                vid = gr.Video(visible=False, label=None, autoplay=True, loop=True)
                img = gr.Image(visible=False, label=None, type="filepath")
                slots += [title, vid, img]

    gr.Markdown(
        "---\n"
        "**影片生成很慢**：HD 約 2~5 分鐘一支，FHD 更久，而且主機一次只能跑一個工作。"
        "送出後請保持這個分頁開著——關掉就收不到結果了。"
    )

    otype.change(on_type_change, otype, [models, resolution])
    rand_btn.click(random_prompt, otype, prompt)
    go.click(generate, [prompt, seed, otype, models, resolution], [head, *slots])

    # 佇列狀態每 10 秒自動更新
    gr.Timer(10.0).tick(queue_text, None, qbox)


def _auth_pairs():
    raw = os.environ.get("SPACE_USERS", "").strip()
    pairs = {}
    for item in raw.split(","):
        if ":" in item:
            u, p = item.split(":", 1)
            pairs[u.strip()] = p.strip()
    return pairs


if __name__ == "__main__":
    users = _auth_pairs()
    demo.queue(default_concurrency_limit=1, max_size=20).launch(
        theme=gr.themes.Soft(),
        auth=(lambda u, p: users.get(u) == p) if users else None,
        auth_message="請登入以使用 LLM Explorer" if users else None,
    )
