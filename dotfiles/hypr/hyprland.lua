-- ============================================================================
--  hypr-min — a minimal, fast, no-nonsense Hyprland setup (Hyprland 0.56+)
--  Theme: "Graphite & Gold"  ·  bg #121417 · surface #1A1D23 · text #E6E9EF
--                              accent #E6B450 · accent2 #D77A61 · muted #8B93A1
--
--  Rules this config lives by (everything below follows from them):
--    1. no resident process that a keybind can replace   (menus are on-demand)
--    2. no polling where an event exists                 (IPC / udev / D-Bus)
--    3. no fork where the compositor can do it           (hl.timer, hl.config)
--    4. every bind carries a `description`               → SUPER+/ = live cheat sheet
--    5. heavy looks only where they are cheap            (blur on 2 thin layers)
--    6. personal tweaks go in user.lua (loaded last, survives updates)
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
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")   -- portals (screen-share, file picker)
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")  -- Java/AWT windows on a tiling WM
hl.env("TERMINAL", "kitty")                 -- scripts honour $TERMINAL

-------------------
---- 3. HELPERS --
-------------------
local HOME    = os.getenv("HOME") or "/root"
local CFG     = HOME .. "/.config/hypr"
local SCRIPTS = CFG .. "/scripts"

local terminal = "kitty"
local launcher = "fuzzel"

-- POSIX-safe single quoting, for the few commands we build at runtime.
local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- Toast: a normal desktop notification through mako (themed, one tiny fork,
-- only on explicit user action — never in a loop, never on a timer).
local function toast(text, ms)
    hl.dispatch(hl.dsp.exec_cmd(
        "notify-send -a hypr-min -u low -t " .. tostring(ms or 1800) .. " " .. shq(text)))
end

-- Run something later, off the input path. Setting DPMS straight from a bind
-- is explicitly discouraged upstream (the key release can wake the screen
-- again), so the helper degrades to "immediately" only if timers are missing.
local function later(fn, ms)
    if type(hl.timer) == "function" then
        if pcall(hl.timer, fn, { timeout = ms or 400, type = "oneshot" }) then return end
    end
    fn()
end

-- Start a helper only if it is not already running: keeps reloaded configs and
-- second sessions from stacking duplicate daemons (RAM + wakeups).
local function spawn_once(proc, cmd)
    hl.exec_cmd("pgrep -x " .. shq(proc) .. " >/dev/null 2>&1 || " .. cmd)
end

-- One of our small scripts (see dotfiles/hypr/scripts/).
local function script(name, args)
    return hl.dsp.exec_cmd(SCRIPTS .. "/" .. name .. (args and " " .. args or ""))
end

-- Bind inside a submap and leave the submap right after — so a "tools" menu
-- never traps the keyboard.
local function tool(keys, action, desc)
    hl.bind(keys, function()
        if type(action) == "function" then action() else hl.dispatch(action) end
        hl.dispatch(hl.dsp.submap("reset"))
    end, { description = desc })
end

