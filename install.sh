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
    sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,2\}//'
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
    network-manager-applet
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

# desktops have no battery: drop the waybar battery module (keeps JSON valid)
if ! ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    info "no battery detected — removing waybar battery module"
    run sed -i 's/"battery", //' "$CONFIG_HOME/waybar/config"
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

  Essentials
    SUPER+Return   terminal          SUPER+D        app launcher
    SUPER+Q        close window      SUPER+SHIFT+Q  kill window
    SUPER+1..0     workspaces        SUPER+SHIFT+1..0  move window
    SUPER+arrows/HJKL  focus         SUPER+SHIFT+…  move window
    SUPER+CTRL+arrows  resize        SUPER+mouse    drag / resize
    ALT+Tab        cycle windows     SUPER+Tab      prev workspace
    SUPER+F / SHIFT+F  fullscreen / maximize
    SUPER+S        scratchpad        SUPER+SHIFT+S  send to scratchpad
    SUPER+V        clipboard history SUPER+L        lock screen
    SUPER+X        power menu        SUPER+R        reload config
    Print          screenshot        SHIFT+Print    region shot
    ALT+Print      window shot       3-finger swipe switch workspace

  Personalize
    ~/.config/hypr/user.lua     binds, monitors, extras (update-safe)
    ~/.config/hypr/hyprland.lua the full config (commented)

  Enjoy your calm desktop. ✦
EOF
