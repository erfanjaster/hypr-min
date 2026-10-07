#!/usr/bin/env python3
"""Keybind & script hygiene for hypr-min.

The whole point of `description = "…"` on every bind is that SUPER+/ can build
a complete cheat sheet straight from the running compositor — so a bind without
one is a bug, not a style choice. Also checks that submaps referenced actually
exist, that every script we dispatch is shipped, and that those scripts are
written defensively.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HYPR = ROOT / "dotfiles" / "hypr"
SCRIPTS = HYPR / "scripts"

errors = []
notes = []


def strip_lua_comments(code: str) -> str:
    """Drop -- comments and /* */-style block comments, keeping strings intact."""
    out, i, n = [], 0, len(code)
    quote = None
    while i < n:
        ch = code[i]
        if quote:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(code[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in "\"'":
            quote = ch
            out.append(ch)
            i += 1
            continue
        if code.startswith("--[[", i):
            end = code.find("]]", i)
            i = n if end < 0 else end + 2
            out.append(" ")
            continue
        if code.startswith("--", i):
            end = code.find("\n", i)
            i = n if end < 0 else end
            out.append(" ")
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def calls(code: str, name: str):
    """Yield the full source text of every `name(...)` call, balanced."""
    for m in re.finditer(re.escape(name) + r"\s*\(", code):
        i = m.end()
        depth = 1
        quote = None
        while i < len(code) and depth:
            ch = code[i]
            if quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif ch in "\"'":
                quote = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            i += 1
        yield code[m.end():i - 1]


def line_of(code: str, pos: int) -> int:
    return code.count("\n", 0, pos) + 1


total_binds = 0
for path in (HYPR / "hyprland.lua", HYPR / "user.lua"):
    raw = path.read_text()
    code = strip_lua_comments(raw)

    # 1. every bind must be documented -> the live cheat sheet stays complete
    for m in re.finditer(r"hl\.bind\s*\(", code):
        total_binds += 1
    for body in calls(code, "hl.bind"):
        if "description" not in body:
            first = body.strip().splitlines()[0][:60] if body.strip() else "?"
            errors.append(f"{path.name}: hl.bind({first}…) has no description "
                          f"— it will be missing from SUPER+/")

    # 2. submaps that are entered must be defined (and vice versa)
    defined = set(re.findall(r'hl\.define_submap\s*\(\s*"([^"]+)"', code))
    entered = set(re.findall(r'hl\.dsp\.submap\s*\(\s*"([^"]+)"', code)) - {"reset"}
    for s in sorted(entered - defined):
        errors.append(f"{path.name}: enters submap '{s}' which is never defined")
    for s in sorted(defined - entered):
        notes.append(f"{path.name}: submap '{s}' is defined but never entered")

    # 3. no legacy hyprlang syntax creeping back in
    for pat, what in ((r"\bbind\s*=\s*", "hyprlang bind= directive"),
                      (r"\bbindm\s*=", "hyprlang bindm= directive"),
                      (r"hyprctl dispatch\s+(?!')\w", "legacy hyprctl dispatch "
                                                      "(0.54 syntax)")):
        for m in re.finditer(pat, code):
            errors.append(f"{path.name}:{line_of(code, m.start())}: {what}")

# 3b. the README must document every user-facing bind description
readme = (ROOT / "README.md").read_text()


def norm(text: str) -> str:
    text = re.sub(r"[0-9]+", "n", text.lower())
    return re.sub(r"\s+", " ", text)


readme_norm = norm(readme)
documented, undocumented = 0, []
for path in (HYPR / "hyprland.lua",):
    code = strip_lua_comments(path.read_text())
    for body in calls(code, "hl.bind"):
        for m in re.finditer(r'description\s*=\s*"([^"]+)"', body):
            desc = m.group(1).strip()
            if desc.startswith("["):        # submap internals: listed as a table
                continue
            documented += 1
            if norm(desc) not in readme_norm:
                undocumented.append(desc)
for desc in undocumented:
    errors.append(f"README.md does not document the bind '{desc}'")
if undocumented:
    notes.append(f"{documented - len(undocumented)}/{documented} bind "
                 f"descriptions are in README.md")

# 4. every script the config dispatches must exist
referenced = set()
for path in (HYPR / "hyprland.lua", HYPR / "user.lua"):
    code = strip_lua_comments(path.read_text())
    referenced |= set(re.findall(r'SCRIPTS\s*\.\.\s*"/([\w.-]+\.sh)', code))
    referenced |= set(re.findall(r'script\s*\(\s*"([\w.-]+\.sh)"', code))
shipped = {p.name for p in SCRIPTS.glob("*.sh")}
for name in sorted(referenced - shipped):
    errors.append(f"config dispatches missing script: {name}")
for name in sorted(shipped - referenced):
    notes.append(f"script {name} is never bound (ok if the bar or a menu uses it)")

# 5. scripts: executable, bash, strict mode
for p in sorted(SCRIPTS.glob("*.sh")):
    src = p.read_text()
    if not src.startswith("#!/usr/bin/env bash"):
        errors.append(f"{p.name}: missing '#!/usr/bin/env bash' shebang")
    if "set -euo pipefail" not in src:
        errors.append(f"{p.name}: missing 'set -euo pipefail'")
    if not p.stat().st_mode & 0o111:
        errors.append(f"{p.name}: not executable in the repo")

# 6. waybar commands must point at shipped scripts too
wb = (ROOT / "dotfiles" / "waybar" / "config").read_text()
for m in re.finditer(r'hypr/scripts/([\w.-]+\.sh)', wb):
    if m.group(1) not in shipped:
        errors.append(f"waybar/config references missing script {m.group(1)}")

if errors:
    print("BIND/SCRIPT LINT FAILED:")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print(f"bind lint: OK ({total_binds} binds, all described; "
      f"{documented} of them documented in README.md; "
      f"{len(referenced)} scripts wired up)")
for n in notes:
    print("  · note:", n)