------------------
---- 4. AUTOSTART
------------------
hl.on("hyprland.start", function()
    spawn_once("hyprpaper",       "hyprpaper")                                    -- wallpaper
    spawn_once("waybar",          "waybar")                                       -- status bar
    spawn_once("mako",            "mako")                                         -- notifications
    spawn_once("hypridle",        "hypridle")                                     -- idle / dpms
    spawn_once("hyprpolkitagent", "hyprpolkitagent")                              -- admin prompts
    spawn_once("wl-paste",        "wl-paste --type text --watch cliphist store")  -- clipboard history

    -- Deliberately NOT started: nm-applet. A resident GTK tray applet costs
    -- ~40-60 MB RSS and a wakeup per network event; the bar's network pill and
    -- SUPER+N (netmenu) cover the same ground. Want the tray icon anyway?
    -- Put this in user.lua:
    --   hl.on("hyprland.start", function()
    --       hl.exec_cmd("pgrep -x nm-applet >/dev/null || nm-applet &")
    --   end)
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
        dim_inactive     = false,            -- no full-screen dimming pass
        shadow = { enabled = false },        -- no shadows: cheaper, cleaner
        blur = {                             -- blur only for the two thin
            enabled  = true,                 -- layers that opt in below
            size     = 4,                    -- (bar + notifications).
            passes   = 1,                    -- size 4 / 1 pass is the cheap
            vibrancy = 0.2,                  -- end of "still looks frosted".
            new_optimizations = true,
            xray     = true,                 -- skip blur work behind opaque content
            special  = false,                -- never blur behind the scratchpad
            popups   = false,                -- never blur menus/popups
        },
    },

    animations = { enabled = true },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        repeat_delay = 400,
        repeat_rate  = 40,
        numlock_by_default = true,
        resolve_binds_by_sym = false,   -- binds stay on the FIRST layout, so a
                                        -- Persian/Russian layout never breaks them
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
        -- interactive move/resize without animation: fewer frames, no rubber-band
        animate_manual_resizes        = false,
        animate_mouse_windowdragging  = false,
    },

    dwindle = {
        preserve_split = true,   -- required for the `togglesplit` layout message
    },

    binds = {
        workspace_back_and_forth = 1,     -- SUPER+n twice = back
        allow_workspace_cycles   = true,
        scroll_event_delay       = 90,    -- SUPER+scroll feels instant (default 300)
        hide_special_on_workspace_change = true,
        movefocus_cycles_groupfirst = true, -- arrows walk group tabs first
        allow_pin_fullscreen     = true,  -- pinned windows may go fullscreen
    },

    group = {                             -- themed tabs (default is neon yellow)
        col = {
            border_active          = "#E6B450AA",
            border_inactive        = "#2E333DAA",
            border_locked_active   = "#D77A61AA",
            border_locked_inactive = "#2E333DAA",
        },
        groupbar = {
            enabled       = true,
            height        = 12,
            font_size     = 9,
            gradients     = false,        -- flat = fewer shader ops
            render_titles = true,
            text_color    = "#E6E9EFFF",
            col = {
                active           = "#E6B450CC",
                inactive         = "#2E333DCC",
                locked_active    = "#D77A61CC",
                locked_inactive  = "#2E333DCC",
            },
        },
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

-- apps ------------------------------------------------------------------
hl.bind(M .. " + Return", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind(M .. " + D",      hl.dsp.exec_cmd(launcher), { description = "App launcher" })
hl.bind(M .. " + Space",  hl.dsp.exec_cmd(launcher), { description = "App launcher (alt)" })
hl.bind(M .. " + W",      script("app.sh", "browser"), { description = "Web browser" })
hl.bind(M .. " + E",      script("app.sh", "files"),   { description = "File manager" })

-- on-demand menus & helpers (no daemon behind any of them) --------------
hl.bind(M .. " + V",      script("clipboard.sh"), { description = "Clipboard history" })
hl.bind(M .. " + N",      script("netmenu.sh"),   { description = "Network menu" })
hl.bind(M .. " + A",      script("audiomenu.sh"), { description = "Audio output/input menu" })
hl.bind(M .. " + I",      script("sysinfo.sh"),   { description = "System info" })
hl.bind(M .. " + Slash",  script("keybinds.sh"),  { submap_universal = true,
                          description = "Keybind cheat sheet" })
hl.bind(M .. " + X",      script("powermenu.sh"), { description = "Power menu" })
hl.bind(M .. " + U",      script("updates.sh", "check-notify"), { description = "Check for updates" })
hl.bind(M .. " + SHIFT + U", script("updates.sh", "run"),       { description = "System update (terminal)" })
hl.bind(M .. " + T",      hl.dsp.submap("tools"),  { description = "Tools menu (submap)" })
hl.bind(M .. " + SHIFT + R", hl.dsp.submap("resize"), { description = "Resize mode (submap)" })
hl.bind(M .. " + Escape", hl.dsp.submap("reset"),  { submap_universal = true,
                          description = "Leave any submap" })
hl.bind(M .. " + B", hl.dsp.exec_cmd("pkill -SIGUSR1 -x waybar"),
                     { description = "Hide/show the bar" })

-- windows ---------------------------------------------------------------
hl.bind(M .. " + Q",        hl.dsp.window.close(), { description = "Close window" })
hl.bind(M .. " + SHIFT + Q", hl.dsp.window.kill(), { description = "Kill window" })
hl.bind(M .. " + SHIFT + Space", hl.dsp.window.float(), { description = "Toggle floating" })
hl.bind(M .. " + C",        hl.dsp.window.center(), { description = "Center floating window" })
hl.bind(M .. " + SHIFT + P", hl.dsp.window.pin(), { description = "Pin window to all workspaces" })
hl.bind(M .. " + F",        hl.dsp.window.fullscreen({ action = "toggle" }), { description = "Fullscreen" })
hl.bind(M .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }), { description = "Maximize" })
hl.bind(M .. " + P",        hl.dsp.window.pseudo(), { description = "Pseudo-tiling (dwindle)" })
hl.bind(M .. " + Backslash", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })
hl.bind(M .. " + SHIFT + Backslash", hl.dsp.layout("swapsplit"), { description = "Swap split halves" })

