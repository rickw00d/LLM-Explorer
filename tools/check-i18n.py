#!/usr/bin/env python3
"""Consistency checks for the translation tables.

1. every language table has exactly the same keys as English
2. every error_code the server can emit has an "err.<CODE>" entry in the UI table
3. every data-i18n* key used in an HTML page exists in that page's table
4. every inline English default in the markup still matches its table entry

Run from the repository root:  python3 tools/check-i18n.py
"""
import json, re, subprocess, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAIL = []


def tables(js_path):
    """Read the I18N object out of an i18n.js file by evaluating it with node."""
    src = open(js_path, encoding="utf-8").read()
    prog = src + "\nconsole.log(JSON.stringify(I18N));"
    out = subprocess.run(["node", "-e", prog], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def check_parity(name, data):
    base = set(data["en"])
    for lang, table in data.items():
        missing = base - set(table)
        extra = set(table) - base
        if missing:
            FAIL.append(f"{name} [{lang}] missing keys: {sorted(missing)}")
        if extra:
            FAIL.append(f"{name} [{lang}] unknown keys: {sorted(extra)}")
    print(f"{name}: {len(base)} keys x {len(data)} languages")


def check_html(html_path, data):
    html = open(html_path, encoding="utf-8").read()
    used = set(re.findall(r'data-i18n(?:-title|-ph)?="([^"]+)"', html))
    missing = sorted(k for k in used if k not in data["en"])
    if missing:
        FAIL.append(f"{html_path}: keys used in markup but not translated: {missing}")
    print(f"{html_path}: {len(used)} keys used in markup")


def check_inline_defaults(html_path, data):
    """Elements may carry their English text inline so the page still reads without
    JavaScript. applyI18n() overwrites it at runtime, so a default that has drifted
    from the table would only be visible to no-JS visitors — check it here."""
    html = open(html_path, encoding="utf-8").read()
    pairs = re.findall(r'<(\w+)[^>]*?data-i18n="([\w.]+)"[^>]*?>(.*?)</\1>', html, re.S)
    checked = mismatched = 0
    for _tag, key, inline in pairs:
        if not inline.strip():
            continue
        checked += 1
        if inline != data["en"].get(key):
            mismatched += 1
            FAIL.append(f"{html_path}: inline default for \"{key}\" does not match the "
                        f"English string\n      inline: {inline[:70]!r}\n      table:  "
                        f"{str(data['en'].get(key))[:70]!r}")
    print(f"{html_path}: {checked} inline defaults checked, {mismatched} mismatched")


def check_error_codes(py_path, data):
    src = open(py_path, encoding="utf-8").read()
    codes = set(re.findall(r'err\("([A-Z_]+)"', src))
    declared = set(re.findall(r'^\s*"([A-Z_]+)":', src, re.M))
    for code in sorted(codes - declared):
        FAIL.append(f"{py_path}: err(\"{code}\") has no ERROR_TEXT entry")
    for code in sorted(c for c in codes if f"err.{c}" not in data["en"] and c != "NOT_FOUND"):
        FAIL.append(f"{py_path}: err(\"{code}\") has no err.{code} translation")
    print(f"{py_path}: {len(codes)} error codes emitted")


compare = tables(os.path.join(ROOT, "compare/i18n.js"))
check_parity("compare/i18n.js", compare)
check_html(os.path.join(ROOT, "compare/index.html"), compare)
check_error_codes(os.path.join(ROOT, "compare/server.py"), compare)

docs = tables(os.path.join(ROOT, "docs/i18n.js"))
check_parity("docs/i18n.js", docs)
check_html(os.path.join(ROOT, "docs/index.html"), docs)
check_inline_defaults(os.path.join(ROOT, "docs/index.html"), docs)

if FAIL:
    print("\nFAILED:")
    for f in FAIL:
        print("  -", f)
    sys.exit(1)
print("\nAll i18n checks passed.")
