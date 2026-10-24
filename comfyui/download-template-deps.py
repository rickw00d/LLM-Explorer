#!/usr/bin/env python3
"""
Read the three official templates, find the model files they reference that are not
on this machine yet (LoRAs, upscalers, encoders and so on), and download them from
their HuggingFace URLs into the matching ComfyUI/models/ folder.

Only what is missing is fetched; anything already present is left alone.
"""
import glob, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMFY = os.path.join(HERE, "ComfyUI")
HF = os.path.join(HERE, "comfyui-env", "bin", "hf")

# The templates live under the venv's site-packages. Glob the Python version rather
# than hard-coding it, so a venv built on a different minor release still works.
_tpl = sorted(glob.glob(os.path.join(
    HERE, "comfyui-env", "lib", "python3.*", "site-packages",
    "comfyui_workflow_templates_json", "templates")))
if not _tpl:
    sys.exit("!! workflow templates not found — is the ComfyUI venv set up? Run ./setup.sh")
TPL = _tpl[-1]

TEMPLATES = ["video_ltx2_5_t2v.json", "video_wan2_2_14B_t2v.json", "video_minimax_h3_t2v.json"]
KNOWN_FOLDERS = ("diffusion_models", "text_encoders", "vae", "loras",
                 "latent_upscale_models", "clip_vision", "checkpoints", "unet")

have = set()
for root, _, fs in os.walk(os.path.join(COMFY, "models")):
    for f in fs:
        have.add(f)

# Collect (repo, repo_path, dest_folder, filename)
jobs = {}
url_re = re.compile(r'https?:/?/?huggingface\.co/([^\s"]+?\.safetensors)')
for t in TEMPLATES:
    path = os.path.join(TPL, t)
    if not os.path.exists(path):
        print(f"  !! template not found, skipping: {t}")
        continue
    s = json.dumps(json.load(open(path)))
    for m in url_re.finditer(s):
        full = m.group(1)                      # e.g. Comfy-Org/Wan.../resolve/main/split_files/loras/xxx.safetensors
        parts = full.split("/resolve/main/")
        if len(parts) != 2:
            continue
        repo = parts[0]
        repo_path = parts[1]
        fname = repo_path.split("/")[-1]
        if fname in have:
            continue
        # Work out which models subfolder it belongs in
        segs = repo_path.replace("split_files/", "").split("/")
        folder = segs[0] if segs[0] in KNOWN_FOLDERS else "loras"
        jobs[fname] = (repo, repo_path, folder, fname)

if not jobs:
    print(">> Nothing missing — all template dependencies are already in place.")
    sys.exit(0)

print(f">> {len(jobs)} missing dependencies to download:")
for repo, rp, folder, fname in jobs.values():
    print(f"   [{folder}] {fname}  ←  {repo}")

os.environ["HF_XET_HIGH_PERFORMANCE"] = "1"
stage = os.path.join(HERE, ".hf-stage")
ok = fail = 0
for repo, repo_path, folder, fname in jobs.values():
    dest_dir = os.path.join(COMFY, "models", folder)
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, fname)
    if os.path.exists(dest):
        print(f"  ✓ already present: {folder}/{fname}"); ok += 1; continue
    print(f">> downloading {folder}/{fname} …")
    sd = os.path.join(stage, repo.replace("/", "_"))
    r = subprocess.run([HF, "download", repo, "--include", "**/" + fname,
                        "--include", fname, "--local-dir", sd],
                       capture_output=True, text=True)
    if r.returncode != 0:
        err = r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "unknown error"
        print(f"  !! failed: {err}")
        if re.search(r"access denied|requires approval|gated", err, re.I):
            print(f"     {repo} is gated — accept its licence at https://huggingface.co/{repo}")
        fail += 1; continue
    found = None
    for root, _, fs in os.walk(sd):
        if fname in fs:
            found = os.path.join(root, fname); break
    if found:
        os.replace(found, dest); print(f"  → {folder}/{fname}"); ok += 1
    else:
        print("  !! downloaded, but the file was not found in the staging dir"); fail += 1

print(f"\n>> Done: {ok} succeeded, {fail} failed")
