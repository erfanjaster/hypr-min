#!/usr/bin/env bash
# sysinfo.sh — one notification with the numbers you actually look for.
# Reads /proc, /sys, df and ip directly: no neofetch, no fastfetch, no daemon.
set -euo pipefail

ncpu="$(nproc 2>/dev/null || echo 1)"
read -r load1 _ < /proc/loadavg

cpu="$(awk -v l="$load1" -v n="$ncpu" \
        'BEGIN { printf "%3d%%  (load %s / %d cores)", (l / n) * 100, l, n }')"

mem="$(awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 }
           END { u = t - a
                 printf "%.1f G / %.1f G  (%d%%)", u/1048576, t/1048576, (u/t)*100 }' \
        /proc/meminfo)"

disk="$(df -h / 2>/dev/null | awk 'NR == 2 { printf "%s used of %s  (%s)", $3, $2, $5 }')"

up="$(awk '{ s = int($1); d = int(s/86400); h = int(s%86400/3600); m = int(s%3600/60)
            if (d)      printf "%dd %dh", d, h
            else if (h) printf "%dh %dm", h, m
            else        printf "%dm", m }' /proc/uptime)"

bat=""
for p in /sys/class/power_supply/BAT*; do
    [[ -e "$p/capacity" ]] || continue
    bat+="$(printf '%s%% %s' "$(cat "$p/capacity")" "$(cat "$p/status" 2>/dev/null || echo '?')") "
done

net="$(ip -4 -o addr show scope global 2>/dev/null | awk '{ print $4 }' \
       | cut -d/ -f1 | paste -sd, - || true)"

pkgs=""
if command -v pacman >/dev/null 2>&1; then
    pkgs="$(pacman -Qq 2>/dev/null | wc -l | tr -d ' ') packages · "
fi

body="$(printf 'CPU     %s\nRAM     %s\nDisk /  %s\nUptime  %s' \
        "$cpu" "$mem" "${disk:-unknown}" "$up")"
if [[ -n "$bat" ]]; then body+="$(printf '\nBattery %s' "${bat% }")"; fi
if [[ -n "$net" ]]; then body+="$(printf '\nIP      %s' "$net")"; fi
body+="$(printf '\n%skernel %s' "$pkgs" "$(uname -r)")"

notify-send -a hypr-min -u low -t 8000 "${HOSTNAME:-system}" "$body"
