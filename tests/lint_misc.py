#!/usr/bin/env python3
"""Validate waybar (JSON+CSS), fuzzel.ini and mako config for hypr-min.

On top of "does it parse", this enforces the two things that quietly ruin a
minimal setup: modules that are configured but never shown, and poll intervals
so tight that the bar becomes the busiest process on the desktop.
"""
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

# binaries a bar module may launch directly (anything else must be one of our
# own scripts, so that install.sh stays the single source of installed tools)
KNOWN_CMD = {"nm-connection-editor", "pavucontrol", "hyprctl", "playerctl",
             "wpctl", "brightnessctl", "makoctl", "notify-send"}
MIN_INTERVAL = 5          # seconds: nothing in the bar may poll faster
GROUP_ORIENTATIONS = {"horizontal", "vertical", "inherit", "orthogonal"}


def css_id(module: str) -> str:
    """waybar's CSS name for a module: custom/x -> custom-x, a/b -> b."""
    if module.startswith("custom/"):
        return "custom-" + module.split("/", 1)[1]
    if "/" in module:
        return module.split("/", 1)[1]
    return module


def check_cmd(where: str, key: str, value: str):
    if not isinstance(value, str) or not value.strip():
        return
    first = value.split()[0].strip('"')
    if "/hypr/scripts/" in value or first.startswith("$HOME"):
        base = first.split("/")[-1]
        if not (D / "hypr" / "scripts" / base).exists():
            errors.append(f"waybar: {where}.{key} references missing script {base}")
        return
    if first.split("/")[-1] not in KNOWN_CMD:
        errors.append(f"waybar: {where}.{key} runs unknown binary '{first}' "
                      f"(add it to install.sh or use a script)")


shown: list[str] = []
if wb:
    listed = (wb.get("modules-left", []) + wb.get("modules-center", [])
              + wb.get("modules-right", []))
    grouped = []
    for name, cfg in wb.items():
        if name.startswith("group/") and isinstance(cfg, dict):
            mods = cfg.get("modules", [])
            if not mods:
                errors.append(f"waybar: {name} has no modules")
            orient = cfg.get("orientation", "orthogonal")
            if orient not in GROUP_ORIENTATIONS:
                errors.append(f"waybar: {name} bad orientation '{orient}'")
            grouped += mods

    shown = set(listed) | set(grouped)

    # every listed/grouped module must have a configuration block
    for m in shown:
        if m not in wb:
            errors.append(f"waybar: module '{m}' is shown but not configured")
    # every namespaced module that is configured must actually be shown
    for key in wb:
        if "/" in key and key not in shown:
            errors.append(f"waybar: configured module '{key}' is never shown")
    # a module may not appear twice
    for m in set(listed):
        if listed.count(m) + grouped.count(m) > 1:
            errors.append(f"waybar: module '{m}' is listed more than once")

    for key, val in wb.items():
        if not isinstance(val, dict):
            continue
        for k2, v2 in val.items():
            if (k2.startswith("on-") or k2 in {"exec", "exec-if"}) \
                    and isinstance(v2, str):
                check_cmd(key, k2, v2)
            if k2 == "interval":
                if not isinstance(v2, (int, float)):
                    errors.append(f"waybar: {key}.interval must be a number")
                elif v2 < MIN_INTERVAL:
                    errors.append(f"waybar: {key}.interval={v2}s polls too "
                                  f"hard (minimum {MIN_INTERVAL}s)")
        # custom modules that exec must say how often they run
        if key.startswith("custom/") and "exec" in val \
                and "interval" not in val and "signal" not in val:
            errors.append(f"waybar: {key} execs without interval/signal "
                          f"(it would respawn in a tight loop)")

# ---- waybar CSS --------------------------------------------------------------
css = (D / "waybar" / "style.css").read_text()
if css.count("{") != css.count("}"):
    errors.append("waybar style.css: unbalanced braces")

valid_ids = {"waybar", "tooltip"} | {css_id(m) for m in shown}
# only look at selectors: strip comments and declaration bodies first, so that
# hex colours (#e6b450) are not mistaken for widget names
selectors = re.sub(r"\{[^{}]*\}", "", re.sub(r"/\*.*?\*/", "", css, flags=re.S))
for sel in set(re.findall(r"#([\w-]+)", selectors)):
    if sel not in valid_ids:
        errors.append(f"waybar style.css: selector #{sel} matches no module "
                      f"(known: {', '.join(sorted(valid_ids))})")

# ---- fuzzel.ini ---------------------------------------------------------------
fz = configparser.ConfigParser(strict=False)
fz.read(D / "fuzzel" / "fuzzel.ini")
FUZZEL_KEYS = {
    "main": {"font", "prompt", "icon-theme", "icons-enabled", "lines",
             "columns", "width", "horizontal-pad", "inner-pad", "line-height",
             "letter-spacing", "layer", "exit-on-keyboard-focus-loss",
             "terminal", "dpi-aware", "show-actions", "tabs", "placeholder",
             "password-character", "filter-desktop", "launch-prefix"},
    "border": {"width", "radius", "color"},
    "colors": {"background", "text", "match", "selection", "selection-text",
               "selection-match", "border", "placeholder", "title",
               "custom", "input-line"},
    "key-bindings": {"cancel", "execute", "execute-or-next", "cursor-left",
                     "cursor-right", "delete-prev", "delete-next", "prev",
                     "next", "prev-page", "next-page", "first", "last"},
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
             "height", "max-visible", "max-history", "default-timeout",
             "ignore-timeout", "layer", "anchor", "actions", "markup",
             "icon-path", "max-icon-size", "progress-color", "group-by",
             "sort", "output", "format", "history", "text-alignment",
             "default-anchor", "invisible", "icon-location"}
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
print(f"misc lint: OK (waybar JSON/CSS with {len(shown) if wb else 0} modules, "
      f"fuzzel.ini, mako config)")
