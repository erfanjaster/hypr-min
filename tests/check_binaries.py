#!/usr/bin/env python3
"""Cross-reference: every external binary referenced by configs and scripts
must be provided by packages install.sh installs (or be a shell/coreutils/
systemd basic). Catches typos and missing-package bugs."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "dotfiles"

# binaries shipped by the packages in install.sh
PROVIDED = {
    "hyprpaper", "waybar", "mako", "hypridle", "hyprlock", "hyprpolkitagent",
    "hyprshutdown", "nm-applet", "wl-paste", "wl-copy", "cliphist", "kitty",
    "fuzzel", "wpctl", "brightnessctl", "playerctl", "pavucontrol",
    "nm-connection-editor", "grim", "slurp", "jq", "notify-send", "hyprctl",
    "hyprlauncher",
}
# always present on any Arch/CachyOS system (coreutils/systemd/shell)
BASIC = {
    "loginctl", "systemctl", "pidof", "date", "mkdir", "echo", "printf",
    "cat", "head", "sh", "bash", "env", "command", "test", "grep", "sed",
    "cp", "mv", "chmod", "mktemp", "rm",
}
SHELL_KEYWORDS = {
    "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "do",
    "done", "in", "function", "local", "exit", "return", "set", "export",
    "shift", "true", "false", "eval", "exec", "SUB", "STR",
    "local", "read", "source",
}

problems = []


def _iter_parts(piece):
    for part in re.split(r"[;|&\n]+|`", piece):
        part = part.strip()
        if not part or part.isdigit():
            continue
        lab = re.match(r"^[\w.*-]+\)\s*(.*)$", part, re.S)   # case label prefix
        if lab:
            part = lab.group(1).strip()
            if not part:
                continue
        if re.fullmatch(r"[\w.*-]+\)", part):
            continue
        yield part


def simple_commands(code: str):
    """Yield the first token of each simple command in shell code."""
    code = re.sub(r"#.*$", "", code, flags=re.M)          # comments
    code = re.sub(r'"[^"]*"', " STR ", code)              # double-quoted
    code = re.sub(r"'[^']*'", " STR ", code)              # single-quoted
    pending = [code]
    while pending:
        piece = pending.pop()
        chunks = []

        def stash(m, _c=chunks):
            _c.append(m.group(1))
            return " SUB "

        piece = re.sub(r"\$\(([^()]*)\)", stash, piece)
        for part in _iter_parts(piece):
            toks = part.split()
            i = 0
            while i < len(toks) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=\S*", toks[i]):
                i += 1                                     # VAR=... prefix
            if i >= len(toks):
                continue
            yield toks[i].strip(chr(39) + chr(34))
        pending.extend(chunks)                             # recurse into $( )


def check_cmd(cmd: str, where: str):
    base = cmd.split("/")[-1]
    if base in PROVIDED or base in BASIC or base in SHELL_KEYWORDS:
        return
    if base.startswith(("$", "-", "{", ">", "<")) or not base:
        return
    if "/scripts/" in cmd and cmd.endswith(".sh"):         # our own script
        name = base
        if not (D / "hypr" / "scripts" / name).exists():
            problems.append(f"{where}: references missing script {name}")
        return
    problems.append(f"{where}: references binary '{cmd}' not provided by install.sh")


# 1. lua exec strings
lua = (D / "hypr" / "hyprland.lua").read_text()
for m in re.finditer(r'(?:hl\.dsp\.)?exec_cmd\(\s*"([^"]+)"', lua):
    for c in simple_commands(m.group(1)):
        check_cmd(c, "hyprland.lua")

# 2. shell scripts
for p in (D / "hypr" / "scripts").glob("*.sh"):
    for c in simple_commands(p.read_text()):
        check_cmd(c, p.name)

# 3. waybar on-* commands
wb = (D / "waybar" / "config").read_text()
for m in re.finditer(r'"on-[\w-]+"\s*:\s*"([^"]+)"', wb):
    for c in simple_commands(m.group(1)):
        check_cmd(c, "waybar/config")

# 4. hypridle / hyprlock command values
for name in ("hypridle.conf", "hyprlock.conf"):
    txt = (D / "hypr" / name).read_text()
    for m in re.finditer(r"^\s*([\w-]+)\s*=\s*(.+)$", txt, re.M):
        key, val = m.group(1), m.group(2).split("#")[0].strip()
        if key in {"lock_cmd", "unlock_cmd", "on_lock_cmd", "on_unlock_cmd",
                   "before_sleep_cmd", "after_sleep_cmd", "on-timeout",
                   "on-resume", "condition_cmd"}:
            for c in simple_commands(val):
                check_cmd(c, name)
        if val.startswith("cmd["):
            for c in simple_commands(val.split("]", 1)[1]):
                check_cmd(c, name)

if problems:
    print("BINARY CROSS-REF FAILED:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("binary cross-ref: OK (all referenced binaries are installed)")
