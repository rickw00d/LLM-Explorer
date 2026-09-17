#!/usr/bin/env python3
"""
Model comparison tool — backend (Python standard library only, no dependencies).

Endpoints:
  - serves the comparison page (index.html) from the same origin as ComfyUI (no CORS)
  - /api/import  : upload a workflow exported from ComfyUI via "Save (API Format)";
                   detects which model it is and whether it outputs images or video,
                   and locates the positive-prompt node and the seed nodes.
  - /api/generate: sends the same prompt + seed once to each selected model via ComfyUI /prompt.
  - /api/status  : whether a run has finished, and details of its output files.
  - /api/view    : proxies ComfyUI /view so images/video stream back same-origin.

Run: python3 server.py  (defaults to 127.0.0.1:8890, localhost only)
"""
import json, os, uuid, hmac, urllib.request, urllib.parse, urllib.error, http.server, socketserver, cgi, re

HERE = os.path.dirname(os.path.abspath(__file__))
WF_DIR = os.path.join(HERE, "workflows")
os.makedirs(WF_DIR, exist_ok=True)

COMFY = os.environ.get("COMFY_URL", "http://127.0.0.1:8188")
HOST = os.environ.get("COMPARE_HOST", "127.0.0.1")
PORT = int(os.environ.get("COMPARE_PORT", "8890"))
CLIENT_ID = str(uuid.uuid4())

# ---------- Public mode ----------
# Setting COMPARE_TOKEN switches the server into public mode:
#   1. every /api/* call must carry the X-Compare-Token header
#   2. admin endpoints (they write files / can push arbitrary workflows into ComfyUI) are blocked
#   3. resolution allow-list, queue cap and model-count cap apply
# No token = local mode, behaving exactly as before.
# COMPARE_TOKEN /api/* X-Compare-Token
TOKEN = os.environ.get("COMPARE_TOKEN", "").strip()
PUBLIC = bool(TOKEN)
ADMIN_OK = os.environ.get("COMPARE_ADMIN", "") == "1"
MAX_PENDING = int(os.environ.get("COMPARE_MAX_PENDING", "8"))
MAX_MODELS = int(os.environ.get("COMPARE_MAX_MODELS", "3"))
MAX_PROMPT = int(os.environ.get("COMPARE_MAX_PROMPT", "2000"))

# Resolutions allowed in public mode (2K and above excluded: at high token counts H3
# produces artefacts or runs out of memory)
# 2K H3 token OOM
ALLOWED_RES = {
    "video": {"860x480", "1376x768", "1920x1080"},
    "image": {"1024x1024", "1152x896", "896x1152", "1344x768", "768x1344"},
}

# These endpoints write files or let a caller push an arbitrary workflow into ComfyUI
# (i.e. read/write anywhere on this machine). Blocked in public mode unless COMPARE_ADMIN=1.
# workflow ComfyUI
ADMIN_PATHS = {"/api/import", "/api/savewf", "/api/capture", "/api/uitpl", "/api/stop"}

# ComfyUI's bundled workflow template directory (importable when this server runs in the comfyui venv)
# ComfyUI workflow server comfyui venv import
try:
    import comfyui_workflow_templates_json as _tj
    TPL_DIR = os.path.join(os.path.dirname(_tj.__file__), "templates")
except Exception:
    TPL_DIR = None

MODELS = ["ltx", "h3", "wan", "flux2", "qwen", "hidream"]
MODEL_LABEL = {"ltx": "LTX-2.5", "wan": "Wan 2.2", "h3": "MiniMax H3",
               "flux2": "FLUX.2 Dev", "qwen": "Qwen-Image", "hidream": "HiDream-I1"}
# Identify the model from diffusion_models / encoder filenames (most distinctive first)
# diffusion_models / encoder
SIGNATURES = [
    ("ltx", ["ltx-2.5", "ltx2", "ltx-2", "ltx_"]),
    ("h3",  ["minimax_h3", "minimax", "hailuo", "_h3_"]),
    ("wan", ["wan2.2", "wan2_2", "wan_2.2", "wan_2.1", "umt5", "wan2", "wan_"]),
    ("flux2", ["flux2", "flux_2", "flux.2"]),
    ("qwen", ["qwen_image", "qwen-image", "qwen_2.5_vl"]),
    ("hidream", ["hidream", "hi_dream"]),
]
VIDEO_EXT = (".mp4", ".webm", ".gif", ".mov", ".mkv", ".m4v")

