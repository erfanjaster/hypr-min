#!/usr/bin/env bash
# netmenu.sh — keyboard-driven network menu (nmcli + fuzzel).
# Replaces the resident nm-applet tray icon: same jobs, ~50 MB less RSS and no
# background wakeups. Reads the scan cache by default so the menu is instant;
# "Rescan Wi-Fi" refreshes it on demand.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
notify() { notify-send -a hypr-min -u low "network" "$1" 2>/dev/null || true; }

if ! have nmcli; then
    notify-send -a hypr-min -u critical "network" \
        "nmcli not found — install networkmanager" 2>/dev/null || true
    exit 1
fi

menu=""
add() { menu+="$(printf '%s\t%s' "$1" "$2")"$'\n'; }

# --- status line (informational only) --------------------------------------
active="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | head -1 | tr ':' ' ' || true)"
add "status" "▸ ${active:-no connection}"

# --- radio -----------------------------------------------------------------
if [[ "$(nmcli radio wifi 2>/dev/null || echo unknown)" == "enabled" ]]; then
    add "wifi-off" "󰤮  Wi-Fi: on  (turn off)"
else
    add "wifi-on" "󰤫  Wi-Fi: off  (turn on)"
fi
add "wifi-rescan" "󰑓  Rescan Wi-Fi"

# --- saved connections (NetworkManager already knows their secrets) ---------
# type is the LAST colon-separated field, so SSIDs containing ':' survive.
while IFS=$'\t' read -r name type; do
    [[ -n "$name" ]] || continue
    add "up:$name" "󰆓  Connect: $name ($type)"
done < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '
    { t = $NF; n = substr($0, 1, length($0) - length(t) - 1)
      if (t != "802-11-wireless") printf "%s\t%s\n", n, t }' || true)

# --- visible Wi-Fi networks (cached scan: instant) --------------------------
while IFS=$'\t' read -r ssid signal sec; do
    [[ -n "$ssid" ]] || continue
    bars="󰤟"
    if   (( signal >= 80 )); then bars="󰤨"
    elif (( signal >= 60 )); then bars="󰤥"
    elif (( signal >= 40 )); then bars="󰤢"
    fi
    if [[ -z "$sec" || "$sec" == "--" ]]; then
        add "wifi:$ssid" "$bars  $ssid  (open)"
    else
        # unknown network + password: let the GUI editor ask for it (never on
        # a command line, where it would be visible in `ps`)
        add "join:$ssid" "$bars  $ssid  ($sec · enter password)"
    fi
done < <(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | awk -F: '
    { s = $(NF - 1); sec = $NF
      ssid = substr($0, 1, length($0) - length(s) - length(sec) - 2)
      if (ssid == "" ) next
      if (seen[ssid]++) next
      printf "%s\t%s\t%s\n", ssid, s, sec }' || true)

add "editor" "⚙  Network settings…"

choice="$(printf '%s' "$menu" | fuzzel --dmenu --with-nth 2 --prompt "net ❯ " \
          --width 60 --lines 16)" || exit 0
[[ -n "$choice" ]] || exit 0

action="${choice%%$'\t'*}"
arg="${action#*:}"

case "$action" in
    wifi-on)     nmcli radio wifi on  >/dev/null && notify "Wi-Fi radio on" ;;
    wifi-off)    nmcli radio wifi off >/dev/null && notify "Wi-Fi radio off" ;;
    wifi-rescan) nmcli device wifi list --rescan yes >/dev/null 2>&1 || true
                 exec "$0" ;;
    up:*)        if nmcli connection up "$arg" >/dev/null 2>&1; then
                     notify "connected: $arg"
                 else
                     notify "could not connect: $arg"
                 fi ;;
    wifi:*)      if nmcli device wifi connect "$arg" >/dev/null 2>&1; then
                     notify "connected: $arg"
                 else
                     notify "could not connect: $arg"
                 fi ;;
    join:*|editor) nm-connection-editor >/dev/null 2>&1 & ;;
    *)           exit 0 ;;
esac
