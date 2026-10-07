#!/usr/bin/env bash
# ============================================================================
#  hypr-min installer — CachyOS / Arch Linux
#
#  Installs a minimal, future-proof Hyprland desktop (Lua config, 0.56+):
#    hyprland · waybar · fuzzel · mako · hyprpaper · hyprlock · hypridle
#    hyprpolkitagent · hyprshutdown · kitty · cliphist · grim/slurp
#
#  Safe to re-run: existing configs are backed up, and your personal
#  ~/.config/hypr/user.lua is preserved across updates.
#
#  The bar is fitted to the machine it lands on: modules for hardware you do
#  not have (battery, backlight, temperature sensor) are removed, and the
#  keyboard-layout pill only appears when a multi-layout kb_layout is set.
#
#  Usage: ./install.sh [--no-packages] [--dry-run] [--help]
# ============================================================================
set -euo pipefail

NAME="hypr-min"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$SCRIPT_DIR/dotfiles"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
INSTALL_PKGS=1

usage() {
    sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,2\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-packages) INSTALL_PKGS=0; shift ;;
        --dry-run)     DRY_RUN=1; shift ;;
        -h|--help)     usage ;;
        *) echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
    esac
done

info() { printf '\033[1;33m[%s]\033[0m %s\n' "$NAME" "$*"; }
run()  { if [[ $DRY_RUN -eq 1 ]]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

# ---------------------------------------------------------------- sanity ----
[[ -d "$DOTFILES/hypr" ]] || { echo "error: $DOTFILES/hypr not found (run from the repo dir)" >&2; exit 1; }

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-} ${ID_LIKE:-}" in
        *arch*|*cachyos*) ;;
        *) info "warning: this looks like a non-Arch distro (${ID:-unknown}); continuing anyway" ;;
    esac
else
    info "warning: /etc/os-release missing; continuing anyway"
fi

command -v pacman >/dev/null 2>&1 || { echo "error: pacman not found — this installer needs Arch/CachyOS" >&2; exit 1; }

SUDO_CMD=()
if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || { echo "error: need sudo (or run as root)" >&2; exit 1; }
    SUDO_CMD=(sudo)
fi

# --------------------------------------------------------------- packages ---
PKGS=(
    hyprland waybar fuzzel mako hyprpaper hyprlock hypridle
    hyprpolkitagent hyprshutdown
    kitty wl-clipboard cliphist
    grim slurp jq brightnessctl playerctl pavucontrol libnotify
    networkmanager network-manager-applet
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    qt6-wayland pipewire wireplumber polkit
    inter-font ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
    adwaita-icon-theme
)
# Qt5 wayland support only if Qt5 is already on the system (avoid pulling Qt5)
if pacman -Qq qt5-base >/dev/null 2>&1; then
    PKGS+=(qt5-wayland)
fi

if [[ $INSTALL_PKGS -eq 1 ]]; then
    missing=()
    for p in "${PKGS[@]}"; do
        pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        info "installing ${#missing[@]} packages: ${missing[*]}"
        run "${SUDO_CMD[@]}" pacman -S --needed --noconfirm "${missing[@]}"
    else
        info "all packages already installed"
    fi
else
    info "skipping package installation (--no-packages)"
fi

# ---------------------------------------------------------------- backup ----
# keep the user's personal overrides across updates (grab BEFORE backup move)
USER_LUA_KEEP="$(mktemp)"
if [[ -f "$CONFIG_HOME/hypr/user.lua" ]]; then
    cp "$CONFIG_HOME/hypr/user.lua" "$USER_LUA_KEEP"
    info "your user.lua will be preserved"
fi

for d in hypr waybar fuzzel mako kitty; do
    target="$CONFIG_HOME/$d"
    if [[ -e "$target" ]]; then
        info "backing up $target -> $target.backup-$STAMP"
        run mv "$target" "$target.backup-$STAMP"
    fi
done

# ------------------------------------------------------------------ copy ----
info "installing configs to $CONFIG_HOME"
for d in hypr waybar fuzzel mako kitty; do
    run mkdir -p "$CONFIG_HOME/$d"
    run cp -r "$DOTFILES/$d/." "$CONFIG_HOME/$d/"
done
run chmod +x "$CONFIG_HOME/hypr/scripts/"*.sh

if [[ -s "$USER_LUA_KEEP" ]]; then
    run cp "$USER_LUA_KEEP" "$CONFIG_HOME/hypr/user.lua"
fi
rm -f "$USER_LUA_KEEP"

