#!/usr/bin/env bash
# ============================================================================
#  hypr-min test suite — 8 complete tests
#  Usage: ./tests/run_tests.sh     (writes tests/RESULTS.md)
# ============================================================================
set -u

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/tests/RESULTS.md"
PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

start() { echo; echo "── TEST $1: $2"; echo "## TEST $1 — $2" >> "$OUT"; }
ok()    { PASS=$((PASS+1)); echo "   ✔ $1"; echo "- ✔ $1" >> "$OUT"; }
bad()   { FAIL=$((FAIL+1)); echo "   ✘ $1"; echo "- ✘ $1" >> "$OUT"; }
check() { # check <desc> <cmd...>
    local d="$1"; shift
    if "$@" >>"$TMP/last.log" 2>&1; then ok "$d"; else bad "$d (see log below)"; sed 's/^/     | /' "$TMP/last.log" | tail -5; fi
}

: > "$OUT"
echo "# hypr-min test results — $(date -u +%Y-%m-%dT%H:%MZ)" >> "$OUT"

# ══════════════════════════ TEST 1: shell static analysis ══════════════════
start 1 "shell static analysis (bash -n + shellcheck)"
for f in "$ROOT/install.sh" "$ROOT"/dotfiles/hypr/scripts/*.sh; do
    check "bash -n $(basename "$f")" bash -n "$f"
    check "shellcheck $(basename "$f")" shellcheck -S warning "$f"
done

# ══════════════════════════ TEST 2: lua syntax + API audit ═════════════════
start 2 "Lua config: syntax parse + API surface audit"
check "luac -p hyprland.lua"  luac5.4 -p "$ROOT/dotfiles/hypr/hyprland.lua"
check "luac -p user.lua"      luac5.4 -p "$ROOT/dotfiles/hypr/user.lua"
check "execute hyprland.lua against stub hl API" lua5.4 "$ROOT/tests/lua_stub_test.lua" "$ROOT/dotfiles/hypr/hyprland.lua"
check "execute user.lua against stub hl API"     lua5.4 "$ROOT/tests/lua_stub_test.lua" "$ROOT/dotfiles/hypr/user.lua"
MISSING_SCRIPTS="$(grep -oE 'SCRIPTS \.\. "/[a-zA-Z0-9./_-]+"' "$ROOT/dotfiles/hypr/hyprland.lua" | sed 's|^.*/||; s|"||g' | while read -r n; do [ -f "$ROOT/dotfiles/hypr/scripts/$n" ] || echo "$n"; done)"
if [[ -z "$MISSING_SCRIPTS" ]]; then ok "all scripts referenced by binds exist"; else bad "missing scripts: $MISSING_SCRIPTS"; fi
check "user.lua require is pcall-protected" grep -q 'pcall(require, "user")' "$ROOT/dotfiles/hypr/hyprland.lua"

# ══════════════════════════ TEST 3: hyprlang configs ═══════════════════════
start 3 "hyprlang configs (hyprlock/hypridle/hyprpaper): schema + dpms syntax"
check "hyprlang lint" python3 "$ROOT/tests/lint_hyprlang.py"

# ══════════════════════════ TEST 4: waybar/fuzzel/mako ═════════════════════
start 4 "waybar JSON+CSS, fuzzel.ini, mako config validation"
check "misc lint" python3 "$ROOT/tests/lint_misc.py"

# ══════════════════════════ TEST 5: packages exist upstream ════════════════
start 5 "every package in install.sh exists in the official Arch repos"
check "package availability (live archlinux.org API)" python3 "$ROOT/tests/check_packages.py"

# ══════════════════════════ TEST 6: installer end-to-end ═══════════════════
start 6 "installer end-to-end simulation (desktop + laptop + update safety)"

make_shims() { # $1 = bindir, $2 = logfile
    mkdir -p "$1"
    cat > "$1/pacman" <<EOF
#!/bin/sh
case "\$1" in
  -Qq) shift; case "\$1" in kitty|grim|polkit) exit 0 ;; *) exit 1 ;; esac ;;
  -S)  echo "PACMAN-INSTALL: \$*" >> "$2"; exit 0 ;;
esac
exit 0
EOF
    cat > "$1/sudo" <<'EOF'
#!/bin/sh
exec "$@"
EOF
    cat > "$1/ls" <<EOF
