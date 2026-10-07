#!/usr/bin/env python3
"""Lint hyprlang-style configs (hyprlock.conf, hypridle.conf, hyprpaper.conf).

Checks structural sanity plus a whitelist of categories/keys taken from the
official wiki pages (hyprlock, hypridle, hyprpaper 0.8), and verifies that
dpms control commands use the Hyprland 0.55+ Lua dispatch string form.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
H = ROOT / "dotfiles" / "hypr"

SCHEMA = {
    "hyprlock.conf": {
        "general": {"hide_cursor", "ignore_empty_input", "immediate_render",
                    "text_trim", "fractional_scaling", "screencopy_mode",
                    "fail_timeout"},
        "auth": {"pam:enabled", "pam:module", "fingerprint:enabled",
                 "fingerprint:ready_message", "fingerprint:present_message",
                 "fingerprint:retry_delay"},
        "animations": {"enabled"},
        "background": {"monitor", "path", "color", "blur_passes", "blur_size",
                       "noise", "contrast", "brightness", "vibrancy",
                       "vibrancy_darkness", "reload_time", "reload_cmd",
                       "crossfade_time", "zindex"},
        "label": {"monitor", "text", "text_align", "color", "font_size",
                  "font_family", "rotate", "position", "halign", "valign",
                  "shadow_passes", "shadow_size", "shadow_color",
                  "shadow_boost", "onclick", "zindex"},
        "input-field": {"monitor", "size", "outline_thickness", "dots_size",
                        "dots_spacing", "dots_center", "dots_rounding",
                        "dots_text_format", "outer_color", "inner_color",
                        "font_color", "font_family", "fade_on_empty",
                        "fade_timeout", "placeholder_text", "hide_input",
                        "hide_input_base_color", "rounding", "check_color",
                        "check_text", "fail_color", "fail_text",
                        "capslock_color", "position", "halign", "valign",
                        "shadow_passes", "shadow_size", "shadow_color",
                        "shadow_boost", "zindex", "swap_font_color",
                        "invert_color", "placeholder_color", "fail_transition"},
        "image": {"monitor", "path", "size", "rounding", "border_size",
                  "border_color", "rotate", "reload_time", "reload_cmd",
                  "position", "halign", "valign", "zindex", "shadow_passes",
                  "shadow_size", "shadow_color", "shadow_boost", "onclick"},
        "shape": {"monitor", "size", "color", "rounding", "rotate",
                  "border_size", "border_color", "xray", "position", "halign",
                  "valign", "zindex", "shadow_passes", "shadow_size",
                  "shadow_color", "shadow_boost", "onclick"},
    },
    "hypridle.conf": {
        "general": {"lock_cmd", "unlock_cmd", "on_lock_cmd", "on_unlock_cmd",
                    "before_sleep_cmd", "after_sleep_cmd",
                    "ignore_dbus_inhibit", "ignore_systemd_inhibit",
                    "ignore_wayland_inhibit", "inhibit_sleep"},
        "listener": {"timeout", "on-timeout", "on-resume", "ignore_inhibit",
                     "condition_cmd", "condition_retry"},
    },
    "hyprpaper.conf": {
        "__top__": {"splash", "splash_offset", "splash_opacity", "ipc",
                    "source"},
        "wallpaper": {"monitor", "path", "fit_mode", "timeout", "order",
                      "recursive"},
    },
}

DPMS_OK = re.compile(r"hyprctl dispatch 'hl\.dsp\.dpms\(\{ action = "
                     r"\"(enable|disable)\" \}\)'")
DPMS_OLD = re.compile(r"hyprctl dispatch dpms (on|off)")

errors = []


def strip_comment(line: str) -> str:
    out, in_str = [], False
    for ch in line:
        if ch == '"':
            in_str = not in_str
        if ch == "#" and not in_str:
            break
        out.append(ch)
    return "".join(out).strip()


def lint(path: Path):
    schema = SCHEMA[path.name]
    section = "__top__" if "__top__" in schema else None
    depth = 0
    for lineno, raw in enumerate(path.read_text().splitlines(), 1):
        line = strip_comment(raw)
        if not line:
            continue
        if line.endswith("{"):
            depth += 1
            section = line[:-1].strip()
            if section not in schema:
                errors.append(f"{path.name}:{lineno}: unknown category '{section}'")
            continue
        if line == "}":
            depth -= 1
            section = "__top__" if "__top__" in schema else None
            continue
        m = re.match(r"^([\w:+-]+)\s*=\s*(.*)$", line)
        if not m:
            errors.append(f"{path.name}:{lineno}: not a 'key = value' line: {line!r}")
            continue
        key, val = m.group(1), m.group(2)
        keys = schema.get(section, schema.get("__top__", set()))
        if key not in keys:
            errors.append(f"{path.name}:{lineno}: unknown key '{key}' in [{section}]")
        if DPMS_OLD.search(val):
            errors.append(f"{path.name}:{lineno}: legacy dpms syntax (0.54-); "
                          f"use hyprctl dispatch 'hl.dsp.dpms(...)'")
        if "dpms" in val and not DPMS_OK.search(val):
            errors.append(f"{path.name}:{lineno}: suspicious dpms command: {val}")
    if depth != 0:
        errors.append(f"{path.name}: unbalanced braces (depth {depth})")


def main():
    for name in SCHEMA:
        p = H / name
        if not p.exists():
            errors.append(f"missing {p}")
            continue
        lint(p)
    if errors:
        print("HYPRLANG LINT FAILED:")
        for e in errors:
            print("  -", e)
        sys.exit(1)
    print("hyprlang lint: OK (categories, keys, dpms syntax)")


if __name__ == "__main__":
    main()
