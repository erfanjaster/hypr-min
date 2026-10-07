-- ============================================================================
--  hypr-min — a minimal, fast, no-nonsense Hyprland setup (Hyprland 0.56+)
--  Theme: "Graphite & Gold"  ·  bg #121417 · surface #1A1D23 · text #E6E9EF
--                              accent #E6B450 · accent2 #D77A61 · muted #8B93A1
--  Everything is deliberately small: few daemons, no plugins, no bloat.
--  Personal tweaks go in user.lua (loaded last, survives updates).
-- ============================================================================

---------------------
---- 1. MONITORS ----
---------------------
-- Fallback rule: any monitor, preferred mode, auto-placed.
-- Need something specific? Add rules in user.lua, e.g.:
--   hl.monitor({ output = "eDP-1", mode = "2560x1440@165", scale = 1.5 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-------------------------------
---- 2. ENVIRONMENT VARS ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-------------------
---- 3. PROGRAMS --
-------------------
local HOME    = os.getenv("HOME") or "/root"
local CFG     = HOME .. "/.config/hypr"
local SCRIPTS = CFG .. "/scripts"

local terminal = "kitty"
local launcher = "fuzzel"

------------------
---- 4. AUTOSTART
------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")                                      -- wallpaper
    hl.exec_cmd("waybar")                                         -- status bar
    hl.exec_cmd("mako")                                           -- notifications
    hl.exec_cmd("hypridle")                                       -- idle / dpms
    hl.exec_cmd("hyprpolkitagent")                                -- privilege prompts
    hl.exec_cmd("command -v nm-applet >/dev/null && nm-applet")   -- wifi/bt tray
    hl.exec_cmd("wl-paste --type text --watch cliphist store")    -- clipboard history
end)

----------------------------
---- 5. LOOK AND FEEL ----
----------------------------
hl.config({
    general = {
        gaps_in       = 6,
        gaps_out      = 12,
        border_size   = 2,
        resize_on_border = true,   -- drag window borders with the mouse
        layout        = "dwindle",
        col = {
            active_border   = { colors = { "#E6B450EE", "#D77A61EE" }, angle = 45 },
            inactive_border = "#2E333DCC",
        },
        snap = { enabled = true }, -- floating windows snap to edges/gaps
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = false },          -- no shadows: cheaper, cleaner
        blur = {                               -- blur only applies to layers
            enabled  = true,                   -- that opt in via layer rules
            size     = 6,                      -- (bar + notifications)
            passes   = 1,
            vibrancy = 0.2,
        },
    },

    animations = { enabled = true },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        repeat_delay = 400,
        repeat_rate  = 40,
        numlock_by_default = true,
        touchpad = {
            tap_to_click         = true,
            disable_while_typing = true,
            natural_scroll       = false,
        },
    },

    misc = {
        disable_hyprland_logo  = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,      -- no bundled anime art
        background_color       = "#121417",
        font_family            = "Inter",
        enable_swallow         = true,    -- GUI apps swallow their terminal
        swallow_regex          = "^(kitty)$",
        focus_on_activate      = true,
        key_press_enables_dpms  = true,   -- wake screen on any input
        mouse_move_enables_dpms = true,
    },

    dwindle = { preserve_split = true },

    binds = {
        workspace_back_and_forth = 1,     -- SUPER+n twice = back
        allow_workspace_cycles   = true,
    },

    ecosystem = {
        no_update_news = true,            -- work machine: no popups
    },
})

-- frosted glass on the bar and notifications only (tiny blurred areas)
hl.layer_rule({ match = { namespace = "waybar" },       blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.3 })

----------------------
---- 6. ANIMATIONS ---
----------------------
hl.curve("smooth", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("snappy", { type = "bezier", points = { { 0.2, 0.9 },  { 0.25, 1.0 } } })

hl.animation({ leaf = "global",     enabled = true, speed = 6, bezier = "smooth" })
hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "smooth", style = "popin 92%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3, bezier = "snappy" })
hl.animation({ leaf = "layers",     enabled = true, speed = 3, bezier = "smooth", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "smooth", style = "slide" })
hl.animation({ leaf = "border",     enabled = true, speed = 6, bezier = "smooth" })

-----------------------
---- 7. KEYBINDINGS ---
-----------------------
local M = "SUPER"

-- apps
hl.bind(M .. " + Return", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind(M .. " + D",      hl.dsp.exec_cmd(launcher), { description = "App launcher" })

-- windows
hl.bind(M .. " + Q",        hl.dsp.window.close(), { description = "Close window" })
hl.bind(M .. " + SHIFT + Q", hl.dsp.window.kill(), { description = "Kill window" })
hl.bind(M .. " + SHIFT + Space", hl.dsp.window.float(), { description = "Toggle floating" })
hl.bind(M .. " + C",        hl.dsp.window.center(), { description = "Center floating window" })
hl.bind(M .. " + SHIFT + P", hl.dsp.window.pin(), { description = "Pin window to all workspaces" })
hl.bind(M .. " + F",        hl.dsp.window.fullscreen({ action = "toggle" }), { description = "Fullscreen" })
hl.bind(M .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }), { description = "Maximize" })

