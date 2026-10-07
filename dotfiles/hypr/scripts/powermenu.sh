#!/usr/bin/env bash
# powermenu.sh — tiny fuzzy power menu (fuzzel dmenu).
# Lock/Logout/Suspend/Reboot/Shutdown in one place.
set -euo pipefail

choice="$(printf '%s\n' \
    "󰌾 Lock" \
    " Logout" \
    "󰤄 Suspend" \
    " Reboot" \
    " Shutdown" | fuzzel --dmenu)" || exit 0

case "$choice" in
    *Lock)     loginctl lock-session ;;
    *Logout)   if command -v hyprshutdown >/dev/null 2>&1; then
                   hyprshutdown
               else
                   hyprctl dispatch 'hl.dsp.exit()'
               fi ;;
    *Suspend)  systemctl suspend ;;
    *Reboot)   systemctl reboot ;;
    *Shutdown) systemctl poweroff ;;
esac