-- groups (tabbed containers) -------------------------------------------
hl.bind(M .. " + G",        hl.dsp.group.toggle(), { description = "Toggle group (tabs)" })
hl.bind(M .. " + SHIFT + G", hl.dsp.group.next(),  { description = "Next tab in group" })
hl.bind(M .. " + CTRL + G",  hl.dsp.group.prev(),  { description = "Previous tab in group" })

-- focus / move (arrows everywhere; H/J/K = vim left/down/up.
-- L is intentionally left free: SUPER+L locks the screen)
for _, d in ipairs({ { "left", "H" }, { "down", "J" }, { "up", "K" }, { "right", nil } }) do
    local dir = d[1]
    hl.bind(M .. " + " .. dir, hl.dsp.focus({ direction = dir }),
        { description = "Focus " .. dir })
    hl.bind(M .. " + SHIFT + " .. dir,
        hl.dsp.window.move({ direction = dir, group_aware = true }),
        { description = "Move window " .. dir })
    hl.bind(M .. " + CTRL + " .. dir, hl.dsp.window.resize({
        x = (dir == "left" and -40 or dir == "right" and 40 or 0),
        y = (dir == "up"   and -40 or dir == "down"  and 40 or 0),
        relative = true }), { repeating = true, description = "Resize " .. dir })
    if d[2] then
        hl.bind(M .. " + " .. d[2], hl.dsp.focus({ direction = dir }),
            { description = "Focus " .. dir .. " (vim)" })
        hl.bind(M .. " + SHIFT + " .. d[2],
            hl.dsp.window.move({ direction = dir, group_aware = true }),
            { description = "Move window " .. dir .. " (vim)" })
    end
end

-- workspaces 1-9,0 · SHIFT = send window · CTRL = send window and follow
for i = 1, 10 do
    local key = i % 10
    hl.bind(M .. " + " .. key, hl.dsp.focus({ workspace = i }),
        { description = "Workspace " .. key })
    hl.bind(M .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
        { description = "Send window to workspace " .. key })
    hl.bind(M .. " + CTRL + " .. key,
        hl.dsp.window.move({ workspace = i, follow = true }),
        { description = "Send window to workspace " .. key .. " and follow" })
end
hl.bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace (scroll)" })
hl.bind(M .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace (scroll)" })
hl.bind(M .. " + Tab",        hl.dsp.focus({ workspace = "previous" }), { description = "Previous workspace" })
hl.bind(M .. " + SHIFT + Tab", hl.dsp.focus({ urgent_or_last = true }), { description = "Focus urgent/last window" })

-- multi-monitor ---------------------------------------------------------
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(M .. " + ALT + " .. dir, hl.dsp.focus({ monitor = dir }),
        { description = "Focus monitor " .. dir })
    hl.bind(M .. " + SHIFT + ALT + " .. dir, hl.dsp.window.move({ monitor = dir }),
        { description = "Move window to monitor " .. dir })
    hl.bind(M .. " + CTRL + ALT + " .. dir, hl.dsp.workspace.move({ monitor = dir }),
        { description = "Move workspace to monitor " .. dir })
end

-- scratchpad (special workspace) ---------------------------------------
hl.bind(M .. " + S",         hl.dsp.workspace.toggle_special("scratch"), { description = "Scratchpad" })
hl.bind(M .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }), { description = "Send window to scratchpad" })
hl.bind(M .. " + SHIFT + Return", function()
    hl.dispatch(hl.dsp.exec_cmd(terminal .. " --class kitty-scratch"))
    hl.dispatch(hl.dsp.focus({ workspace = "special:scratch" }))
end, { description = "New scratchpad terminal" })