# ---------- error payloads ----------
# Errors carry a stable code plus its parameters so the web UI can render them in
# the viewer's language (see compare/i18n.js). The English `error` sentence stays
# in the payload for clients that do not translate (the Space frontend, curl).
ERROR_TEXT = {
    "UNAUTHORIZED": "Not authorised — check the access token",
    "ENDPOINT_DISABLED": "This endpoint is disabled in public mode",
    "NOT_A_WORKFLOW": "Not a valid workflow",
    "UI_FORMAT": "This is the editor (UI) format; the API format is required",
    "IMPORT_UI_FORMAT": "This is the editor (UI) format. Export it from ComfyUI with "
                        "'Save (API Format)' and upload that file.",
    "UNKNOWN_MODEL": "Could not identify the model",
    "TEMPLATE_DIR_MISSING": "Template directory not found",
    "COMFY_UNREACHABLE": "Cannot reach ComfyUI: {detail}",
    "COMFY_EXEC": "ComfyUI execution error (see the ComfyUI log)",
    "COMFY_STATUS": "ComfyUI returned {code}: {detail}",
    "NOTHING_TO_CAPTURE": "Nothing to capture — open a template in ComfyUI and press Run first",
    "PROMPT_REQUIRED": "Enter a prompt",
    "PROMPT_TOO_LONG": "Prompt too long (max {max} characters)",
    "TOO_MANY_MODELS": "At most {max} models per run",
    "BAD_TYPE": "Unsupported output type: {type}",
    "BAD_RESOLUTION": "Unsupported resolution: {resolution}",
    "QUEUE_FULL": "Queue full ({depth}/{max}), try again later",
    "NO_WORKFLOW": "No \u201c{type}\u201d workflow imported for {label}",
    "NODE_ERROR": "Workflow node error: {detail}",
    "NOT_FOUND": "Not found",
}


def err(code, **params):
    """Build an error payload: stable code + parameters + an English fallback sentence."""
    text = ERROR_TEXT.get(code, code)
    if params:
        try:
            text = text.format(**params)
        except (KeyError, IndexError):
            pass
    return {"error_code": code, "error_params": params, "error": text}

# ---------- ComfyUI HTTP helpers ----------
def comfy_get(path):
    with urllib.request.urlopen(COMFY + path, timeout=30) as r:
        return json.loads(r.read().decode())

def comfy_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(COMFY + path, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())

# ---------- Workflow analysis workflow ----------
def all_string_inputs(graph):
    for n in graph.values():
        for v in (n.get("inputs", {}) or {}).values():
            if isinstance(v, str):
                yield v.lower()

def detect_model(graph):
    blob = "\n".join(all_string_inputs(graph))
    for model, keys in SIGNATURES:
        if any(k in blob for k in keys):
            return model
    return None

def class_types(graph):
    return [str(n.get("class_type", "")).lower() for n in graph.values()]

def detect_type(graph, model):
    cts = class_types(graph)
    joined = " ".join(cts)
    if any(w in joined for w in ("savevideo", "vhs_videocombine", "createvideo",
                                 "savewebm", "saveanimated", "save_video")):
        return "video"
    if "saveimage" in cts or any("saveimage" in c for c in cts):
        # Many frames usually still means video, but be conservative: SaveImage only → image
        return "image"
    # Fallback: LTX / H3 are video models, and Wan defaults to video
    # LTX / H3 Wan
    return "video"

# The positive prompt may live in these input names (in order of preference); negative_* excluded
# input negative_*
POS_KEYS = ("text", "prompt", "positive_prompt", "text_g", "text_l", "value")

def _pos_key(node):
    """Return the node's input name holding the positive prompt, or None.
 input None"""
    ins = node.get("inputs", {}) or {}
    for k in POS_KEYS:
        if isinstance(ins.get(k), str):
            return k
    return None

