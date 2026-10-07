# hypr-min test results — 2026-10-06T23:01Z
## TEST 1 — shell static analysis (bash -n + shellcheck)
- ✔ bash -n install.sh
- ✘ shellcheck install.sh (see log below)
- ✔ bash -n clipboard.sh
- ✘ shellcheck clipboard.sh (see log below)
- ✔ bash -n powermenu.sh
- ✘ shellcheck powermenu.sh (see log below)
- ✔ bash -n screenshot.sh
- ✘ shellcheck screenshot.sh (see log below)
## TEST 2 — Lua config: syntax parse + API surface audit
- ✔ luac -p hyprland.lua
- ✔ luac -p user.lua
- ✔ execute hyprland.lua against stub hl API
- ✔ execute user.lua against stub hl API
- ✔ all scripts referenced by binds exist
- ✔ user.lua require is pcall-protected
## TEST 3 — hyprlang configs (hyprlock/hypridle/hyprpaper): schema + dpms syntax
- ✔ hyprlang lint
## TEST 4 — waybar JSON+CSS, fuzzel.ini, mako config validation
- ✔ misc lint
## TEST 5 — every package in install.sh exists in the official Arch repos
- ✘ package availability (live archlinux.org API) (see log below)
## TEST 6 — installer end-to-end simulation (desktop + laptop + update safety)
- ✔ install run #1 (desktop) exits 0
- ✔ hyprland.lua installed
- ✔ scripts executable
- ✔ wallpaper path baked in
- ✔ battery module removed (desktop)
- ✔ waybar JSON still valid after battery removal
- ✔ pacman asked for hyprland+waybar
- ✔ pacman skipped already-installed kitty
- ✔ install run #2 (update) exits 0
- ✔ backup created on update
- ✔ user.lua preserved across update
- ✔ install run (laptop) exits 0
- ✔ battery module kept (laptop)
- ✔ dry-run exits 0
- ✔ dry-run touches nothing
## TEST 7 — helper scripts functional tests (stubbed binaries)
- ✔ screenshot full: grim + wl-copy + notify called
- ✔ screenshot region: slurp geometry passed to grim
- ✔ screenshot window: hyprctl geometry parsed
- ✔ powermenu: Lock -> loginctl lock-session
- ✔ powermenu: Logout -> hyprshutdown (graceful)
- ✔ powermenu: Reboot -> systemctl reboot
- ✔ clipboard: cliphist list -> fuzzel -> decode -> wl-copy
## TEST 8 — repo hygiene (EOF newlines, CRLF, wallpaper asset, binary cross-ref)
- ✔ all text files end with newline
- ✔ no CRLF line endings
- ✘ wallpaper: valid PNG, 16:9, >=1920 wide, <5MB (see log below)
- ✔ no stray placeholders outside hyprpaper template
- ✔ every binary referenced by configs/scripts is installed by install.sh

**RESULT: 38 passed, 6 failed**
