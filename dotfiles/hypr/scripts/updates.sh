#!/usr/bin/env bash
# updates.sh — tiny Arch/CachyOS update helper.
#   updates.sh check          bar mode: "N\n\nclass" if updates pending, else
#                             nothing at all (the waybar module hides itself)
#   updates.sh check-notify   the same check as a notification (SUPER+U)
#   updates.sh run            update in a terminal window (SUPER+SHIFT+U)
#
# `check` is what the bar runs — once an hour, read-only, ~50 ms.
set -euo pipefail

count() {
    if command -v pacman >/dev/null 2>&1; then
        { pacman -Quq 2>/dev/null || true; } | grep -c . || true
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
        else
            cmd="sudo pacman -Syu --needed"
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