def trace_to_text(graph, nid, seen):
    nid = str(nid)
    if nid in seen:
        return None
    seen.add(nid)
    node = graph.get(nid)
    if not node:
        return None
    if _pos_key(node):
        return nid
    for v in (node.get("inputs", {}) or {}).values():
        if isinstance(v, list) and len(v) == 2 and isinstance(v[0], (str, int)):
            r = trace_to_text(graph, v[0], seen)
            if r:
                return r
    return None

def find_positive_node(graph):
    # 1) Walk back from the sampler's positive link to the node holding the prompt
    # 1) sampler positive
    for n in graph.values():
        pv = (n.get("inputs", {}) or {}).get("positive")
        if isinstance(pv, list) and pv:
            r = trace_to_text(graph, pv[0], set())
            if r:
                return r
    # 2) Dedicated wrapper nodes whose input is simply prompt / text (skip negative-only ones)
    # 2) input prompt / text negative
    cand = [nid for nid, n in graph.items() if _pos_key(n)]
    # Prefer text-encode / video-wrapper class types whose _meta title has no 'negative'
    # class_type / _meta negative
    def not_negative(nid):
        title = ((graph[nid].get("_meta", {}) or {}).get("title", "") or "").lower()
        return "negativ" not in title
    cand_pos = [c for c in cand if not_negative(c)]
    if len(cand_pos) == 1:
        return cand_pos[0]
    # 3) _meta title contains 'positive' _meta positive
    for nid in cand:
        title = ((graph[nid].get("_meta", {}) or {}).get("title", "") or "").lower()
        if "posit" in title:
            return nid
    if cand_pos:
        return cand_pos[0]
    return cand[0] if cand else None

def inject(graph, prompt, seed, positive_nid, resolution=None):
    ok = False
    if positive_nid and positive_nid in graph:
        key = _pos_key(graph[positive_nid]) or "text"
        graph[positive_nid].setdefault("inputs", {})[key] = prompt
        ok = True
    if not ok:
        for n in graph.values():
            ins = n.get("inputs", {}) or {}
            for k, v in ins.items():
                if isinstance(v, str) and "__PROMPT__" in v:
                    ins[k] = v.replace("__PROMPT__", prompt); ok = True
    # seed: set every literal seed / noise_seed to the given value
    # seed seed / noise_seed
    for n in graph.values():
        ins = n.get("inputs", {}) or {}
        for key in ("seed", "noise_seed"):
            if key in ins and isinstance(ins[key], (int, float)):
                ins[key] = int(seed)
    if resolution:
        w, h = (int(x) for x in resolution.split("x"))
        mp = round(w * h / 1e6, 2)
        for n in graph.values():
            ct = n.get("class_type", "")
            ins = n.get("inputs", {}) or {}
            if ct == "ResolutionSelector":
                ins["megapixels"] = mp
            if ct == "Flux2Scheduler" and "width" in ins and "height" in ins:
                ins["width"] = w
                ins["height"] = h
            if "width" in ins and "height" in ins and isinstance(ins["width"], (int, float)) and isinstance(ins["height"], (int, float)):
                ins["width"] = w
                ins["height"] = h
    return ok

# Temporal down-sampling factor of each model's video VAE (used to estimate token counts).
# h3=4 is cross-checked against the GB10 tuning guide's example (124 frames -> 31,992 tokens);
# the rest are estimates from common values.
# VAE token h3=4
TEMPORAL_DOWNSAMPLE = {"h3": 4, "ltx": 8, "wan": 4}
TEMPORAL_CONFIRMED = {"h3"}

def _safe_eval(expr, names):
    """Evaluate a simple expression limited to arithmetic plus round/max/min/floor/ceil.
 + round/max/min/floor/ceil"""
    import math as _m
    allowed = {"round": round, "max": max, "min": min,
               "floor": _m.floor, "ceil": _m.ceil, "abs": abs}
    allowed.update(names)
    return eval(expr, {"__builtins__": {}}, allowed)  # noqa: S307 - internally generated expression, not user input

