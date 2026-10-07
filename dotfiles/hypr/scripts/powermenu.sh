#!/usr/bin/env bash
# powermenu.sh — tiny fuzzy power menu (fuzzel dmenu).
# Everything session-related in one place, reachable from SUPER+X or SUPER+T x.
set -euo pipefail

choice="$(printf '%s\n' \
    "󰌾 Lock" \
    "󰍃 Log out" \
    "󰍹 Screen off" \
    "󰒲 Suspend" \
    "󰑓 Reboot" \
    "󰐥 Shutdown" \
    | fuzzel --dmenu --prompt "power ❯ " --width 34 --lines 6)" || exit 0

case "$choice" in
    *Lock)
        loginctl lock-session
        ;;
    *"Log out")
        if command -v hyprshutdown >/dev/null 2>&1; then
            hyprshutdown
        else
            hyprctl dispatch 'hl.dsp.exit()'
        fi
        ;;
    *"Screen off")
        # not from a keybind: hypridle's own DPMS path, wakes on any input
        hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
        ;;
    *Suspend)
        systemctl suspend
        ;;
    *Reboot)
        systemctl reboot
        ;;
    *Shutdown)
        systemctl poweroff
        ;;
esac
