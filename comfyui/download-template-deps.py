#!/usr/bin/env python3
"""
讀取三個官方 Template，抓出裡面引用、但本機還缺的模型檔（LoRA / upscaler / encoder…），
依照 HuggingFace URL 下載到 ComfyUI/models/ 對應資料夾。
只下缺的，不重複下載已有的。
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMFY = os.path.join(HERE, "ComfyUI")
HF = os.path.join(HERE, "comfyui-env", "bin", "hf")
TPL = os.path.join(HERE, "comfyui-env", "lib", "python3.12",
                   "site-packages", "comfyui_workflow_templates_json", "templates")
TEMPLATES = ["video_ltx2_5_t2v.json", "video_wan2_2_14B_t2v.json", "video_minimax_h3_t2v.json"]
KNOWN_FOLDERS = ("diffusion_models", "text_encoders", "vae", "loras",
                 "latent_upscale_models", "clip_vision", "checkpoints", "unet")

have = set()
for root, _, fs in os.walk(os.path.join(COMFY, "models")):
    for f in fs:
        have.add(f)

# 收集 (repo, repo_path, dest_folder, filename)
jobs = {}
url_re = re.compile(r'https?:/?/?huggingface\.co/([^\s"]+?\.safetensors)')
for t in TEMPLATES:
    s = json.dumps(json.load(open(os.path.join(TPL, t))))
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
        # 決定放到哪個 models 子資料夾
        segs = repo_path.replace("split_files/", "").split("/")
        folder = segs[0] if segs[0] in KNOWN_FOLDERS else "loras"
        jobs[fname] = (repo, repo_path, folder, fname)

if not jobs:
    print(">> 沒有缺少的相依檔，全部已就緒。")
    sys.exit(0)

print(f">> 需要下載 {len(jobs)} 個缺少的相依檔：")
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
        print(f"  ✓ 已存在 {folder}/{fname}"); ok += 1; continue
    print(f">> 下載 {folder}/{fname} …")
    sd = os.path.join(stage, repo.replace("/", "_"))
    r = subprocess.run([HF, "download", repo, "--include", "**/" + fname,
                        "--include", fname, "--local-dir", sd],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("  !! 失敗：" + (r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "unknown"))
        fail += 1; continue
    found = None
    for root, _, fs in os.walk(sd):
        if fname in fs:
            found = os.path.join(root, fname); break
    if found:
        os.replace(found, dest); print(f"  → {folder}/{fname}"); ok += 1
    else:
        print("  !! 下載後找不到檔案"); fail += 1

print(f"\n>> 完成：成功 {ok}，失敗 {fail}")