def _res_selector_dims(node):
    """Derive width/height from a ResolutionSelector node's megapixels/aspect_ratio/multiple.
 ResolutionSelector"""
    ins = node.get("inputs", {}) or {}
    mp = ins.get("megapixels")
    ar = ins.get("aspect_ratio", "")
    mult = ins.get("multiple", 32)
    if not isinstance(mp, (int, float)) or not isinstance(ar, str):
        return None
    m = re.match(r"\s*(\d+)\s*:\s*(\d+)", ar)
    if not m:
        return None
    rw, rh = int(m.group(1)), int(m.group(2))
    ratio = rw / rh
    h = (mp * 1e6 / ratio) ** 0.5
    w = h * ratio
    w = round(w / mult) * mult
    h = round(h / mult) * mult
    return int(w), int(h)

def resolve_value(graph, val, seen=None):
    """Resolve an input value recursively: literals are returned as-is, links are followed.
 input link"""
    seen = seen or set()
    if isinstance(val, (int, float)):
        return val
    if not (isinstance(val, list) and len(val) == 2):
        return None
    nid, out_idx = str(val[0]), val[1]
    if nid in seen:
        return None
    seen.add(nid)
    node = graph.get(nid)
    if not node:
        return None
    ct = node.get("class_type", "")
    ins = node.get("inputs", {}) or {}
    if ct in ("PrimitiveInt", "PrimitiveFloat"):
        return resolve_value(graph, ins.get("value"), seen)
    if ct == "ResolutionSelector":
        dims = _res_selector_dims(node)
        return dims[out_idx] if dims and out_idx in (0, 1) else None
    if ct == "ComfyMathExpression":
        names = {}
        for k, v in ins.items():
            if k.startswith("values."):
                names[k.split(".", 1)[1]] = resolve_value(graph, v, seen)
        if any(v is None for v in names.values()):
            return None
        try:
            return _safe_eval(ins.get("expression", ""), names)
        except Exception:
            return None
    return None

def estimate_tokens(graph, model):
    """Return {width,height,frames,fps,latent_tokens,temporal_confirmed} or None.
 {width,height,frames,fps,latent_tokens,temporal_confirmed} None"""
    width = height = frames = fps = None
    for n in graph.values():
        ct = n.get("class_type", "")
        ins = n.get("inputs", {}) or {}
        if ct == "ResolutionSelector":
            dims = _res_selector_dims(n)
            if dims: width, height = dims
        if ct in ("EmptyHunyuanLatentVideo", "EmptyLTXVLatentVideo") and "length" in ins:
            if isinstance(ins.get("width"), (int, float)): width = ins["width"]
            if isinstance(ins.get("height"), (int, float)): height = ins["height"]
            f = resolve_value(graph, ins.get("length"))
            if f: frames = f
        if ct == "MiniMaxH3ImageToVideo" and "length" in ins:
            w = resolve_value(graph, ins.get("width")); h = resolve_value(graph, ins.get("height"))
            if w: width = w
            if h: height = h
            f = resolve_value(graph, ins.get("length"))
            if f: frames = f
        if ct == "CreateVideo" and "fps" in ins:
            f2 = resolve_value(graph, ins.get("fps"))
            if f2: fps = f2
    if not (width and height and frames):
        return None
    lw, lh = round(width / 32), round(height / 32)
    factor = TEMPORAL_DOWNSAMPLE.get(model, 4)
    import math as _m
    t_latent = _m.ceil(frames / factor)
    tokens = lw * lh * t_latent
    return {"width": int(width), "height": int(height), "frames": int(frames),
            "fps": fps, "tokens": int(tokens),
            "temporal_confirmed": model in TEMPORAL_CONFIRMED}

def wf_path(model, otype):
    return os.path.join(WF_DIR, f"{model}.{otype}.json")

def meta_path(model, otype):
    return os.path.join(WF_DIR, f"{model}.{otype}.meta.json")

def load_state():
    """Report, per model, whether image/video workflows are imported and which positive node was found.
 image/video +"""
    state = {}
    for m in MODELS:
        state[m] = {"label": MODEL_LABEL[m], "image": None, "video": None}
        for t in ("image", "video"):
            if os.path.exists(wf_path(m, t)):
                meta = {}
                if os.path.exists(meta_path(m, t)):
                    meta = json.load(open(meta_path(m, t)))
                state[m][t] = {"positive_node": meta.get("positive_node"),
                               "prompt_ok": meta.get("prompt_ok", False)}
    return state

