#!/usr/bin/env bash
# clipboard.sh — pick an old clipboard entry (cliphist) and copy it back.
# Text-only history on purpose: an image history would keep every screenshot in
# RAM/disk for the whole session.
set -euo pipefail

if ! command -v cliphist >/dev/null 2>&1; then
    notify-send -a hypr-min -u critical "clipboard" "cliphist is not installed" 2>/dev/null || true
    exit 1
fi

if [[ -z "$(cliphist list 2>/dev/null || true)" ]]; then
    notify-send -a hypr-min -u low "clipboard" "history is empty — copy something first" 2>/dev/null || true
    exit 0
fi

# --with-nth 2 hides cliphist's numeric index column; fuzzel still returns the
# whole line, which is what `cliphist decode` needs.
entry="$(cliphist list | fuzzel --dmenu --with-nth 2 --prompt "clip ❯ " \
         --width 70 --lines 15 --placeholder "type to filter…")" || exit 0
[[ -n "$entry" ]] || exit 0

printf '%s' "$entry" | cliphist decode | wl-copy
