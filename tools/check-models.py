#!/usr/bin/env python3
"""
Keep three lists of models in step:

  1. compare/server.py        MODELS   — the cards the comparison tool offers
  2. compare/workflows/*.json          — the weights each card actually loads
  3. comfyui/download-models.sh        — what the downloader can fetch

Drift between them is quiet and expensive: a card with no downloader looks broken
for no stated reason, a downloader with no card wastes tens of gigabytes, and a
workflow pointing at a quantisation the downloader never fetches fails only at
generation time. Run: python3 tools/check-models.py
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WF = ROOT / "compare" / "workflows"
problems = []

# ---- 1. cards the comparison tool offers -----------------------------------
server = (ROOT / "compare" / "server.py").read_text()
m = re.search(r'^MODELS = \[(.*?)\]', server, re.M)
if not m:
    sys.exit("!! could not find MODELS in compare/server.py")
cards = re.findall(r'"([^"]+)"', m.group(1))
print(f"compare/server.py: {len(cards)} cards — {', '.join(cards)}")

# ---- 2. what the downloader can fetch --------------------------------------
dl_src = (ROOT / "comfyui" / "download-models.sh").read_text()
targets = {}
for fn in re.finditer(r'^get_(\w+)\(\)\{(.*?)^\}', dl_src, re.S | re.M):
    targets[fn.group(1)] = set(re.findall(r'dl "[^"]+" "([^"]+\.safetensors)"', fn.group(2)))
# the dispatch decides the public names
dispatch = dict(re.findall(r'^\s{2}(\w+)\)\s+(get_\w+(?:; get_\w+)*)\s*;;', dl_src, re.M))
print(f"download-models.sh: {len(targets)} targets — {', '.join(sorted(targets))}")

def files_for(name):
    """Every file reachable through a dispatch key, following group targets."""
    spec = dispatch.get(name)
    if not spec:
        return None
    out = set()
    for g in spec.split("; "):
        out |= targets.get(g[len("get_"):], set())
    return out

# ---- 3. what each workflow actually loads ----------------------------------
# Only values under inputs: a widget's dropdown also lists files that are merely
# available, and counting those would hide real gaps behind false matches.
def selected(path):
    out = set()
    for node in json.load(open(path)).values():
        if isinstance(node, dict):
            for v in (node.get("inputs") or {}).values():
                if isinstance(v, str) and v.endswith(".safetensors"):
                    out.add(v)
    return out

# cards without a workflow, and workflows without a card
wf_cards = {p.name.split(".")[0] for p in WF.glob("*.json") if not p.name.endswith(".meta.json")}
for c in cards:
    if c not in wf_cards:
        problems.append(f"card '{c}' has no workflow in compare/workflows/ "
                        f"(capture one from ComfyUI, or drop it from MODELS)")
for c in sorted(wf_cards - set(cards)):
    problems.append(f"workflow '{c}' has no card: add it to MODELS in compare/server.py, "
                    f"or delete compare/workflows/{c}.*")

# downloader targets nothing shows
EXTRA_OK = {"h3turbo"}   # serves the h3t8 / h3t4 cards
for t in sorted(set(dispatch) - {"video", "image", "all"}):
    if t not in cards and t not in EXTRA_OK:
        problems.append(f"download target '{t}' has no card in the comparison tool "
                        f"— remove it, or add the card")

# weights a card loads that the downloader cannot fetch
# The h3 card was captured with the Turbo-8 LoRA applied, so it needs h3turbo too.
SERVED_BY = {"h3": ["h3", "h3turbo"],
             "h3t8": ["h3turbo", "h3"], "h3t4": ["h3turbo", "h3"]}
for c in sorted(wf_cards & set(cards)):
    wfp = next(WF.glob(f"{c}.*.json"), None)
    if wfp is None or wfp.name.endswith(".meta.json"):
        wfp = next((p for p in WF.glob(f"{c}.*.json") if not p.name.endswith(".meta.json")), None)
    if wfp is None:
        continue
    have = set()
    for key in SERVED_BY.get(c, [c]):
        have |= files_for(key) or set()
    missing = selected(wfp) - have
    for f in sorted(missing):
        problems.append(f"card '{c}' loads {f}, which no download target fetches")

print()
if problems:
    print(f"!! {len(problems)} inconsistencies:")
    for p in problems:
        print(f"   - {p}")
    sys.exit(1)
print("Models, workflows and download targets agree.")