NOTE_TYPES = {"Note", "MarkdownNote", "Reroute", "PrimitiveNode"}

def sanitize(graph):
    """Drop nodes without a class_type, or that are notes/decorations — ComfyUI /prompt rejects them.
 class_type /"""
    return {nid: n for nid, n in graph.items()
            if isinstance(n, dict) and n.get("class_type")
            and n["class_type"] not in NOTE_TYPES}

def save_graph(graph):
    """Detect model/type, find the positive node and save. Returns a result dict or {'error':...}.
 /"""
    if not isinstance(graph, dict) or not graph:
        return err("NOT_A_WORKFLOW")
    if "nodes" in graph and "links" in graph:
        return err("UI_FORMAT")
    graph = sanitize(graph)
    model = detect_model(graph)
    if not model:
        return err("UNKNOWN_MODEL")
    otype = detect_type(graph, model)
    pos = find_positive_node(graph)
    json.dump(graph, open(wf_path(model, otype), "w"))
    json.dump({"positive_node": pos, "prompt_ok": bool(pos),
               "model": model, "type": otype}, open(meta_path(model, otype), "w"))
    return {"model": model, "label": MODEL_LABEL[model], "type": otype,
            "positive_node": pos, "prompt_ok": bool(pos), "state": load_state()}

def extract_media(hist_entry):
    media = []
    for o in (hist_entry.get("outputs", {}) or {}).values():
        for val in o.values():
            if isinstance(val, list):
                for item in val:
                    if isinstance(item, dict) and item.get("filename"):
                        fn = item["filename"].lower()
                        kind = "video" if fn.endswith(VIDEO_EXT) else "image"
                        media.append({"filename": item["filename"],
                                      "subfolder": item.get("subfolder", ""),
                                      "type": item.get("type", "output"),
                                      "kind": kind})
    return media

