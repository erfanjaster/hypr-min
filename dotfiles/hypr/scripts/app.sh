#!/usr/bin/env bash
# app.sh — open an app by role, picking the first one that is actually
# installed. Keeps hyprland.lua free of hard-coded app names and costs nothing
# at rest (a fork only when you press the key).
#
#   app.sh browser | files | editor | scratch
set -euo pipefail

TERM_APP="${TERMINAL:-kitty}"
app=""

pick() { # pick a b c -> first command that exists
    local c
    for c in "$@"; do
        if command -v "$c" >/dev/null 2>&1; then printf '%s' "$c"; return 0; fi
    done
    return 1
}

missing() {
    notify-send -a hypr-min -u critical "hypr-min" "$1" 2>/dev/null || true
    exit 1
}

case "${1:-}" in
    browser)
        app="$(pick firefox zen-browser librewolf brave microsoft-edge-stable \
                    chromium vivaldi opera || true)"
        [[ -n "$app" ]] || missing "no web browser installed"
        ;;
    files)
        app="$(pick thunar dolphin nautilus nemo pcmanfm-qt pcmanfm || true)"
        # no GUI file manager? a terminal in $HOME is still useful
        [[ -n "$app" ]] || app="$TERM_APP"
        ;;
    editor)
        app="$(pick code codium vscodium || true)"
        if [[ -z "$app" ]]; then
            # only terminal editors around: run one inside the terminal
            exec "$TERM_APP" -e "${VISUAL:-${EDITOR:-nano}}"
        fi
        ;;
    scratch)
        exec "$TERM_APP" --class kitty-scratch
        ;;
    *)
        echo "usage: app.sh {browser|files|editor|scratch}" >&2
        exit 1
        ;;
esac

exec "$app"
