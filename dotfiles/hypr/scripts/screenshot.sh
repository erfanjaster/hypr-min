#!/usr/bin/env bash
# screenshot.sh — save and/or copy screenshots.
#   full        whole screen      -> file + clipboard
#   region      pick with slurp   -> file + clipboard
#   window      active window     -> file + clipboard
#   clip        pick with slurp   -> clipboard only (nothing touches the disk)
#   clip-full   whole screen      -> clipboard only
set -euo pipefail

mode="${1:-full}"
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
file="$dir/$(date +%Y%m%d-%H%M%S).png"

saved() { # $1 = png file
    wl-copy --type image/png < "$1"
    notify-send -a hypr-min -u low -i "$1" "Screenshot saved" "$1" 2>/dev/null || true
}

copied() { # $1 = label
    notify-send -a hypr-min -u low "$1 copied to clipboard" 2>/dev/null || true
}

case "$mode" in
    region)
        geom="$(slurp)" || exit 0            # cancelled: exit quietly
        mkdir -p "$dir"
        grim -g "$geom" "$file"
        saved "$file"
        ;;
    full)
        mkdir -p "$dir"
        grim "$file"
        saved "$file"
        ;;
    window)
        geom="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        mkdir -p "$dir"
        grim -g "$geom" "$file"
        saved "$file"
        ;;
    clip)
        geom="$(slurp)" || exit 0
        grim -g "$geom" -t png - | wl-copy --type image/png
        copied "Region"
        ;;
    clip-full)
        grim -t png - | wl-copy --type image/png
        copied "Screen"
        ;;
    *)
        echo "usage: screenshot.sh [full|region|window|clip|clip-full]" >&2
        exit 1
        ;;
esac