-- window cycling (alt-tab style) ---------------------------------------
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end, { description = "Cycle windows" })

-- media on the keyboard, without the media keys -------------------------
hl.bind(M .. " + M",      hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind(M .. " + Comma",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Previous track" })
hl.bind(M .. " + Period", hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next track" })

-- drag / resize with the mouse -----------------------------------------
hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag window (mouse)" })
hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window (mouse)" })

-- system / session ------------------------------------------------------
hl.bind(M .. " + L", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true, description = "Lock screen" })
hl.bind(M .. " + R", hl.dsp.reload_config(), { description = "Reload config" })
hl.bind(M .. " + SHIFT + I", script("idle.sh", "toggle"), { description = "Toggle idle + auto-lock" })
hl.bind(M .. " + SHIFT + N", hl.dsp.exec_cmd("makoctl dismiss --all"), { description = "Dismiss all notifications" })
hl.bind(M .. " + SHIFT + O", function()
    toast("Screen off — any input wakes it")
    later(function() hl.dispatch(hl.dsp.dpms({ action = "disable" })) end, 500)
end, { locked = true, description = "Screen off (DPMS)" })

-- screenshots: save to ~/Pictures/Screenshots *and* the clipboard.
-- SUPER variants copy only — nothing touches the disk.
hl.bind("Print",             script("screenshot.sh", "full"),      { description = "Screenshot: full screen" })
hl.bind("SHIFT + Print",     script("screenshot.sh", "region"),    { description = "Screenshot: region" })
hl.bind("ALT + Print",       script("screenshot.sh", "window"),    { description = "Screenshot: active window" })
hl.bind(M .. " + Print",     script("screenshot.sh", "clip"),      { description = "Screenshot: region to clipboard" })
hl.bind(M .. " + SHIFT + Print", script("screenshot.sh", "clip-full"), { description = "Screenshot: screen to clipboard" })

-- hardware keys (work even on the lock screen; hold to repeat, SHIFT = fine) --
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Volume down" })
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+"), { locked = true, repeating = true, description = "Volume up (fine)" })
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"),      { locked = true, repeating = true, description = "Volume down (fine)" })
hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true, description = "Mute output" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Mute microphone" })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "Brightness down" })
hl.bind("SHIFT + XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 1%+"), { locked = true, repeating = true, description = "Brightness up (fine)" })
hl.bind("SHIFT + XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 1%-"), { locked = true, repeating = true, description = "Brightness down (fine)" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause (media key)" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Pause (media key)" })
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("playerctl stop"),       { locked = true, description = "Stop (media key)" })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next track (media key)" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Previous track (media key)" })
hl.bind("XF86Sleep",      hl.dsp.exec_cmd("systemctl suspend"),    { locked = true, description = "Suspend (sleep key)" })
hl.bind("XF86Explorer",   script("app.sh", "files"),               { description = "File manager (explorer key)" })
hl.bind("XF86Search",     hl.dsp.exec_cmd(launcher),               { description = "App launcher (search key)" })

-- submap: tools — one keystroke from anywhere, then a single letter -------
local LAYOUTS  = { "dwindle", "master" }   -- switched live from inside `tools`
local layout_i = 1