# ------------------------------------------------- hardware adaptations ----
# wallpaper: bake the real absolute path into hyprpaper.conf
run sed -i "s|__WALLPAPER__|$CONFIG_HOME/hypr/assets/wallpaper.png|" "$CONFIG_HOME/hypr/hyprpaper.conf"

# Remove a waybar module everywhere: from the module lists, from group arrays
# and its own config block. Keeps the JSON valid in every position.
waybar_drop_module() { # $1 = module name ("battery", "custom/updates", …)
    local mod="$1" file="$CONFIG_HOME/waybar/config"
    run sed -i -e "s|\"$mod\", ||g" -e "s|, \"$mod\"||g" -e "s|\[\"$mod\"\]|[]|g" "$file"
    run sed -i -e "\|^    \"$mod\": {$|,\|^    },$|d" "$file"
}

if ! ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    info "no battery detected — dropping the waybar battery module"
    waybar_drop_module "battery"
fi

if ! ls /sys/class/backlight/* >/dev/null 2>&1; then
    info "no backlight control — dropping the waybar backlight module"
    waybar_drop_module "backlight"
fi

if ! ls /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp >/dev/null 2>&1; then
    info "no temperature sensor — dropping the waybar temperature module"
    waybar_drop_module "temperature"
fi

# the layout pill is noise on a single-layout keyboard
# (commented-out examples in user.lua must not count — strip Lua comments first)
if ! cat "$CONFIG_HOME/hypr/hyprland.lua" "$CONFIG_HOME/hypr/user.lua" 2>/dev/null \
        | grep -vE '^[[:space:]]*--' \
        | grep -qE 'kb_layout[[:space:]]*=[[:space:]]*"[^"]+,[^"]+"'; then
    info "single keyboard layout — dropping the waybar layout module"
    waybar_drop_module "hyprland/language"
fi

# --------------------------------------------------------------- summary ----
if [[ $DRY_RUN -eq 1 ]]; then
    info "dry run finished — nothing was changed"
    exit 0
fi

cat <<'EOF'

  ┌──────────────────────────────────────────────────────────────┐
  │  hypr-min installed. Log out, pick "Hyprland" in SDDM.        │
  └──────────────────────────────────────────────────────────────┘

  Everyday
    SUPER+Return   terminal          SUPER+D / SUPER+Space  app launcher
    SUPER+W        browser           SUPER+E                file manager
    SUPER+Q        close window      SUPER+SHIFT+Q          kill window
    SUPER+1..0     workspaces        SUPER+SHIFT+1..0  send window
    SUPER+CTRL+1..0  send window and follow
    SUPER+arrows/HJK   focus         SUPER+SHIFT+…    move window
    SUPER+CTRL+arrows  resize        SUPER+mouse      drag / resize
    ALT+Tab        cycle windows     SUPER+Tab        previous workspace

  Windows
    SUPER+F / SHIFT+F  fullscreen / maximize      SUPER+P  pseudo-tiling
    SUPER+SHIFT+Space  float        SUPER+C        center floating window
    SUPER+SHIFT+P      pin to all workspaces
    SUPER+G            group (tabs) SUPER+SHIFT/CTRL+G  next/prev tab
    SUPER+\            toggle split SUPER+SHIFT+\  swap split halves
    SUPER+S            scratchpad   SUPER+SHIFT+S  send window there
                                   SUPER+SHIFT+Return  new scratch terminal

  Menus & helpers (all on-demand, nothing resident)
    SUPER+/          every keybind, searchable     SUPER+T  tools submap
    SUPER+SHIFT+R    resize mode (HJKL, SHIFT=fine, ESC=exit)
    SUPER+V          clipboard history             SUPER+N  network menu
    SUPER+A          audio output/input menu       SUPER+I  system info
    SUPER+U          check updates                 SUPER+SHIFT+U  update now
    SUPER+B          hide/show the bar             SUPER+M , .  play/pause, prev, next
    SUPER+SHIFT+I    freeze idle + auto-lock       SUPER+SHIFT+O  screen off
    SUPER+SHIFT+N    dismiss all notifications     SUPER+X  power menu
    SUPER+L          lock screen                   SUPER+R  reload config

  Screenshots
    Print  full      SHIFT+Print  region      ALT+Print  active window
    SUPER+Print  region → clipboard only      SUPER+SHIFT+Print  screen → clipboard

  Hardware keys work as usual (volume, brightness, media) — also on the lock
  screen, and SHIFT+ them for fine steps. 3-finger swipe switches workspaces.

  Personalize
    ~/.config/hypr/user.lua     binds, monitors, extras (update-safe)
    ~/.config/hypr/hyprland.lua the full config (commented)

  Enjoy your calm desktop. ✦
EOF
