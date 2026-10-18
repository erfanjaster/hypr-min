#!/usr/bin/env python3
"""Verify every Arch package listed in install.sh exists in official Arch repos
and that hyprland >= 0.56 (Lua config support). Live query to archlinux.org.

The Debian list is cross-checked against a pinned snapshot of the trixie
package index (tests/debian_packages.txt) — no network needed."""
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
src = (ROOT / "install.sh").read_text()

m = re.search(r"PKGS_ARCH=\((.*?)\)\n", src, re.S)
pkgs = m.group(1).split()
pkgs += ["qt5-wayland"]  # conditional extra

# Debian list: cross-checked offline against a pinned trixie snapshot below.
def check_debian():
    """Every name in PKGS_DEBIAN must exist in the pinned trixie snapshot."""
    mdeb = re.search(r"PKGS_DEBIAN=\((.*?)\)\n", src, re.S)
    if not mdeb:
        print("FAIL: PKGS_DEBIAN array not found in install.sh")
        return False
    deb_pkgs = mdeb.group(1).split()
    snap = (ROOT / "tests" / "debian_packages.txt").read_text().split()
    known = set(snap)
    missing = [p for p in deb_pkgs if p not in known]
    if missing:
        print("FAIL: unknown Debian (trixie) packages: " + " ".join(missing))
        return False
    print(f"Debian check: OK ({len(deb_pkgs)} packages present in trixie)")
    return True


if len(sys.argv) > 1 and sys.argv[1] == "--debian":
    sys.exit(0 if check_debian() else 1)

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