hl.define_submap("tools", function()
    tool("t", hl.dsp.exec_cmd(terminal),          "[tools] Terminal")
    tool("b", script("app.sh", "browser"),        "[tools] Web browser")
    tool("f", script("app.sh", "files"),          "[tools] File manager")
    tool("e", script("app.sh", "editor"),         "[tools] Text editor")
    tool("n", script("netmenu.sh"),               "[tools] Network menu")
    tool("a", script("audiomenu.sh"),             "[tools] Audio menu")
    tool("v", script("clipboard.sh"),             "[tools] Clipboard history")
    tool("s", script("screenshot.sh", "region"),  "[tools] Screenshot region")
    tool("i", script("sysinfo.sh"),               "[tools] System info")
    tool("p", hl.dsp.exec_cmd("pavucontrol"),     "[tools] Volume mixer")
    tool("k", script("keybinds.sh"),              "[tools] Keybind cheat sheet")
    tool("u", script("updates.sh", "run"),        "[tools] System update")
    tool("l", hl.dsp.exec_cmd("loginctl lock-session"), "[tools] Lock screen")
    tool("x", script("powermenu.sh"),             "[tools] Power menu")
    tool("m", function()                          -- dwindle <-> master, live
        layout_i = layout_i % #LAYOUTS + 1
        hl.config({ general = { layout = LAYOUTS[layout_i] } })
        toast("Layout: " .. LAYOUTS[layout_i])
    end, "[tools] Switch layout (dwindle/master)")
    for _, k in ipairs({ "Escape", "Q", "Return", "Space" }) do
        hl.bind(k, hl.dsp.submap("reset"), { description = "[tools] Exit" })
    end
end)

-- submap: resize — hold-free, repeating, HJKL + arrows, SHIFT = fine -----
hl.define_submap("resize", function()
    local step, fine = 60, 10
    local dirs = {
        left  = { x = -1, y =  0 }, right = { x = 1, y =  0 },
        up    = { x =  0, y = -1 }, down  = { x = 0, y =  1 },
    }
    local keys = {
        left = "left", right = "right", up = "up", down = "down",
        h = "left", l = "right", k = "up", j = "down",
    }
    for key, dir in pairs(keys) do
        local v = dirs[dir]
        for _, variant in ipairs({ { step, "" }, { fine, " (fine)" } }) do
            local delta, label = variant[1], variant[2]
            local bind_key = (delta == fine and "SHIFT + " or "") .. key
            hl.bind(bind_key, function()
                hl.dispatch(hl.dsp.window.resize({
                    x = v.x * delta, y = v.y * delta, relative = true }))
            end, { repeating = true, description = "[resize] " .. dir .. label })
        end
    end
    for _, k in ipairs({ "Escape", "Q", "Return", "Space" }) do
        hl.bind(k, hl.dsp.submap("reset"), { description = "[resize] Exit" })
    end
end)

---------------------
---- 8. GESTURES ----
---------------------
-- touchpad: 3 fingers sideways = switch workspace, 3 fingers down = scratchpad
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", action = "special", workspace_name = "scratch" })

---------------------
---- 9. RULES -------
---------------------
-- apps politely asking to be maximized: ignored (the tiling layout decides)
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- dialogs and small utilities float centered
hl.window_rule({ name = "float-modal",   match = { modal = true }, float = true, center = true })
hl.window_rule({ name = "float-utilities", match = { class = "^(pavucontrol|Nm-connection-editor|nm-connection-editor|blueman-manager|hyprpolkitagent)$" }, float = true, center = true })

-- firefox picture-in-picture floats and stays visible
hl.window_rule({ name = "pip", match = { title = "Picture-in-Picture" }, float = true, pin = true })

-- the scratchpad terminal spawned by SUPER+SHIFT+Return
hl.window_rule({ name = "scratchpad", match = { class = "^kitty-scratch$" }, workspace = "special:scratch" })

-- video players: keep the screen awake, skip alpha blending and rounding
-- (an opaque, square-cornered surface is the cheapest thing to composite)
hl.window_rule({ name = "video", match = { class = "^(mpv|celluloid|vlc|mpvtk)$" },
                 idle_inhibit = "always", opaque = true, rounding = 0 })

-- classic XWayland drag fix
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

------------------------
---- 10. USER OVERRIDES --
------------------------
-- ~/.config/hypr/user.lua is yours: extra binds, monitors, themes, …
-- Loaded with pcall so a broken user.lua can never kill the session.
local ok, err = pcall(require, "user")
if not ok then
    print("hypr-min: user.lua failed to load: " .. tostring(err))
end
