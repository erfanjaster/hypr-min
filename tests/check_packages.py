#!/usr/bin/env python3
"""Verify every package listed in install.sh exists in official Arch repos
and that hyprland >= 0.56 (Lua config support). Live query to archlinux.org."""
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
src = (ROOT / "install.sh").read_text()

m = re.search(r"PKGS=\((.*?)\)\n", src, re.S)
pkgs = m.group(1).split()
pkgs += ["qt5-wayland"]  # conditional extra

def get(name):
    url = f"https://archlinux.org/packages/search/json/?name={name}"
    req = urllib.request.Request(url, headers={"User-Agent": "hypr-min-tests/1.0"})
    d = json.loads(urllib.request.urlopen(req, timeout=20).read().decode())
    for r in d["results"]:
        if r["pkgname"] == name:
            return r
    return None

missing, versions = [], {}
for p in pkgs:
    r = get(p)
    if r is None:
        missing.append(p)
    else:
        versions[p] = (r["repo"], r["pkgver"])

if missing:
    print("MISSING FROM OFFICIAL REPOS:", missing)
    sys.exit(1)

ver = versions["hyprland"][1]
maj, min_ = (int(x) for x in ver.split(".")[:2])
if (maj, min_) < (0, 56):
    print(f"hyprland {ver} < 0.56 — Lua configs unsupported")
    sys.exit(1)

print(f"all {len(pkgs)} packages found in official repos; hyprland = {ver} (>= 0.56 ✔)")
