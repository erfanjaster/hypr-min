#!/usr/bin/env bash
# updates.sh — tiny update helper for Arch/CachyOS *and* Debian/Ubuntu.
#   updates.sh check          bar mode: "N\n\nclass" if updates pending, else
#                             nothing at all (the waybar module hides itself)
#   updates.sh check-notify   the same check as a notification (SUPER+U)
#   updates.sh run            update in a terminal window (SUPER+SHIFT+U)
#
# `check` is what the bar runs — once an hour, read-only, ~50 ms.
# Backend auto-detects: pacman (Arch) → apt-get (Debian). The list of upgradable
# packages lives in root-owned files under /var/lib/, so both checks shell out
# to sudo -A (askpass); no pkexec — it would pop a GUI window from the hourly
# bar poll. On Debian the first sudo askpass prompt can also refresh apt's
# package index, which makes that one run slower than Arch's pure-local check.
set -euo pipefail

count() {
    if command -v pacman >/dev/null 2>&1; then
        { sudo -A pacman -Quq 2>/dev/null || true; } | grep -c . || true
    elif command -v apt-get >/dev/null 2>&1; then
        { sudo -A apt-get upgrade --simulate 2>/dev/null \
            | awk '/^The following packages will be upgraded:/ { flag = 1; next }
                   flag && NF == 0 { exit }
                   flag { n++ }
                   END { print n + 0 }' || true; }
    else
        echo 0
    fi
}

case "${1:-check}" in
    check)
        # bar mode: i3blocks output — line 1 text, line 2 tooltip, line 3 css class.
        # No output at all = the module hides itself (hide-empty-text).
        n="$(count)"
        if [[ "${n:-0}" -gt 0 ]]; then
            printf '%s\n\npending\n' "$n"
        fi
        ;;
    check-notify)
        n="$(count)"
        if [[ "${n:-0}" -gt 0 ]]; then
            notify-send -a hypr-min -u normal "Updates available" \
                "$n package(s) — SUPER+SHIFT+U to install"
        else
            notify-send -a hypr-min -u low "System up to date" "nothing pending"
        fi
        ;;
    run)
        term="${TERMINAL:-kitty}"
        if command -v paru >/dev/null 2>&1; then
            cmd="paru -Syu"
        elif command -v yay >/dev/null 2>&1; then
            cmd="yay -Syu"
        elif command -v pacman >/dev/null 2>&1; then
            cmd="sudo pacman -Syu --needed"
        elif command -v apt-get >/dev/null 2>&1; then
            cmd="sudo apt update && sudo apt full-upgrade"
        else
            echo "updates.sh: no pacman/apt found" >&2
            exit 1
        fi
        # shellcheck disable=SC2086
        exec "$term" --title "system update" -e bash -c \
            "$cmd; printf '\n[done] close this window when ready\n'; read -r"
        ;;
    *)
        echo "usage: updates.sh {check|check-notify|run}" >&2
        exit 1
        ;;
esac
