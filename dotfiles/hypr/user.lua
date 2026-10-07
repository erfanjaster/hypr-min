-- ============================================================================
--  user.lua — your personal tweaks. This file is NEVER overwritten by the
--  installer, so updates to hypr-min can't clobber your changes.
--  Everything below is optional; delete what you don't need.
--
--  Loaded last, inside pcall(): a syntax error here can print a warning but
--  can never kill your session. Docs: https://wiki.hypr.land/configuring/
--
--  TIP: give every bind you add a `description` — then it shows up in the
--  live cheat sheet (SUPER+/) automatically. Nothing else to maintain.
-- ============================================================================

--------------------------------------------------------------------------------
-- Keyboard layout (Persian users): uncomment to get English + Persian with
-- Alt+Shift switching. Hyprland binds stay on the FIRST layout (us) because
-- hyprland.lua sets input.resolve_binds_by_sym = false.
-- Re-run ./install.sh afterwards: the bar's layout pill is only installed when
-- a multi-layout kb_layout is detected.
--------------------------------------------------------------------------------
-- hl.config({
--     input = {
--         kb_layout  = "us,ir",
--         kb_options = "grp:alt_shift_toggle",
--     },
-- })

--------------------------------------------------------------------------------
-- Monitor examples
--------------------------------------------------------------------------------
-- hl.monitor({ output = "eDP-1",  mode = "2560x1440@165", scale = 1.5 })
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "2560x0" })
-- hl.monitor({ output = "DP-2", disabled = true })

--------------------------------------------------------------------------------
-- Extra keybind examples
--------------------------------------------------------------------------------
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"), { description = "Browser" })
-- hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"),  { description = "Files" })

-- A direct dwindle/master switch, if you use it more than the tools menu does:
-- local LAYOUTS, i = { "dwindle", "master" }, 1
-- hl.bind("SUPER + SHIFT + L", function()
--     i = i % #LAYOUTS + 1
--     hl.config({ general = { layout = LAYOUTS[i] } })
-- end, { description = "Switch layout" })

-- Master layout messages (only meaningful while layout = "master"):
-- hl.bind("SUPER + CTRL + Return", hl.dsp.layout("swapwithmaster"), { description = "Swap with master" })
-- hl.bind("SUPER + CTRL + M",      hl.dsp.layout("focusmaster"),    { description = "Focus master" })
-- hl.bind("SUPER + CTRL + Right",  hl.dsp.layout("orientationnext"),{ description = "Rotate master" })

-- Touchpad accessibility: 2-finger pinch zooms the screen around the cursor.
-- Off by default because browsers use the same pinch for page zoom.
-- hl.gesture({ fingers = 2, direction = "pinch", action = "cursor_zoom", zoom_level = 2 })

-- Laptop lid: lock (or suspend) when the lid closes. Find your switch name
-- with `hyprctl devices`, then:
-- hl.bind("switch:on:[Lid Switch]", hl.dsp.exec_cmd("loginctl lock-session"),
--         { locked = true, description = "Lid closed: lock" })

--------------------------------------------------------------------------------
-- Bring back the network tray applet (hypr-min skips it on purpose: a resident
-- GTK applet is ~40-60 MB RSS and the bar + SUPER+N already cover networks)
--------------------------------------------------------------------------------
-- hl.on("hyprland.start", function()
--     hl.exec_cmd("pgrep -x nm-applet >/dev/null || nm-applet &")
-- end)

--------------------------------------------------------------------------------
-- Comfort switches (uncomment what you like)
--------------------------------------------------------------------------------
-- hl.config({ misc  = { vrr = 1 } })                        -- adaptive sync
-- hl.config({ misc  = { enable_swallow = false } })         -- no swallowing
-- hl.config({ input = { touchpad = { natural_scroll = true } } })
-- hl.config({ decoration = { blur = { enabled = false } } })-- absolute min GPU
-- hl.config({ animations = { enabled = false } })           -- zero animations
-- hl.config({ render = { new_render_scheduling = true } })  -- triple-buffer when
--                                                           -- needed: smoother on
--                                                           -- weak GPUs, a touch
--                                                           -- more latency
