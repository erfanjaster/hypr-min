#!/usr/bin/env bash
# idle.sh — toggle the idle daemon without editing a single config file.
#   idle.sh toggle   stop/start hypridle (auto-lock + DPMS off)
#   idle.sh status   print "on" or "off"
#
# With hypridle stopped the screen stays on and the session never auto-locks.
# Handy for presentations, long downloads or reading; SUPER+SHIFT+I turns it back on.
set -euo pipefail

notify() { notify-send -a hypr-min -u low "hypr-min" "$1" "$2" 2>/dev/null || true; }

case "${1:-toggle}" in
    status)
        if pgrep -x hypridle >/dev/null 2>&1; then echo "on"; else echo "off"; fi
        ;;
    toggle)
        if pgrep -x hypridle >/dev/null 2>&1; then
            pkill -x hypridle || true
            notify "Idle + auto-lock OFF" "Screen stays on. SUPER+SHIFT+I to re-enable."
        else
            setsid hypridle >/dev/null 2>&1 </dev/null &
            notify "Idle + auto-lock ON" "Locks after 5 min, screen off after 6."
        fi
        ;;
    *)
        echo "usage: idle.sh {toggle|status}" >&2
        exit 1
        ;;
esac
