#!/usr/bin/env bash
# ============================================================================
#  hypr-min test suite — 10 tests
#  Needs: bash, lua5.4, shellcheck, python3 (+ Pillow), jq
#  Usage: ./tests/run_tests.sh     (writes tests/RESULTS.md)
# ============================================================================
set -u

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/tests/RESULTS.md"
PASS=0; FAIL=0; SKIP=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

start() { echo; echo "── TEST $1: $2"; echo "## TEST $1 — $2" >> "$OUT"; }
ok()    { PASS=$((PASS+1)); echo "   ✔ $1"; echo "- ✔ $1" >> "$OUT"; }
bad()   { FAIL=$((FAIL+1)); echo "   ✘ $1"; echo "- ✘ $1" >> "$OUT"; }
skip()  { SKIP=$((SKIP+1)); echo "   – $1 (skipped)"; echo "- – $1 (skipped)" >> "$OUT"; }
check() { # check <desc> <cmd...>
    local d="$1"; shift
    : > "$TMP/last.log"
    if "$@" >>"$TMP/last.log" 2>&1; then ok "$d"; else bad "$d (see log below)"; sed 's/^/     | /' "$TMP/last.log" | tail -8; fi
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
check "user.lua require is pcall-protected" grep -q 'pcall(require, "user")' "$ROOT/dotfiles/hypr/hyprland.lua"
check "registers >=100 binds (keymap not accidentally gutted)" bash -c \
    'lua5.4 "$1/tests/lua_stub_test.lua" "$1/dotfiles/hypr/hyprland.lua" | grep -qE "[0-9]{3,} binds"' _ "$ROOT"

# the harness must actually catch things, or the checks above are decoration
cat > "$TMP/bad.lua" <<'LUA'
hl.bind("SUPER + Z", hl.dsp.window.close(), { description = "ok" })
hl.bind("SUPER + Z", hl.dsp.window.kill(),  { description = "duplicate" })
hl.define_submap("trap", function()
    hl.bind("a", hl.dsp.exec_cmd("true"), { description = "no way out" })
end)
hl.bind("SUPER + Y", function() error("boom") end, { description = "bad callback" })
hl.bind("SUPER + U", hl.dsp.window.float(), { description = "x", not_a_flag = true })
hl.bind("SUPER + I", hl.dsp.does_not_exist(), { description = "unknown dispatcher" })
LUA
check "stub catches duplicate bind + submap trap + bad callback + bad flag" bash -c \
    '! lua5.4 "$1/tests/lua_stub_test.lua" "$2/bad.lua" >/dev/null 2>&1' _ "$ROOT" "$TMP"
check "stub reports all five problems" bash -c \
    'lua5.4 "$1/tests/lua_stub_test.lua" "$2/bad.lua" 2>&1 | grep -c "^  - " | grep -qx 5' _ "$ROOT" "$TMP"

# ══════════════════════════ TEST 3: hyprlang configs ═══════════════════════
start 3 "hyprlang configs: schema, dpms syntax, no legacy dispatchers"
check "hyprlang lint" python3 "$ROOT/tests/lint_hyprlang.py"
check "no legacy 'hyprctl dispatch <word>' anywhere" bash -c \
    '! grep -rnE "hyprctl dispatch [a-z]" "$1/dotfiles"' _ "$ROOT"
check "no hyprlang bind=/bindm= directives left" bash -c \
    '! grep -rnE "^[[:space:]]*bind[m]?[[:space:]]*=" "$1/dotfiles/hypr"' _ "$ROOT"

# ══════════════════════════ TEST 4: waybar/fuzzel/mako ═════════════════════
start 4 "waybar JSON+CSS, fuzzel.ini, mako config validation"
check "misc lint" python3 "$ROOT/tests/lint_misc.py"

# ══════════════════════════ TEST 5: bind + script hygiene ══════════════════
start 5 "keybind hygiene (descriptions, submaps, scripts, README in sync)"
check "bind lint" python3 "$ROOT/tests/lint_binds.py"

# ══════════════════════════ TEST 6: resource budget ════════════════════════
start 6 "resource budget (resident processes, blur, polling, no busy loops)"
check "budget lint" python3 "$ROOT/tests/lint_budget.py"

# ══════════════════════════ TEST 7: packages exist upstream ════════════════
start 7 "every package in install.sh exists in the official Arch repos"
if [[ -n "${OFFLINE:-}" ]]; then
    skip "package availability (OFFLINE=1)"
else
    check "package availability (live archlinux.org API)" python3 "$ROOT/tests/check_packages.py"
fi

# ══════════════════════════ TEST 8: installer end-to-end ═══════════════════
start 8 "installer end-to-end (desktop + laptop + layouts + update safety)"

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
    cat > "$1/ls" <<'EOF'
#!/bin/sh
for a in "$@"; do
  case "$a" in
    /sys/class/power_supply/BAT*)
        [ "${FAKE_BATTERY:-0}" = "1" ] && exit 0 || exit 2 ;;
    /sys/class/backlight/*)
        [ "${FAKE_BACKLIGHT:-0}" = "1" ] && exit 0 || exit 2 ;;
    /sys/class/hwmon/*|/sys/class/thermal/*)
        [ "${FAKE_TEMP:-0}" = "1" ] && exit 0 || exit 2 ;;
  esac
done
exec /bin/ls "$@"
EOF
    chmod +x "$1"/*
}

run_install() { # $1=fakehome $2=bindir $3=battery $4=backlight $5=temp
    mkdir -p "$1"
    HOME="$1" XDG_CONFIG_HOME="$1/.config" \
        FAKE_BATTERY="$3" FAKE_BACKLIGHT="$4" FAKE_TEMP="$5" \
        PATH="$2:$PATH" bash "$ROOT/install.sh" >"$TMP/install-$3$4$5.log" 2>&1
}

# list every module that will actually be rendered (top level + inside groups)
cat > "$TMP/mods.py" <<'PY'
import json, sys
wb = json.load(open(sys.argv[1]))
mods = (wb.get("modules-left", []) + wb.get("modules-center", [])
        + wb.get("modules-right", []))
for k, v in wb.items():
    if k.startswith("group/") and isinstance(v, dict):
        mods += v.get("modules", [])
print("\n".join(mods))
PY
has_mod()  { python3 "$TMP/mods.py" "$1" | grep -qx "$2"; }
no_mod()   { ! has_mod "$1" "$2" && ! grep -q "\"$2\": {" "$1"; }
valid_json() { python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1"; }

# --- scenario A: desktop (no battery, no backlight, no thermal sensor)
BIN_A="$TMP/binA"; LOG_A="$TMP/pacmanA.log"; HOME_A="$TMP/homeA"
make_shims "$BIN_A" "$LOG_A"
if run_install "$HOME_A" "$BIN_A" 0 0 0; then ok "install run #1 (desktop) exits 0"
else bad "install run #1 failed"; tail -20 "$TMP/install-000.log"; fi
CA="$HOME_A/.config"
check "hyprland.lua installed"        test -f "$CA/hypr/hyprland.lua"
check "user.lua installed"            test -f "$CA/hypr/user.lua"
check "all 10 helper scripts installed and executable" bash -c \
    '[ "$(ls -1 "$1/hypr/scripts" | wc -l)" = 10 ] && ! find "$1/hypr/scripts" -name "*.sh" ! -executable | grep -q .' _ "$CA"
check "wallpaper path baked in"       bash -c "! grep -q __WALLPAPER__ '$CA/hypr/hyprpaper.conf' && grep -q 'homeA/.config/hypr/assets/wallpaper.png' '$CA/hypr/hyprpaper.conf'"
check "waybar JSON valid after pruning" valid_json "$CA/waybar/config"
check "battery module dropped (desktop)"     no_mod "$CA/waybar/config" "battery"
check "backlight module dropped (no panel)"  no_mod "$CA/waybar/config" "backlight"
check "temperature module dropped (no sensor)" no_mod "$CA/waybar/config" "temperature"
check "layout module dropped (single layout)"  no_mod "$CA/waybar/config" "hyprland/language"
check "group/net survives with network+pulseaudio" bash -c \
    'has_mod() { python3 "$1/mods.py" "$2" | grep -qx "$3"; }; has_mod "$1" "$2" network && has_mod "$1" "$2" pulseaudio' _ "$TMP" "$CA/waybar/config"
check "group/system survives with cpu+memory" bash -c \
    'has_mod() { python3 "$1/mods.py" "$2" | grep -qx "$3"; }; has_mod "$1" "$2" cpu && has_mod "$1" "$2" memory' _ "$TMP" "$CA/waybar/config"
check "pacman asked for hyprland+waybar+networkmanager" bash -c \
    'grep -q hyprland "$1" && grep -q waybar "$1" && grep -q networkmanager "$1"' _ "$LOG_A"
check "pacman skipped already-installed kitty" bash -c "! grep -q ' kitty ' '$LOG_A'"

# --- scenario A2: update, user.lua edited (Persian+English) and preserved
echo "-- my-marker-42" >> "$CA/hypr/user.lua"
cat >> "$CA/hypr/user.lua" <<'LUA'
hl.config({ input = { kb_layout = "us,ir", kb_options = "grp:alt_shift_toggle" } })
LUA
if run_install "$HOME_A" "$BIN_A" 0 0 0; then ok "install run #2 (update) exits 0"
else bad "install run #2 failed"; tail -20 "$TMP/install-000.log"; fi
check "backup created on update"      bash -c "ls -d '$CA/hypr.backup-'* >/dev/null"
check "user.lua preserved across update" grep -q "my-marker-42" "$CA/hypr/user.lua"
check "layout module kept for us,ir keyboard" has_mod "$CA/waybar/config" "hyprland/language"
check "waybar JSON still valid after keeping layout module" valid_json "$CA/waybar/config"

# --- scenario B: laptop (battery + backlight + thermal sensor)
BIN_B="$TMP/binB"; LOG_B="$TMP/pacmanB.log"; HOME_B="$TMP/homeB"
make_shims "$BIN_B" "$LOG_B"
if run_install "$HOME_B" "$BIN_B" 1 1 1; then ok "install run (laptop) exits 0"
else bad "laptop install failed"; tail -20 "$TMP/install-111.log"; fi
CB="$HOME_B/.config"
check "battery module kept (laptop)"    has_mod "$CB/waybar/config" "battery"
check "backlight module kept (laptop)"  has_mod "$CB/waybar/config" "backlight"
check "temperature module kept (sensor)" has_mod "$CB/waybar/config" "temperature"
check "laptop waybar JSON valid" valid_json "$CB/waybar/config"

# --- scenario C: dry run changes nothing
HOME_C="$TMP/homeC"; mkdir -p "$HOME_C"
HOME="$HOME_C" XDG_CONFIG_HOME="$HOME_C/.config" PATH="$BIN_A:$PATH" \
    bash "$ROOT/install.sh" --dry-run >"$TMP/dry.log" 2>&1
check "dry-run exits 0" test $? -eq 0
check "dry-run touches nothing" bash -c "[ ! -e '$HOME_C/.config/hypr' ]"

# ══════════════════════════ TEST 9: scripts functional ═════════════════════
start 9 "helper scripts functional tests (stubbed binaries)"
BIN_S="$TMP/binS"; LOG_S="$TMP/scripts.log"; mkdir -p "$BIN_S"; : > "$LOG_S"
export LOG_S FUZZEL_IN="$TMP/fuzzel-in.txt"

mk() { printf '#!/bin/sh\necho "%s $*" >> "%s"\n%s\n' "$1" "$LOG_S" "${2:-}" > "$BIN_S/$1"; chmod +x "$BIN_S/$1"; }
mk grim   'f=""; for a in "$@"; do f="$a"; done; case "$f" in *.png) : > "$f" ;; esac'
mk slurp  'echo "0,0 100x100"'
mk wl-copy 'cat > /dev/null'
mk cliphist 'if [ "$1" = "list" ]; then printf "1\tfirst item\n"; else cat; fi'
mk loginctl ''
mk systemctl ''
mk hyprshutdown ''
mk makoctl ''
mk playerctl ''
mk brightnessctl ''
mk pavucontrol ''
mk nm-connection-editor ''
mk firefox ''
mk thunar ''
mk kitty ''
mk ip 'echo "2: eth0    inet 10.0.0.5/24 brd 10.0.0.255 scope global eth0"'
mk pgrep '[ "${FAKE_RUNNING:-0}" = "1" ] && exit 0 || exit 1'
mk pkill ''
mk setsid ''
mk notify-send ''

# fuzzel: log the invocation, keep what it was offered, then answer
cat > "$BIN_S/fuzzel" <<'EOF'
#!/bin/sh
echo "fuzzel $*" >> "$LOG_S"
if [ -n "${FUZZEL_IN:-}" ]; then
    cat > "$FUZZEL_IN"
    if [ -n "${FUZZEL_REPLY:-}" ]; then printf '%s\n' "$FUZZEL_REPLY"; else head -n1 "$FUZZEL_IN"; fi
elif [ -n "${FUZZEL_REPLY:-}" ]; then
    printf '%s\n' "$FUZZEL_REPLY"
else
    head -n1
fi
EOF
chmod +x "$BIN_S/fuzzel"

cat > "$BIN_S/hyprctl" <<'EOF'
#!/bin/sh
echo "hyprctl $*" >> "$LOG_S"
case "$1 $2" in
  "binds -j") cat "$BINDS_JSON" ;;
  "binds "*)  printf 'bind\tSUPER\tQ\tclose\t(Close window)\n' ;;
  "activewindow -j") printf '{"at":[10,20],"size":[300,200]}' ;;
esac
exit 0
EOF
chmod +x "$BIN_S/hyprctl"

cat > "$BIN_S/nmcli" <<'EOF'
#!/bin/sh
echo "nmcli $*" >> "$LOG_S"
case "$*" in
  "radio wifi")        echo "enabled" ;;
  *"--active"*)        echo "HomeWiFi:802-11-wireless" ;;
  *"wifi list"*)       printf 'HomeWiFi:90:WPA2\nHomeWiFi:88:WPA2\nCafeOpen:45:\n' ;;
  *"connection show"*) printf 'HomeWiFi:802-11-wireless\nOffice:802-3-ethernet\n' ;;
esac
exit 0
EOF
chmod +x "$BIN_S/nmcli"

cat > "$BIN_S/wpctl" <<'EOF'
#!/bin/sh
echo "wpctl $*" >> "$LOG_S"
case "$1" in
  status)      cat "$WPCTL_STATUS" ;;
  get-volume)  echo "Volume: 0.42" ;;
esac
exit 0
EOF
chmod +x "$BIN_S/wpctl"

cat > "$BIN_S/pacman" <<'EOF'
#!/bin/sh
echo "pacman $*" >> "$LOG_S"
case "$1" in
  -Quq) printf 'linux\nmesa\nkitty\n' ;;
  -Qq)  printf 'a\nb\nc\nd\ne\n' ;;
esac
exit 0
EOF
chmod +x "$BIN_S/pacman"

cat > "$TMP/binds.json" <<'JSON'
[
 {"modmask":"SUPER","key":"Q","description":"Close window","submap":""},
 {"modmask":"SUPER","key":"T","description":"Tools menu (submap)","submap":""},
 {"modmask":"","key":"t","description":"[tools] Terminal","submap":"tools"},
 {"modmask":"SUPER SHIFT","key":"Print","description":"Screenshot: screen to clipboard","submap":""},
 {"modmask":64,"key":"Return","description":"Terminal","submap":""}
]
JSON
cat > "$TMP/wpctl-status.txt" <<'TXT'
PipeWire 'pipewire-0' [1.4.0, user@host, cookie:1]
 └─ Clients:
        30. pipewire                            [user@host, pid:1]

Audio
 ├─ Devices:
 │      47. Built-in Audio                      [alsa]
 │
 ├─ Sinks:
 │  *   48. Built-in Audio Analog Stereo        [vol: 0.42]
 │      49. HDMI Digital Stereo (HDMI)          [vol: 1.00]
 │
 ├─ Sources:
 │  *   50. Built-in Audio Analog Stereo        [vol: 1.00]
 │
 └─ Endpoints:
TXT

S="$ROOT/dotfiles/hypr/scripts"
export PATH="$BIN_S:$PATH" BINDS_JSON="$TMP/binds.json" WPCTL_STATUS="$TMP/wpctl-status.txt"
run() { env PATH="$BIN_S:$PATH" LOG_S="$LOG_S" FUZZEL_IN="$FUZZEL_IN" \
            BINDS_JSON="$BINDS_JSON" WPCTL_STATUS="$WPCTL_STATUS" \
            FUZZEL_REPLY="${FUZZEL_REPLY:-}" FAKE_RUNNING="${FAKE_RUNNING:-1}" \
            TERMINAL="${TERMINAL:-kitty}" \
        bash "$@" >"$TMP/scr.log" 2>&1; }
reset_log() { : > "$LOG_S"; : > "$FUZZEL_IN"; unset FUZZEL_REPLY FAKE_RUNNING; }

# -- screenshots
reset_log; run "$S/screenshot.sh" full
check "screenshot full: grim + wl-copy + notify" bash -c \
    "grep -q 'grim ' '$LOG_S' && grep -q 'wl-copy' '$LOG_S' && grep -q 'notify-send' '$LOG_S'"
reset_log; run "$S/screenshot.sh" region
check "screenshot region: slurp geometry passed to grim" grep -q 'grim -g 0,0 100x100' "$LOG_S"
reset_log; run "$S/screenshot.sh" window
check "screenshot window: hyprctl geometry parsed" grep -q 'grim -g 10,20 300x200' "$LOG_S"
reset_log; run "$S/screenshot.sh" clip
check "screenshot clip: piped to clipboard, no file written" bash -c \
    "grep -q 'grim -g 0,0 100x100 -t png -' '$LOG_S' && grep -q 'wl-copy --type image/png' '$LOG_S'"
reset_log; run "$S/screenshot.sh" clip-full
check "screenshot clip-full: whole screen to clipboard" grep -q 'grim -t png -' "$LOG_S"

# -- power menu
reset_log; FUZZEL_REPLY="󰌾 Lock" run "$S/powermenu.sh"
check "powermenu: Lock -> loginctl lock-session" grep -q 'loginctl lock-session' "$LOG_S"
reset_log; FUZZEL_REPLY="󰍃 Log out" run "$S/powermenu.sh"
check "powermenu: Log out -> hyprshutdown (graceful)" grep -q 'hyprshutdown' "$LOG_S"
reset_log; FUZZEL_REPLY="󰑓 Reboot" run "$S/powermenu.sh"
check "powermenu: Reboot -> systemctl reboot" grep -q 'systemctl reboot' "$LOG_S"
reset_log; FUZZEL_REPLY="󰍹 Screen off" run "$S/powermenu.sh"
check "powermenu: Screen off -> lua dpms dispatch" grep -q 'hyprctl dispatch' "$LOG_S"

# -- clipboard
reset_log; run "$S/clipboard.sh"
check "clipboard: cliphist -> fuzzel -> decode -> wl-copy" bash -c \
    "grep -q 'cliphist list' '$LOG_S' && grep -q 'fuzzel --dmenu --with-nth 2' '$LOG_S' && grep -q 'cliphist decode' '$LOG_S' && grep -q 'wl-copy' '$LOG_S'"

# -- keybinds (live, from hyprctl binds -j)
if command -v jq >/dev/null 2>&1; then
    reset_log; run "$S/keybinds.sh"
    check "keybinds: reads live binds from hyprctl -j" grep -q 'hyprctl binds -j' "$LOG_S"
    check "keybinds: shows SUPER+Q / Close window" bash -c \
        "grep -q 'SUPER+Q' '$FUZZEL_IN' && grep -q 'Close window' '$FUZZEL_IN'"
    check "keybinds: marks submap membership" grep -q '\[tools\]' "$FUZZEL_IN"
    check "keybinds: renders modifier words, not bitmasks" bash -c \
        "grep -q 'SUPER SHIFT+Print' '$FUZZEL_IN' && grep -q 'SUPER+Return' '$FUZZEL_IN'"
else
    skip "keybinds tests need jq"
fi

# -- network menu
reset_log; run "$S/netmenu.sh"
check "netmenu: offers radio toggle, saved connections and scanned SSIDs" bash -c \
    "grep -q 'Wi-Fi: on' '$FUZZEL_IN' && grep -q 'Connect: Office' '$FUZZEL_IN' && grep -q 'HomeWiFi' '$FUZZEL_IN'"
check "netmenu: hides the password prompt behind the GUI editor" grep -q 'enter password' "$FUZZEL_IN"
check "netmenu: de-duplicates repeated SSIDs" bash -c \
    '[ "$(grep -c "HomeWiFi  (" "$FUZZEL_IN" || true)" -le 1 ]'
reset_log; FUZZEL_REPLY="up:Office	󰆓  Connect: Office (802-3-ethernet)" run "$S/netmenu.sh"
check "netmenu: selecting a saved connection runs nmcli connection up" grep -q 'nmcli connection up Office' "$LOG_S"

# -- audio menu
reset_log; run "$S/audiomenu.sh"
check "audiomenu: lists sinks and sources with the default marked" bash -c \
    "grep -q 'HDMI Digital Stereo' '$FUZZEL_IN' && grep -q 'default' '$FUZZEL_IN'"
reset_log; FUZZEL_REPLY=$'sink:49\tHDMI' run "$S/audiomenu.sh"
check "audiomenu: selecting a sink sets it default" grep -q 'wpctl set-default 49' "$LOG_S"

# -- updates
reset_log
out="$(env PATH="$BIN_S:$PATH" LOG_S="$LOG_S" bash "$S/updates.sh" check 2>/dev/null)"
check "updates check: i3blocks output (text + class)" bash -c \
    '[ "$(printf "%s" "$1" | sed -n 1p)" = "3" ] && [ "$(printf "%s" "$1" | sed -n 3p)" = "pending" ]' _ "$out"
reset_log; run "$S/updates.sh" check-notify
check "updates check-notify: tells the user how many" bash -c \
    "grep -q 'notify-send' '$LOG_S' && grep -q '3 package' '$LOG_S'"
reset_log; run "$S/updates.sh" run
check "updates run: opens the terminal with pacman -Syu" bash -c \
    "grep -q 'kitty --title system update' '$LOG_S' && grep -q 'pacman -Syu' '$LOG_S'"

# -- sysinfo
reset_log; run "$S/sysinfo.sh"
check "sysinfo: one notification with cpu/ram/disk/uptime" bash -c \
    "grep -q 'CPU' '$LOG_S' && grep -q 'RAM' '$LOG_S' && grep -q 'Uptime' '$LOG_S' && grep -q '10.0.0.5' '$LOG_S'"

# -- idle toggle
reset_log; FAKE_RUNNING=1 run "$S/idle.sh" toggle
check "idle toggle: stops hypridle when it is running" bash -c \
    "grep -q 'pkill -x hypridle' '$LOG_S' && grep -q 'notify-send' '$LOG_S'"
reset_log; FAKE_RUNNING=0 run "$S/idle.sh" toggle
check "idle toggle: restarts hypridle detached when stopped" bash -c \
    "grep -q 'setsid hypridle' '$LOG_S'"

# -- app roles
reset_log; run "$S/app.sh" browser
check "app browser: launches the first installed browser" grep -q 'firefox' "$LOG_S"
reset_log; run "$S/app.sh" files
check "app files: launches the first installed file manager" grep -q 'thunar' "$LOG_S"
reset_log; run "$S/app.sh" editor
check "app editor: falls back to \$TERMINAL -e \$EDITOR" grep -q 'kitty -e' "$LOG_S"
reset_log; run "$S/app.sh" scratch
check "app scratch: tagged kitty for the scratchpad rule" grep -q 'kitty --class kitty-scratch' "$LOG_S"

# ══════════════════════════ TEST 10: repo hygiene ══════════════════════════
start 10 "repo hygiene (EOF newlines, CRLF, wallpaper asset, binary cross-ref)"
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

# ═══════════════════════════════════════════════════════════════════════════
echo >> "$OUT"
echo "**RESULT: $PASS passed, $FAIL failed, $SKIP skipped**" >> "$OUT"
echo; echo "════════════════════════════════════"
echo "  TOTAL: $PASS passed, $FAIL failed, $SKIP skipped"
echo "  results: tests/RESULTS.md"
echo "════════════════════════════════════"
[[ $FAIL -eq 0 ]]
