#!/usr/bin/env python3
"""Build termanim.kwinscript, the package to upload to store.kde.org (KWin Scripts category)."""
import json, os, zipfile

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
src = os.path.join(root, "kwin-script")
version = json.load(open(os.path.join(src, "metadata.json")))["KPlugin"]["Version"]
out = os.path.join(root, "dist", f"termanim-{version}.kwinscript")
os.makedirs(os.path.dirname(out), exist_ok=True)

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _dirs, files in os.walk(src):
        for name in sorted(files):
            path = os.path.join(folder, name)
            z.write(path, os.path.relpath(path, src))
print(out)