-- focus / move (arrows everywhere; H/J/K = vim left/down/up.
-- L is intentionally left free: SUPER+L locks the screen)
for _, d in ipairs({ { "left", "H" }, { "down", "J" }, { "up", "K" }, { "right", nil } }) do
    hl.bind(M .. " + " .. d[1], hl.dsp.focus({ direction = d[1] }))
    hl.bind(M .. " + SHIFT + " .. d[1], hl.dsp.window.move({ direction = d[1] }))
    hl.bind(M .. " + CTRL + " .. d[1], hl.dsp.window.resize({
        x = (d[1] == "left" and -40 or d[1] == "right" and 40 or 0),
        y = (d[1] == "up"   and -40 or d[1] == "down"  and 40 or 0),
        relative = true }), { repeating = true })
    if d[2] then
        hl.bind(M .. " + " .. d[2],        hl.dsp.focus({ direction = d[1] }))
        hl.bind(M .. " + SHIFT + " .. d[2], hl.dsp.window.move({ direction = d[1] }))
    end
end

-- workspaces 1-9,0 (+ SHIFT = take window along)
for i = 1, 10 do
    local key = i % 10
    hl.bind(M .. " + " .. key,        hl.dsp.focus({ workspace = i }))
    hl.bind(M .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(M .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(M .. " + Tab",        hl.dsp.focus({ workspace = "previous" }), { description = "Previous workspace" })

-- scratchpad (special workspace)
hl.bind(M .. " + S",         hl.dsp.workspace.toggle_special("scratch"), { description = "Scratchpad" })
hl.bind(M .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }))

-- window cycling (alt-tab style)
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end, { description = "Cycle windows" })

-- drag / resize with the mouse
hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- system / session
hl.bind(M .. " + L", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true, description = "Lock screen" })
hl.bind(M .. " + X", hl.dsp.exec_cmd(SCRIPTS .. "/powermenu.sh"), { description = "Power menu" })
hl.bind(M .. " + R", hl.dsp.reload_config(), { description = "Reload config" })
hl.bind(M .. " + V", hl.dsp.exec_cmd(SCRIPTS .. "/clipboard.sh"), { description = "Clipboard history" })

-- screenshots: Print = full, Shift+Print = region, Alt+Print = active window
hl.bind("Print",        hl.dsp.exec_cmd(SCRIPTS .. "/screenshot.sh full"),   { description = "Screenshot: full" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(SCRIPTS .. "/screenshot.sh region"), { description = "Screenshot: region" })
hl.bind("ALT + Print",  hl.dsp.exec_cmd(SCRIPTS .. "/screenshot.sh window"), { description = "Screenshot: window" })

-- media keys (work even on the lock screen)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- touchpad: 3-finger horizontal swipe switches workspaces
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---------------------
---- 8. RULES -------
---------------------
-- apps politely asking to be maximized: ignored (the tiling layout decides)
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- dialogs and small utilities float centered
hl.window_rule({ name = "float-modal",   match = { modal = true }, float = true, center = true })
hl.window_rule({ name = "float-utilities", match = { class = "^(pavucontrol|Nm-connection-editor|nm-connection-editor|blueman-manager|hyprpolkitagent)$" }, float = true, center = true })

-- firefox picture-in-picture floats and stays visible
hl.window_rule({ name = "pip", match = { title = "Picture-in-Picture" }, float = true, pin = true })

-- video players keep the screen awake
hl.window_rule({ name = "idle-inhibit-video", match = { class = "^(mpv|celluloid)$" }, idle_inhibit = "always" })

-- classic XWayland drag fix
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

------------------------
---- 9. USER OVERRIDES --
------------------------
-- ~/.config/hypr/user.lua is yours: extra binds, monitors, themes, …
-- Loaded with pcall so a broken user.lua can never kill the session.
local ok, err = pcall(require, "user")
if not ok then
    print("hypr-min: user.lua failed to load: " .. tostring(err))
end