#!/bin/sh
for a in "\$@"; do
  case "\$a" in
    /sys/class/power_supply/BAT*) [ "\${FAKE_BATTERY:-0}" = "1" ] && exit 0 || exit 2 ;;
  esac
done
exec /bin/ls "\$@"
EOF
    chmod +x "$1"/*
}

run_install() { # $1 = fakehome, $2 = bindir, $3 = logfile, $4 = battery
    mkdir -p "$1"
    HOME="$1" XDG_CONFIG_HOME="$1/.config" SHIM_LOG="$3" FAKE_BATTERY="$4" \
        PATH="$2:$PATH" bash "$ROOT/install.sh" >"$TMP/install-$4.log" 2>&1
}

# --- scenario A: desktop (no battery)
BIN_A="$TMP/binA"; LOG_A="$TMP/pacmanA.log"; HOME_A="$TMP/homeA"
make_shims "$BIN_A" "$LOG_A"
if run_install "$HOME_A" "$BIN_A" "$LOG_A" 0; then ok "install run #1 (desktop) exits 0"; else bad "install run #1 failed"; tail -20 "$TMP/install-0.log"; fi
CA="$HOME_A/.config"
check "hyprland.lua installed"        test -f "$CA/hypr/hyprland.lua"
check "scripts executable"            test -x "$CA/hypr/scripts/powermenu.sh"
check "wallpaper path baked in"       bash -c "! grep -q __WALLPAPER__ '$CA/hypr/hyprpaper.conf' && grep -q 'homeA/.config/hypr/assets/wallpaper.png' '$CA/hypr/hyprpaper.conf'"
check "battery module removed (desktop)" bash -c "! grep -q '\"modules-right\": .*\"battery\"' '$CA/waybar/config'"
check "waybar JSON still valid after battery removal" python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CA/waybar/config"
check "pacman asked for hyprland+waybar" grep -q "hyprland" "$LOG_A"
check "pacman skipped already-installed kitty" bash -c "! grep -q ' kitty ' '$LOG_A'"

# update-safety: user edits user.lua, re-runs installer
echo "-- my-marker-42" >> "$CA/hypr/user.lua"
if run_install "$HOME_A" "$BIN_A" "$LOG_A" 0; then ok "install run #2 (update) exits 0"; else bad "install run #2 failed"; fi
check "backup created on update"      bash -c "ls -d '$CA/hypr.backup-'* >/dev/null"
check "user.lua preserved across update" grep -q "my-marker-42" "$CA/hypr/user.lua"

# --- scenario B: laptop (battery present)
BIN_B="$TMP/binB"; LOG_B="$TMP/pacmanB.log"; HOME_B="$TMP/homeB"
make_shims "$BIN_B" "$LOG_B"
if run_install "$HOME_B" "$BIN_B" "$LOG_B" 1; then ok "install run (laptop) exits 0"; else bad "laptop install failed"; tail -20 "$TMP/install-1.log"; fi
check "battery module kept (laptop)" grep -q '"modules-right": .*"battery"' "$HOME_B/.config/waybar/config"

# --- dry run changes nothing
HOME_C="$TMP/homeC"; mkdir -p "$HOME_C"
HOME="$HOME_C" XDG_CONFIG_HOME="$HOME_C/.config" PATH="$BIN_A:$PATH" \
    bash "$ROOT/install.sh" --dry-run >"$TMP/dry.log" 2>&1
check "dry-run exits 0" test $? -eq 0
check "dry-run touches nothing" bash -c "[ ! -e '$HOME_C/.config/hypr' ]"

# ══════════════════════════ TEST 7: scripts functional ═════════════════════
start 7 "helper scripts functional tests (stubbed binaries)"
BIN_S="$TMP/binS"; LOG_S="$TMP/scripts.log"; mkdir -p "$BIN_S"; : > "$LOG_S"
mk() { printf '#!/bin/sh\necho "%s $*" >> "%s"\n%s\n' "$1" "$LOG_S" "${2:-}" > "$BIN_S/$1"; chmod +x "$BIN_S/$1"; }
mk grim   'f=""; for a in "$@"; do f="$a"; done; case "$f" in *.png) : > "$f" ;; esac'
mk slurp  'echo "0,0 100x100"'
mk wl-copy 'cat > /dev/null'
mk notify-send ''
mk hyprctl 'if [ "$1" = "activewindow" ]; then echo "{\"at\":[10,20],\"size\":[300,200]}"; fi'
mk fuzzel  'if [ -n "${FUZZEL_REPLY:-}" ]; then echo "$FUZZEL_REPLY"; else head -n1; fi'
mk cliphist 'if [ "$1" = "list" ]; then echo "1\tfirst item"; else cat; fi'
mk loginctl ''
mk systemctl ''
mk hyprshutdown ''
S="$ROOT/dotfiles/hypr/scripts"
export PATH="$BIN_S:$PATH" LOG_S
run() { env PATH="$BIN_S:$PATH" bash "$@" >"$TMP/scr.log" 2>&1; }

run "$S/screenshot.sh" full
check "screenshot full: grim + wl-copy + notify called" bash -c "grep -q 'grim ' '$LOG_S' && grep -q 'wl-copy ' '$LOG_S' && grep -q 'notify-send ' '$LOG_S'"
run "$S/screenshot.sh" region
check "screenshot region: slurp geometry passed to grim" grep -q 'grim -g 0,0 100x100' "$LOG_S"
run "$S/screenshot.sh" window
check "screenshot window: hyprctl geometry parsed" grep -q 'grim -g 10,20 300x200' "$LOG_S"
: > "$LOG_S"
FUZZEL_REPLY=" Lock" run "$S/powermenu.sh"
check "powermenu: Lock -> loginctl lock-session" grep -q 'loginctl lock-session' "$LOG_S"
: > "$LOG_S"
FUZZEL_REPLY=" Logout" run "$S/powermenu.sh"
check "powermenu: Logout -> hyprshutdown (graceful)" grep -q 'hyprshutdown ' "$LOG_S"
: > "$LOG_S"
FUZZEL_REPLY=" Reboot" run "$S/powermenu.sh"
check "powermenu: Reboot -> systemctl reboot" grep -q 'systemctl reboot' "$LOG_S"
: > "$LOG_S"
run "$S/clipboard.sh"
check "clipboard: cliphist list -> fuzzel -> decode -> wl-copy" bash -c "grep -q 'cliphist list' '$LOG_S' && grep -q 'fuzzel --dmenu --with-nth 2' '$LOG_S' && grep -q 'cliphist decode' '$LOG_S' && grep -q 'wl-copy ' '$LOG_S'"

# ══════════════════════════ TEST 8: repo hygiene ═══════════════════════════
start 8 "repo hygiene (EOF newlines, CRLF, wallpaper asset, binary cross-ref)"
check "all text files end with newline" bash -c '
    for f in $(find "$ROOT/install.sh" "$ROOT/dotfiles" -type f ! -name "*.png"); do
        [ -n "$(tail -c1 "$f")" ] && { echo "no EOF newline: $f"; exit 1; }
    done'
check "no CRLF line endings" bash -c '! grep -rIlU1 $'"'"'\r'"'"' "$ROOT/dotfiles" "$ROOT/install.sh"'
check "wallpaper: valid PNG, 16:9, >=1920 wide, <5MB" python3 - "$ROOT/dotfiles/hypr/assets/wallpaper.png" <<'EOF'
import sys, os
from PIL import Image
p = sys.argv[1]
im = Image.open(p); im.verify()
im = Image.open(p); w, h = im.size
assert im.format == "PNG", im.format
assert w >= 1920 and abs(w/h - 16/9) < 0.01, (w, h)
assert os.path.getsize(p) < 5 * 1024 * 1024
print(f"wallpaper {w}x{h} OK")
EOF
check "no stray placeholders outside hyprpaper template" bash -c '
    ! grep -rn "__WALLPAPER__" "$ROOT/dotfiles" --include="*" | grep -v "hypr/hyprpaper.conf"'
check "every binary referenced by configs/scripts is installed by install.sh" python3 "$ROOT/tests/check_binaries.py"

# ══════════════════════════ SUMMARY ═══════════════════════════════════════
echo >> "$OUT"
echo "**RESULT: $PASS passed, $FAIL failed**" >> "$OUT"
echo; echo "════════════════════════════════════"
echo "  TOTAL: $PASS passed, $FAIL failed"
echo "  results: tests/RESULTS.md"
echo "════════════════════════════════════"
[[ $FAIL -eq 0 ]]
