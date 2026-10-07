#!/usr/bin/env bash
# keybinds.sh — searchable cheat sheet of EVERY keybind, read live from
# Hyprland (so it can never drift from the config). Nothing is cached, nothing
# runs in the background: one hyprctl call, one fuzzel window.
set -euo pipefail

rows=""

if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    # modmask is a string on current builds and a bitmask on others: decode both
    rows="$(hyprctl binds -j 2>/dev/null | jq -r '
        def bits($m): [ ["SHIFT",1], ["CTRL",4], ["ALT",8], ["MOD3",32],
                        ["SUPER",64], ["MOD5",128] ]
                    | map(select((($m / .[1]) | floor) % 2 == 1) | .[0]) | join(" ");
        def mods:     (.modmask // "") | if type == "number" then bits(.) else tostring end;
        def keyname:  (.key // "?")    | if type == "number" then "code:\(.)" else tostring end;
        def subname:  (.submap // "")  | tostring;
        def combo:    mods + (if (mods | length) > 0 then "+" else "" end) + keyname;
        [ .[] | select(((.description // "") | tostring | length) > 0) ]
        | sort_by(subname, mods, keyname)
        | .[]
        | [ combo, ((.description // "") | tostring),
            (if subname != "" then "[" + subname + "]" else "" end) ]
        | @tsv' 2>/dev/null || true)"
fi

# fall back to the plain text listing (no jq, or older/odd JSON)
if [[ -z "$rows" ]] && command -v hyprctl >/dev/null 2>&1; then
    rows="$(hyprctl binds 2>/dev/null || true)"
fi

if [[ -z "$rows" ]]; then
    rows="$(printf 'SUPER+/\tthis menu — only works inside a Hyprland session')"
fi

printf '%s\n' "$rows" \
    | awk -F'\t' '{ printf "%-22s %-46s %s\n", $1, $2, $3 }' \
    | fuzzel --dmenu --prompt "keys ❯ " --width 78 --lines 22 \
             --placeholder "type to filter…" >/dev/null || true