# ---------- HTTP handler ----------
class H(http.server.BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        elif isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def log_message(self, *a):  # quiet
        pass

    def _guard(self, path):
        """Access control for public mode. True means the request was already rejected.
 True return"""
        if not PUBLIC:
            return False
        if path in ADMIN_PATHS and not ADMIN_OK:
            self._send(403, err("ENDPOINT_DISABLED"))
            return True
        if path.startswith("/api/"):
            if not hmac.compare_digest(self.headers.get("X-Compare-Token", ""), TOKEN):
                self._send(401, err("UNAUTHORIZED"))
                return True
        return False

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if self._guard(u.path):
            return
        if u.path in ("/", "/index.html"):
            try:
                html = open(os.path.join(HERE, "index.html"), "rb").read()
            except FileNotFoundError:
                return self._send(404, {"error": "index.html not found"})
            return self._send(200, html, "text/html; charset=utf-8")
        if u.path == "/i18n.js":
            fp = os.path.join(HERE, "i18n.js")
            if os.path.exists(fp):
                return self._send(200, open(fp, "rb").read(),
                                  "application/javascript; charset=utf-8")
            return self._send(404, err("NOT_FOUND"))
        if u.path in ("/hero.png", "/bg.png"):
            fp = os.path.join(HERE, u.path.lstrip("/"))
            if os.path.exists(fp):
                return self._send(200, open(fp, "rb").read(), "image/png")
            return self._send(404, err("NOT_FOUND"))
        if u.path == "/api/models":
            return self._send(200, {"models": load_state(),
                                    "comfy": COMFY,
                                    "order": MODELS,
                                    "labels": MODEL_LABEL})
        if u.path == "/api/queue":
            try:
                qi = comfy_get("/queue")
            except Exception:
                return self._send(200, {"ok": False})
            running = qi.get("queue_running") or []
            pending = qi.get("queue_pending") or []
            return self._send(200, {"ok": True,
                                    "running": len(running),
                                    "pending": len(pending)})
        if u.path == "/api/status":
            q = urllib.parse.parse_qs(u.query)
            pid = q.get("id", [""])[0]
            try:
                hist = comfy_get("/history/" + pid)
            except Exception as e:
                return self._send(200, {"state": "running"})
            entry = hist.get(pid)
            if not entry:
                try:
                    qinfo = comfy_get("/queue")
                    running_ids = {str(t[1]) for t in (qinfo.get("queue_running") or [])}
                    if pid in running_ids:
                        return self._send(200, {"state": "running"})
                except Exception:
                    pass
                return self._send(200, {"state": "queued"})
            st = (entry.get("status", {}) or {})
            if st.get("status_str") == "error":
                payload = err("COMFY_EXEC")
                payload["state"] = "error"
                return self._send(200, payload)
            media = extract_media(entry)
            if media or st.get("completed"):
                vram_gb = None
                try:
                    ss = comfy_get("/system_stats")
                    dev = (ss.get("devices") or [{}])[0]
                    used = dev.get("vram_total", 0) - dev.get("vram_free", 0)
                    vram_gb = round(used / (1024**3), 1)
                except Exception:
                    pass
                return self._send(200, {"state": "done", "media": media, "vram_gb": vram_gb})
            return self._send(200, {"state": "running"})
        if u.path == "/api/uitpl":
            q = urllib.parse.parse_qs(u.query)
            name = os.path.basename(q.get("name", [""])[0])
            if not name.endswith(".json"):
                name += ".json"
            if not TPL_DIR:
                return self._send(500, err("TEMPLATE_DIR_MISSING"))
            p = os.path.join(TPL_DIR, name)
            if not os.path.exists(p):
                return self._send(404, {"error": "no such template"})
            return self._send(200, open(p, "rb").read(), "application/json")
        if u.path == "/api/capture":
            return self.handle_capture()
        if u.path == "/api/view":
            q = urllib.parse.parse_qs(u.query)
            qs = urllib.parse.urlencode({"filename": q.get("filename", [""])[0],
                                         "subfolder": q.get("subfolder", [""])[0],
                                         "type": q.get("type", ["output"])[0]})
            try:
                with urllib.request.urlopen(COMFY + "/view?" + qs, timeout=120) as r:
                    data = r.read()
                    ctype = r.headers.get("Content-Type", "application/octet-stream")
                return self._send(200, data, ctype)
            except Exception as e:
                return self._send(502, {"error": str(e)})
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        if self._guard(u.path):
            return
        if u.path == "/api/import":
            return self.handle_import()
        if u.path == "/api/savewf":
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(length).decode() or "{}")
            graph = body.get("output") or body.get("graph")
            return self._send(200, save_graph(graph))
        if u.path == "/api/generate":
            return self.handle_generate()
        if u.path == "/api/stop":
            return self.handle_stop()
        return self._send(404, {"error": "not found"})

    def handle_stop(self):
        errors = []
        for path, body in [("/interrupt", {}), ("/queue", {"clear": True})]:
            try:
                data = json.dumps(body).encode()
                req = urllib.request.Request(COMFY + path, data=data,
                                             headers={"Content-Type": "application/json"})
                urllib.request.urlopen(req, timeout=10).read()
            except Exception as e:
                errors.append(f"{path}: {e}")
        if errors:
            return self._send(200, {"ok": False, "errors": errors})
        return self._send(200, {"ok": True})

    def handle_import(self):
        ctype = self.headers.get("Content-Type", "")
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        # Accepts multipart (drag & drop) or raw JSON multipart raw json
        graph = None
        if ctype.startswith("multipart/form-data"):
            fs = cgi.FieldStorage(fp=__import__("io").BytesIO(raw), headers=self.headers,
                                  environ={"REQUEST_METHOD": "POST",
                                           "CONTENT_TYPE": ctype})
            if "file" in fs:
                graph = json.loads(fs["file"].file.read().decode())
        else:
            graph = json.loads(raw.decode())
        res = save_graph(graph)
        if "error" in res:
            # An upload in the editor format gets a more specific hint than the
            # generic detection error.
            if res.get("error_code") == "UI_FORMAT":
                res = err("IMPORT_UI_FORMAT")
            return self._send(400, res)
        return self._send(200, res)

    def handle_capture(self):
        """Capture the flattened API workflow from ComfyUI's current /queue (or /history) and save it.
 ComfyUI /queue /history API workflow"""
        try:
            q = comfy_get("/queue")
        except Exception as e:
            return self._send(502, err("COMFY_UNREACHABLE", detail=str(e)))
        graph = None; src = "queue"
        for key in ("queue_running", "queue_pending"):
            for item in q.get(key, []):
                if len(item) >= 3 and isinstance(item[2], dict):
                    graph = item[2]
        if not graph:
            src = "history"
            try:
                h = comfy_get("/history")
            except Exception:
                h = {}
            if h:
                pr = list(h.values())[-1].get("prompt")
                if pr and len(pr) >= 3 and isinstance(pr[2], dict):
                    graph = pr[2]
        if not graph:
            return self._send(404, err("NOTHING_TO_CAPTURE"))
        res = save_graph(graph)
        if src == "queue":  # cancel that run too, so a long video does not keep going
            try:
                comfy_post("/interrupt", {}); comfy_post("/queue", {"clear": True})
            except Exception:
                pass
        res["captured_from"] = src
        return self._send(200 if "error" not in res else 400, res)

    def handle_generate(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length).decode() or "{}")
        prompt = (body.get("prompt") or "").strip()
        seed = int(body.get("seed") or 0)
        otype = body.get("type", "video")
        want = body.get("models") or []
        resolution = body.get("resolution")
        if not prompt:
            return self._send(400, err("PROMPT_REQUIRED"))
        if PUBLIC:
            if len(prompt) > MAX_PROMPT:
                return self._send(400, err("PROMPT_TOO_LONG", max=MAX_PROMPT))
            if len(want) > MAX_MODELS:
                return self._send(400, err("TOO_MANY_MODELS", max=MAX_MODELS))
            if otype not in ALLOWED_RES:
                return self._send(400, err("BAD_TYPE", type=otype))
            if resolution and resolution not in ALLOWED_RES[otype]:
                return self._send(400, err("BAD_RESOLUTION", resolution=resolution))
            try:
                qi = comfy_get("/queue")
                depth = len(qi.get("queue_running") or []) + len(qi.get("queue_pending") or [])
            except Exception:
                depth = 0
            if depth + len(want) > MAX_PENDING:
                return self._send(429, err("QUEUE_FULL", depth=depth, max=MAX_PENDING))
        results = {}
        for m in want:
            p = wf_path(m, otype)
            if not os.path.exists(p):
                results[m] = err("NO_WORKFLOW", type=otype, label=MODEL_LABEL.get(m, m))
                continue
            graph = json.load(open(p))
            meta = json.load(open(meta_path(m, otype))) if os.path.exists(meta_path(m, otype)) else {}
            pos = meta.get("positive_node") or find_positive_node(graph)
            ok = inject(graph, prompt, seed, pos, resolution)
            tok_info = estimate_tokens(graph, m) if otype == "video" else None
            try:
                resp = comfy_post("/prompt", {"prompt": graph, "client_id": CLIENT_ID})
                if resp.get("node_errors"):
                    results[m] = err("NODE_ERROR", detail=json.dumps(resp["node_errors"])[:200])
                else:
                    results[m] = {"prompt_id": resp.get("prompt_id"), "prompt_injected": ok, "tokens": tok_info}
            except urllib.error.HTTPError as e:
                results[m] = err("COMFY_STATUS", code=e.code, detail=e.read().decode()[:200])
            except Exception as e:
                results[m] = err("COMFY_UNREACHABLE", detail=str(e))
        return self._send(200, {"results": results, "seed": seed})


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


if __name__ == "__main__":
    print(f">> Model comparison tool: http://{HOST}:{PORT}")
    print(f">> ComfyUI backend: {COMFY}")
    if PUBLIC:
        print(">> Mode: public — X-Compare-Token required")
        print(f">>   admin endpoints: {'open (COMPARE_ADMIN=1)' if ADMIN_OK else 'blocked'}")
        print(f">>   queue cap {MAX_PENDING} · models {MAX_MODELS} · prompt {MAX_PROMPT} chars")
    else:
        print(">> Mode: local — no authentication, do not expose")
    Server((HOST, PORT), H).serve_forever()
