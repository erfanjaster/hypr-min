#!/usr/bin/env bash
# audiomenu.sh — pick the default output/input, mute, or open the mixer.
# Parses `wpctl status` (one call, no daemon) and offers the result in fuzzel.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
have wpctl || { notify-send -a hypr-min -u critical "audio" \
    "wpctl not found — install wireplumber" 2>/dev/null || true; exit 1; }

# id<TAB>label  — the '*' in wpctl's tree marks the current default
nodes() { # $1 = sink|source
    wpctl status 2>/dev/null | awk -v want="$1" '
        /─ Sinks:/    { sec = "sink";   next }
        /─ Sources:/  { sec = "source"; next }
        /─ Devices:/  { sec = "device"; next }
        /─ Clients:/  { sec = "client"; next }
        /─ Endpoints:/{ sec = "endp";   next }
        /^[[:space:]]*$/ { sec = ""; next }
        sec != want { next }
        {
            if (match($0, /[0-9]+\./) == 0) next
            id   = substr($0, RSTART, RLENGTH - 1)
            name = substr($0, RSTART + RLENGTH)
            sub(/[[:space:]]*\[vol:.*/, "", name)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            def = (index($0, "*") > 0) ? "   ← default" : ""
            printf "%s\t%s%s\n", id, name, def
        }'
}

menu=""
add() { menu+="$(printf '%s\t%s' "$1" "$2")"$'\n'; }

while IFS=$'\t' read -r id name; do
    [[ -n "$id" ]] && add "sink:$id" "󰕾  $name"
done < <(nodes sink)

while IFS=$'\t' read -r id name; do
    [[ -n "$id" ]] && add "source:$id" "󰍬  $name"
done < <(nodes source)

vol="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}' || true)"
add "mute" "󰖁  Mute/unmute output${vol:+  (now ${vol})}"
add "pavu" "⚙  Open volume mixer (pavucontrol)"

choice="$(printf '%s' "$menu" | fuzzel --dmenu --with-nth 2 --prompt "audio ❯ " \
          --width 62 --lines 14)" || exit 0
[[ -n "$choice" ]] || exit 0

action="${choice%%$'\t'*}"
case "$action" in
    sink:*)   wpctl set-default "${action#sink:}"   >/dev/null ;;
    source:*) wpctl set-default "${action#source:}" >/dev/null ;;
    mute)     wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null ;;
    pavu)     pavucontrol >/dev/null 2>&1 & ;;
esac
