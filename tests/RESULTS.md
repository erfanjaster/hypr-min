# hypr-min test results — 2026-10-07T12:39Z
## TEST 1 — shell static analysis (bash -n + shellcheck)
- ✔ bash -n install.sh
- ✔ shellcheck install.sh
- ✔ bash -n app.sh
- ✔ shellcheck app.sh
- ✔ bash -n audiomenu.sh
- ✔ shellcheck audiomenu.sh
- ✔ bash -n clipboard.sh
- ✔ shellcheck clipboard.sh
- ✔ bash -n idle.sh
- ✔ shellcheck idle.sh
- ✔ bash -n keybinds.sh
- ✔ shellcheck keybinds.sh
- ✔ bash -n netmenu.sh
- ✔ shellcheck netmenu.sh
- ✔ bash -n powermenu.sh
- ✔ shellcheck powermenu.sh
- ✔ bash -n screenshot.sh
- ✔ shellcheck screenshot.sh
- ✔ bash -n sysinfo.sh
- ✔ shellcheck sysinfo.sh
- ✔ bash -n updates.sh
- ✔ shellcheck updates.sh
## TEST 2 — Lua config: syntax parse + API surface audit
- ✔ luac -p hyprland.lua
- ✔ luac -p user.lua
- ✔ execute hyprland.lua against stub hl API
- ✔ execute user.lua against stub hl API
- ✔ user.lua require is pcall-protected
- ✔ registers >=100 binds (keymap not accidentally gutted)
- ✔ stub catches duplicate bind + submap trap + bad callback + bad flag
- ✔ stub reports all five problems
## TEST 3 — hyprlang configs: schema, dpms syntax, no legacy dispatchers
- ✔ hyprlang lint
- ✔ no legacy 'hyprctl dispatch <word>' anywhere
- ✔ no hyprlang bind=/bindm= directives left
## TEST 4 — waybar JSON+CSS, fuzzel.ini, mako config validation
- ✔ misc lint
## TEST 5 — keybind hygiene (descriptions, submaps, scripts, README in sync)
- ✔ bind lint
## TEST 6 — resource budget (resident processes, blur, polling, no busy loops)
- ✔ budget lint
## TEST 7 — every package in install.sh exists in the official Arch repos
- ✔ package availability (live archlinux.org API)
## TEST 8 — installer end-to-end (desktop + laptop + layouts + update safety)
- ✔ install run #1 (desktop) exits 0
- ✔ hyprland.lua installed
- ✔ user.lua installed
- ✔ all 10 helper scripts installed and executable
- ✔ wallpaper path baked in
- ✔ waybar JSON valid after pruning
- ✔ battery module dropped (desktop)
- ✔ backlight module dropped (no panel)
- ✔ temperature module dropped (no sensor)
- ✔ layout module dropped (single layout)
- ✔ group/net survives with network+pulseaudio
- ✔ group/system survives with cpu+memory
- ✔ pacman asked for hyprland+waybar+networkmanager
- ✔ pacman skipped already-installed kitty
- ✔ install run #2 (update) exits 0
- ✔ backup created on update
- ✔ user.lua preserved across update
- ✔ layout module kept for us,ir keyboard
- ✔ waybar JSON still valid after keeping layout module
- ✔ install run (laptop) exits 0
- ✔ battery module kept (laptop)
- ✔ backlight module kept (laptop)
- ✔ temperature module kept (sensor)
- ✔ laptop waybar JSON valid
- ✔ dry-run exits 0
- ✔ dry-run touches nothing
## TEST 9 — helper scripts functional tests (stubbed binaries)
- ✔ screenshot full: grim + wl-copy + notify
- ✔ screenshot region: slurp geometry passed to grim
- ✔ screenshot window: hyprctl geometry parsed
- ✔ screenshot clip: piped to clipboard, no file written
- ✔ screenshot clip-full: whole screen to clipboard
- ✔ powermenu: Lock -> loginctl lock-session
- ✔ powermenu: Log out -> hyprshutdown (graceful)
- ✔ powermenu: Reboot -> systemctl reboot
- ✔ powermenu: Screen off -> lua dpms dispatch
- ✔ clipboard: cliphist -> fuzzel -> decode -> wl-copy
- ✔ keybinds: reads live binds from hyprctl -j
- ✔ keybinds: shows SUPER+Q / Close window
- ✔ keybinds: marks submap membership
- ✔ keybinds: renders modifier words, not bitmasks
- ✔ netmenu: offers radio toggle, saved connections and scanned SSIDs
- ✔ netmenu: hides the password prompt behind the GUI editor
- ✔ netmenu: de-duplicates repeated SSIDs
- ✔ netmenu: selecting a saved connection runs nmcli connection up
- ✔ audiomenu: lists sinks and sources with the default marked
- ✔ audiomenu: selecting a sink sets it default
- ✔ updates check: i3blocks output (text + class)
- ✔ updates check-notify: tells the user how many
- ✔ updates run: opens the terminal with pacman -Syu
- ✔ sysinfo: one notification with cpu/ram/disk/uptime
- ✔ idle toggle: stops hypridle when it is running
- ✔ idle toggle: restarts hypridle detached when stopped
- ✔ app browser: launches the first installed browser
- ✔ app files: launches the first installed file manager
- ✔ app editor: falls back to $TERMINAL -e $EDITOR
- ✔ app scratch: tagged kitty for the scratchpad rule
## TEST 10 — repo hygiene (EOF newlines, CRLF, wallpaper asset, binary cross-ref)
- ✔ all text files end with newline
- ✔ no CRLF line endings
- ✔ wallpaper: valid PNG, 16:9, >=1920 wide, <5MB
- ✔ no stray placeholders outside hyprpaper template
- ✔ every binary referenced by configs/scripts is installed by install.sh

**RESULT: 98 passed, 0 failed, 0 skipped**
