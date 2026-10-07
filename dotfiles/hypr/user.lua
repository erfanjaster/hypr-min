-- ============================================================================
--  user.lua — your personal tweaks. This file is NEVER overwritten by the
--  installer, so updates to hypr-min can't clobber your changes.
--  Everything below is optional; delete what you don't need.
--  Docs: https://wiki.hypr.land/configuring/
-- ============================================================================

--------------------------------------------------------------------------------
-- Keyboard layout (Persian users): uncomment to get English + Persian with
-- Alt+Shift switching. NOTE: Hyprland binds stay on the first layout (us).
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

--------------------------------------------------------------------------------
-- Comfort switches (uncomment what you like)
--------------------------------------------------------------------------------
-- hl.config({ misc  = { vrr = 1 } })                        -- adaptive sync
-- hl.config({ misc  = { enable_swallow = false } })         -- no swallowing
-- hl.config({ input = { touchpad = { natural_scroll = true } } })
-- hl.config({ decoration = { blur = { enabled = false } } })-- absolute min GPU
-- hl.config({ animations = { enabled = false } })           -- zero animations
