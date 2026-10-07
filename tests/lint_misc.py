#!/usr/bin/env python3
"""Validate waybar (JSON+CSS), fuzzel.ini and mako config for hypr-min."""
import configparser
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "dotfiles"

errors = []

# ---- waybar config (strict JSON) -------------------------------------------
wb_path = D / "waybar" / "config"
try:
    wb = json.loads(wb_path.read_text())
except Exception as e:  # noqa: BLE001
    errors.append(f"waybar config: invalid JSON: {e}")
    wb = {}

if wb:
    mods = set(wb.get("modules-left", []) + wb.get("modules-center", [])
               + wb.get("modules-right", []))
    for m in mods:
        if m not in wb:
            errors.append(f"waybar: module '{m}' listed but not configured")
    for key in wb:
        if "/" in key or key.startswith("custom/"):
            if key not in mods:
                errors.append(f"waybar: configured module '{key}' never used")
    # every on-click/on-scroll command's first binary must be known
    KNOWN = {"nm-connection-editor", "pavucontrol", "hyprctl", "playerctl",
             "wpctl", "brightnessctl"}
    for key, val in wb.items():
        if isinstance(val, dict):
            for k2, v2 in val.items():
                if k2.startswith("on-") and isinstance(v2, str):
                    first = v2.split()[0].strip('"')
                    if "/hypr/scripts/" in v2 or first.startswith("$HOME"):
                        base = first.split("/")[-1]
                        if not (D / "hypr" / "scripts" / base).exists():
                            errors.append(f"waybar: {key}.{k2} references "
                                          f"missing script {base}")
                        continue
                    if first not in KNOWN:
                        errors.append(f"waybar: {key}.{k2} runs unknown binary "
                                      f"'{first}'")
    # battery module: if present it must be configured, and vice versa
    if "battery" in wb and "battery" not in mods:
        errors.append("waybar: battery configured but not in module list")

# ---- waybar CSS --------------------------------------------------------------
css = (D / "waybar" / "style.css").read_text()
if css.count("{") != css.count("}"):
    errors.append("waybar style.css: unbalanced braces")
# every #id selector must map to a module in use (or waybar/tooltip)
valid_ids = {"waybar", "tooltip"} | {m.replace("/", "-").replace("custom-", "custom-")
                                     for m in mods}
for sel in re.findall(r"^#([\w-]+)", css, re.M):
    ok = sel in valid_ids or any(sel.startswith(v) for v in valid_ids)
    if not ok and not sel.startswith(("workspaces", "window", "tray", "network",
                                      "pulseaudio", "battery", "clock",
                                      "custom-power")):
        errors.append(f"waybar style.css: selector #{sel} matches no module")

# ---- fuzzel.ini ---------------------------------------------------------------
fz = configparser.ConfigParser(strict=False)
fz.read(D / "fuzzel" / "fuzzel.ini")
FUZZEL_KEYS = {
    "main": {"font", "prompt", "icon-theme", "icons-enabled", "lines",
             "columns", "width", "horizontal-pad", "inner-pad", "line-height",
             "letter-spacing", "layer", "exit-on-keyboard-focus-loss",
             "terminal", "dpi-aware", "show-actions", "tabs"},
    "border": {"width", "radius", "color"},
    "colors": {"background", "text", "match", "selection", "selection-text",
               "selection-match", "border", "placeholder", "title",
               "custom", "input-line"},
    "key-bindings": {"cancel", "execute", "execute-or-next", "cursor-left",
                     "cursor-right", "delete-prev", "delete-next", "prev",
                     "next"},
}
for sec in fz.sections():
    if sec not in FUZZEL_KEYS:
        errors.append(f"fuzzel.ini: unknown section [{sec}]")
        continue
    for k, _ in fz.items(sec):
        if k not in FUZZEL_KEYS[sec]:
            errors.append(f"fuzzel.ini: unknown key '{k}' in [{sec}]")
for c in fz.get("colors", "background", fallback=""), \
         fz.get("colors", "text", fallback=""):
    if not re.fullmatch(r"[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", c):
        errors.append(f"fuzzel.ini: bad color '{c}' (need RRGGBB[AA])")

# ---- mako config --------------------------------------------------------------
mk = (D / "mako" / "config").read_text()
MAKO_KEYS = {"font", "background-color", "text-color", "border-color",
             "border-size", "border-radius", "padding", "margin", "width",
             "height", "max-visible", "default-timeout", "ignore-timeout",
             "layer", "anchor", "actions", "markup", "icon-path",
             "max-icon-size", "progress-color", "group-by", "sort",
             "output", "format"}
for lineno, raw in enumerate(mk.splitlines(), 1):
    stripped = raw.strip()
    if not stripped or stripped.startswith("#"):
        continue
    line = stripped
    if line.startswith("["):
        if line and not re.fullmatch(r"\[(urgency|category|app-name|desktop-entry)=.*\]", line):
            errors.append(f"mako config:{lineno}: bad section header '{line}'")
        continue
    m = re.match(r"^([\w-]+)\s*=\s*(.*)$", line)
    if not m:
        errors.append(f"mako config:{lineno}: bad line '{line}'")
        continue
    if m.group(1) not in MAKO_KEYS:
        errors.append(f"mako config:{lineno}: unknown key '{m.group(1)}'")
    if m.group(1).endswith("color") or m.group(1) in {"border-color",
                                                      "background-color",
                                                      "text-color"}:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", m.group(2)):
            errors.append(f"mako config:{lineno}: bad color '{m.group(2)}'")

if errors:
    print("MISC LINT FAILED:")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("misc lint: OK (waybar JSON/CSS, fuzzel.ini, mako config)")
