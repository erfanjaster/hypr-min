#!/usr/bin/env python3
"""Cross-reference: every external binary referenced by configs and scripts
must be provided by packages install.sh installs, be part of the base system
(coreutils / util-linux / procps / iproute2 / systemd / awk / shell), or be
explicitly optional (probed with `command -v` at run time, e.g. browsers).

Catches typos, missing packages and "works on my machine" scripts.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "dotfiles"

# binaries shipped by the packages in install.sh
PROVIDED = {
    "hyprpaper", "waybar", "mako", "makoctl", "hypridle", "hyprlock",
    "hyprpolkitagent", "hyprshutdown", "nm-applet", "nmcli",
    "nm-connection-editor", "wl-paste", "wl-copy", "cliphist", "kitty",
    "fuzzel", "wpctl", "brightnessctl", "playerctl", "pavucontrol",
    "grim", "slurp", "jq", "notify-send", "hyprctl", "hyprlauncher",
}
# always present on any Arch/CachyOS system (base group + systemd + shell)
BASIC = {
    # systemd / session
    "loginctl", "systemctl", "hostnamectl", "journalctl",
    # coreutils
    "cat", "cp", "cut", "date", "df", "dirname", "echo", "env", "head",
    "ln", "mkdir", "mktemp", "mv", "nproc", "paste", "printf", "readlink",
    "realpath", "rm", "seq", "sleep", "sort", "tail", "tee", "touch", "tr",
    "uname", "uniq", "wc",
    # util-linux / procps / iproute2 / inetutils / findutils / grep / sed / awk
    "column", "setsid", "pgrep", "pkill", "pidof", "ip", "hostname",
    "find", "grep", "sed", "awk", "gawk", "xargs", "which",
    # the package manager itself and privilege escalation
    "pacman", "sudo",
    # shell builtins / keywords / test scaffolding placeholders
    "sh", "bash", "test", "command", "true", "false", "STR", "SUB",
}
SHELL_KEYWORDS = {
    "if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
    "until", "do", "done", "in", "function", "local", "declare", "readonly",
    "exit", "return", "set", "export", "shift", "eval", "exec", "read",
    "source", "trap", "unset", "break", "continue", "select", "time",
    "[", "]", "[[", "]]", "{", "}", "(", ")", "!", ";;", "&",
}
# optional apps: resolved with `command -v` at run time, never required
PROBED = {
    "firefox", "zen-browser", "librewolf", "brave", "chromium", "vivaldi",
    "opera", "microsoft-edge-stable",
    "thunar", "dolphin", "nautilus", "nemo", "pcmanfm", "pcmanfm-qt",
    "code", "codium", "vscodium", "nvim", "vim", "micro", "nano", "helix",
    "paru", "yay", "checkupdates",
}
# a token only counts as a command if it looks like one
CMD_RE = re.compile(r"^[A-Za-z0-9_.][A-Za-z0-9_./+-]*$")

problems = []


def strip_comments(code: str) -> str:
    """Remove # comments without touching quotes or ${var#pattern} expansions.

    A naive `#.*$` regex eats `"${x#prefix}"` and every apostrophe inside a
    comment, which then mis-pairs the quotes of the whole file and hides real
    commands from the audit.
    """
    out = []
    for line in code.split("\n"):
        buf, quote, i = [], None, 0
        while i < len(line):
            ch = line[i]
            if quote:
                buf.append(ch)
                if ch == "\\" and quote == '"' and i + 1 < len(line):
                    buf.append(line[i + 1])
                    i += 2
                    continue
                if ch == quote:
                    quote = None
                i += 1
                continue
            if ch in "\"'":
                quote = ch
                buf.append(ch)
                i += 1
                continue
            if ch == "#" and (not buf or buf[-1] in " \t;|&({<"):
                break                                   # rest of line is a comment
            buf.append(ch)
            i += 1
        out.append("".join(buf))
    return "\n".join(out)


def _iter_parts(piece):
    for part in re.split(r"[;|&\n{}]+|`", piece):
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
    code = strip_comments(code)                           # comments
    # single quotes first: awk/sed programs are single-quoted and routinely
    # contain double quotes of their own, which would otherwise mis-pair
    code = re.sub(r"'[^']*'", " STR ", code)              # single-quoted
    code = re.sub(r'"[^"]*"', " STR ", code)              # double-quoted
    code = re.sub(r"\$\{[^{}]*\}", " STR ", code)          # ${param} expansion
    # a body that starts on the same line as `then`/`else`/`do` still has to be
    # seen, otherwise one-line functions hide every command they run
    code = re.sub(r"\b(then|else|do)\b", "\n", code)
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


FUNC_DEF = re.compile(r"^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*[{(]",
                      re.M)
FUNC_KW = re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)


def shell_functions(code: str) -> set:
    """Names this script defines itself — they are not external binaries."""
    return set(FUNC_DEF.findall(code)) | set(FUNC_KW.findall(code))


def check_cmd(cmd: str, where: str, local_funcs=frozenset()):
    base = cmd.split("/")[-1]
    if not CMD_RE.match(base) or base.isdigit():
        return                                             # punctuation / fd
    if base in PROVIDED or base in BASIC or base in SHELL_KEYWORDS \
            or base in PROBED or base in local_funcs:
        return
    if base.startswith(("$", "-", "{", ">", "<")) or not base:
        return
    if "/scripts/" in cmd and base.endswith(".sh"):        # our own script
        if not (D / "hypr" / "scripts" / base).exists():
            problems.append(f"{where}: references missing script {base}")
        return
    problems.append(f"{where}: references binary '{cmd}' not provided by "
                    f"install.sh (and not base/optional)")


# 1. lua exec strings + spawn_once helpers
lua = (D / "hypr" / "hyprland.lua").read_text()
for m in re.finditer(r'(?:hl\.dsp\.)?exec_cmd\(\s*"([^"]+)"', lua):
    for c in simple_commands(m.group(1)):
        check_cmd(c, "hyprland.lua")
for m in re.finditer(r'spawn_once\(\s*"[^"]+"\s*,\s*"([^"]+)"', lua):
    for c in simple_commands(m.group(1)):
        check_cmd(c, "hyprland.lua (autostart)")

# 2. shell scripts
for p in sorted((D / "hypr" / "scripts").glob("*.sh")):
    src = p.read_text()
    funcs = shell_functions(src)
    for c in simple_commands(src):
        check_cmd(c, p.name, funcs)

# 3. waybar exec / on-* commands
wb = (D / "waybar" / "config").read_text()
for m in re.finditer(r'"(on-[\w-]+|exec|exec-if)"\s*:\s*"([^"]+)"', wb):
    for c in simple_commands(m.group(2)):
        check_cmd(c, f"waybar/config {m.group(1)}")

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
print("binary cross-ref: OK (every referenced binary is installed, base or optional)")
