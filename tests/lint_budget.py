#!/usr/bin/env python3
"""Static resource budget for hypr-min.

"Minimal" is easy to say and easy to lose: one more tray applet here, one more
1-second poll there, and the desktop that used to idle at 0% CPU does not any
more. This test fails the build when the setup grows beyond its budget.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "dotfiles"
HYPR = D / "hypr"

MAX_RESIDENT = 7          # processes started at login (compositor excluded)
MAX_BLURRED_LAYERS = 2    # blur is the most expensive effect we allow
MAX_CUSTOM_POLLERS = 2    # waybar modules that exec a script on an interval
MIN_LOCK_CMD_MS = 20000   # hyprlock may not spawn a command more often
MIN_BAR_INTERVAL = 5      # nothing in the bar may poll faster than this

errors = []
budget = []


def uncommented(lua: str) -> str:
    return "\n".join(l for l in lua.splitlines()
                     if not l.strip().startswith("--"))


hl = (HYPR / "hyprland.lua").read_text()
live = uncommented(hl)

# 1. resident processes started at login ------------------------------------
autostart = re.findall(r'spawn_once\(\s*"([^"]+)"\s*,\s*"([^"]*)"', live)
budget.append(f"{len(autostart)} resident helpers: "
              + ", ".join(p for p, _ in autostart))
if len(autostart) > MAX_RESIDENT:
    errors.append(f"autostart grew to {len(autostart)} processes "
                  f"(budget {MAX_RESIDENT})")
for proc, cmd in autostart:
    if "pgrep" not in cmd and proc not in cmd:
        errors.append(f"autostart '{cmd}' is not guarded by a pgrep on {proc}")

# 2. no tray applet sneaking back into the autostart path --------------------
if re.search(r"^\s*[^-].*nm-applet", live, re.M):
    errors.append("nm-applet is autostarted again (~50 MB RSS for a tray icon; "
                  "the bar + SUPER+N cover it)")

# 3. compositing cost stays where we put it ---------------------------------
if not re.search(r"shadow\s*=\s*\{\s*enabled\s*=\s*false", live):
    errors.append("window shadows are enabled (a full extra render pass)")
m = re.search(r"blur\s*=\s*\{(.*?)\}", live, re.S)
if m:
    block = m.group(1)
    passes = re.search(r"passes\s*=\s*(\d+)", block)
    size = re.search(r"size\s*=\s*(\d+)", block)
    if passes and int(passes.group(1)) > 1:
        errors.append(f"blur passes = {passes.group(1)} (budget 1)")
    if size and int(size.group(1)) > 6:
        errors.append(f"blur size = {size.group(1)} (budget <= 6)")
    for key in ("special", "popups"):
        if re.search(rf"{key}\s*=\s*true", block):
            errors.append(f"decoration.blur.{key} = true is expensive")
blurred = [c for c in re.findall(r"hl\.layer_rule\((.*?)\)", live, re.S)
           if re.search(r"blur\s*=\s*true", c)]
budget.append(f"{len(blurred)} blurred layer namespaces")
if len(blurred) > MAX_BLURRED_LAYERS:
    errors.append(f"{len(blurred)} blurred layers (budget {MAX_BLURRED_LAYERS})")

# 4. the bar: event-driven or slow, never both busy --------------------------
wb = json.loads((D / "waybar" / "config").read_text())
intervals = {k: v["interval"] for k, v in wb.items()
             if isinstance(v, dict) and "interval" in v}
pollers = [k for k, v in wb.items()
           if isinstance(v, dict) and "exec" in v]
budget.append(f"bar polls: " + ", ".join(f"{k}={v}s" for k, v in sorted(intervals.items())))
for k, v in intervals.items():
    if v < MIN_BAR_INTERVAL:
        errors.append(f"waybar {k} polls every {v}s (budget >= {MIN_BAR_INTERVAL}s)")
if len(pollers) > MAX_CUSTOM_POLLERS:
    errors.append(f"{len(pollers)} waybar modules exec a script "
                  f"(budget {MAX_CUSTOM_POLLERS})")
for k in pollers:
    if intervals.get(k, 0) < 60:
        errors.append(f"waybar {k} execs a script every {intervals.get(k)}s — "
                      f"a fork per update; raise the interval")

# 5. lock screen: no command storms while nobody is watching -----------------
lock = (HYPR / "hyprlock.conf").read_text()
for ms in re.findall(r"cmd\[update:(\d+)\]", lock):
    if int(ms) < MIN_LOCK_CMD_MS:
        errors.append(f"hyprlock runs a command every {ms}ms "
                      f"(budget >= {MIN_LOCK_CMD_MS}ms)")

# 6. scripts: on-demand only, never a loop that keeps a core warm ------------
for p in sorted((HYPR / "scripts").glob("*.sh")):
    src = uncommented(p.read_text())
    if re.search(r"\bsleep\b", src):
        errors.append(f"{p.name} sleeps — a helper must run and exit")
    if re.search(r"while\s+(true|:)", src):
        errors.append(f"{p.name} contains an endless loop")

if errors:
    print("RESOURCE BUDGET EXCEEDED:")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("resource budget: OK")
for b in budget:
    print("  ·", b)
