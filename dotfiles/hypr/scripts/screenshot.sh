#!/usr/bin/env bash
# screenshot.sh — save + copy-to-clipboard screenshots.
#   screenshot.sh full    entire screen
#   screenshot.sh region  select area with slurp
#   screenshot.sh window  active window geometry
set -euo pipefail

mode="${1:-full}"
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y%m%d_%H%M%S).png"

case "$mode" in
    region)
        geom="$(slurp)" || exit 0          # cancelled: exit quietly
        grim -g "$geom" "$file"
        ;;
    full)
        grim "$file"
        ;;
    window)
        geom="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        grim -g "$geom" "$file"
        ;;
    *)
        echo "usage: screenshot.sh [full|region|window]" >&2
        exit 1
        ;;
esac

wl-copy < "$file"
notify-send -a hypr-min -u low "Screenshot saved" "$file" || true
