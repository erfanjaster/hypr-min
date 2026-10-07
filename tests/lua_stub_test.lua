-- ============================================================================
-- lua_stub_test.lua — execute a Hyprland Lua config against a stub `hl` API.
-- Catches: unknown API calls, bad dispatcher names, bad bind flags/malformed
-- keys, duplicate binds, wrong argument types. Exits 1 on any violation.
-- Usage: lua5.4 lua_stub_test.lua /path/to/hyprland.lua
-- ============================================================================

local errors = {}
local function err(msg) errors[#errors + 1] = msg end

local BIND_FLAGS = {
    locked = 1, release = 1, click = 1, drag = 1, long_press = 1,
    repeating = 1, non_consuming = 1, auto_consuming = 1, mouse = 1,
    transparent = 1, ignore_mods = 1, description = 1, dont_inhibit = 1,
    submap_universal = 1, device = 1, allow_input_capture = 1,
}
local MODS = {
    SUPER = 1, SHIFT = 1, CTRL = 1, ALT = 1, MOD3 = 1, MOD4 = 1, MOD5 = 1,
    HYPER = 1, META = 1,
}
local DSP_NS   = { window = 1, workspace = 1, group = 1, cursor = 1 }
local DSP_LEAF = {
    exec_cmd = 1, exec_raw = 1, exit = 1, focus = 1, layout = 1, no_op = 1,
    pass = 1, reload_config = 1, submap = 1, dpms = 1, event = 1, global = 1,
    force_idle = 1, force_renderer_reload = 1, release_input_capture = 1,
    send_shortcut = 1, send_key_state = 1,
    ["window.close"] = 1, ["window.kill"] = 1, ["window.cycle_next"] = 1,
    ["window.bring_to_top"] = 1, ["window.alter_zorder"] = 1,
    ["window.float"] = 1, ["window.center"] = 1, ["window.pin"] = 1,
    ["window.pseudo"] = 1, ["window.fullscreen"] = 1,
    ["window.fullscreen_state"] = 1, ["window.move"] = 1,
    ["window.resize"] = 1, ["window.drag"] = 1, ["window.swap"] = 1,
    ["window.tag"] = 1, ["window.clear_tags"] = 1, ["window.set_prop"] = 1,
    ["window.signal"] = 1, ["window.deny_from_group"] = 1,
    ["window.toggle_swallow"] = 1,
    ["workspace.toggle_special"] = 1, ["workspace.move"] = 1,
    ["workspace.rename"] = 1, ["workspace.swap_monitors"] = 1,
    ["group.active"] = 1, ["group.lock"] = 1, ["group.lock_active"] = 1,
    ["group.move_window"] = 1, ["group.next"] = 1, ["group.prev"] = 1,
    ["group.toggle"] = 1,
    ["cursor.move"] = 1, ["cursor.move_to_corner"] = 1,
}
local EVENTS = {
    ["config.props_refreshed"] = 1, ["config.reloaded"] = 1,
    ["config.unload"] = 1, ["hyprland.shutdown"] = 1, ["hyprland.start"] = 1,
    ["input.keyboard.key"] = 1, ["keybinds.submap"] = 1, ["layer.closed"] = 1,
    ["layer.opened"] = 1, ["monitor.added"] = 1, ["monitor.focused"] = 1,
    ["monitor.layout_changed"] = 1, ["monitor.removed"] = 1,
    ["screenshare.state"] = 1, ["window.active"] = 1, ["window.bell"] = 1,
    ["window.class"] = 1, ["window.close"] = 1, ["window.destroy"] = 1,
    ["window.fullscreen"] = 1, ["window.kill"] = 1, ["window.minimize"] = 1,
    ["window.move_to_workspace"] = 1, ["window.open"] = 1,
    ["window.open_early"] = 1, ["window.pin"] = 1, ["window.title"] = 1,
    ["window.update_rules"] = 1, ["window.urgent"] = 1,
    ["workspace.active"] = 1, ["workspace.created"] = 1,
    ["workspace.move_to_monitor"] = 1, ["workspace.removed"] = 1,
    ["workspace.special_active"] = 1,
}

local stats = { binds = 0, rules = 0, anims = 0, execs = 0, events = 0 }
local seen_binds = {}

local function check_keys(keys)
    if type(keys) ~= "string" or keys == "" then
        err("bind: keys must be a non-empty string, got " .. tostring(keys))
        return
    end
    for part in keys:gmatch("[^+]+") do
        local p = part:match("^%s*(.-)%s*$")
        if p == "" then err("bind '" .. keys .. "': empty key part") end
    end
    local mods = keys:match("^(.*)%s+%S+$") or ""
    for m in mods:gmatch("[^+]+") do
        local name = m:match("^%s*(.-)%s*$")
        if name ~= "" and not MODS[name] then
            err("bind '" .. keys .. "': unknown modifier '" .. name .. "'")
        end
    end
end

local function make_dsp(prefix)
    local t = {}
    return setmetatable(t, {
        __index = function(_, k)
            local name = (prefix == "") and k or (prefix .. "." .. k)
            if DSP_NS[name] then return make_dsp(name) end
            if not DSP_LEAF[name] then
                err("unknown dispatcher: hl.dsp." .. name)
                return function() return { __dsp = name } end
            end
            local STRING_ARG = { exec_cmd = 1, exec_raw = 1, submap = 1,
                                 layout = 1, event = 1, global = 1,
                                 ["workspace.toggle_special"] = 1 }
            return function(args)
                if STRING_ARG[name] then
                    if args ~= nil and type(args) ~= "string" then
                        err("hl.dsp." .. name .. ": expects a string argument")
                    end
                elseif args ~= nil and type(args) ~= "table" then
                    err("hl.dsp." .. name .. ": args must be a table")
                end
                return { __dsp = name, args = args }
            end
        end,
    })
end

hl = {}
hl.dsp = make_dsp("")

function hl.bind(keys, action, flags)
    check_keys(keys)
    if action == nil then err("bind '" .. tostring(keys) .. "': no action") end
    if flags ~= nil then
        if type(flags) ~= "table" then err("bind flags must be a table") end
        for f in pairs(flags or {}) do
            if not BIND_FLAGS[f] then
                err("bind '" .. tostring(keys) .. "': unknown flag '" .. tostring(f) .. "'")
            end
        end
    end
    local norm = keys:gsub("%s+", " "):upper()
    if seen_binds[norm] then err("duplicate bind: " .. norm) end
    seen_binds[norm] = true
    stats.binds = stats.binds + 1
    return { set_enabled = function() end, unbind = function() end }
end

function hl.unbind(keys) seen_binds[keys:upper()] = nil end

function hl.dispatch(d)
    if type(d) ~= "table" or d.__dsp == nil then
        err("hl.dispatch called with a non-dispatcher value")
    end
end

function hl.config(t)
    if type(t) ~= "table" then err("hl.config: expects a table") end
end

function hl.monitor(t)
    if type(t) ~= "table" or type(t.output) ~= "string" then
        err("hl.monitor: requires output = string")
    end
end

function hl.env(k, v)
    if type(k) ~= "string" or type(v) ~= "string" then
        err("hl.env: key and value must be strings")
    end
end

function hl.on(ev, fn)
    if not EVENTS[ev] then err("hl.on: unknown event '" .. tostring(ev) .. "'") end
    if type(fn) ~= "function" then err("hl.on: handler must be a function") end
    stats.events = stats.events + 1
end

function hl.exec_cmd(s)
    if type(s) ~= "string" then err("hl.exec_cmd: expects string") end
    stats.execs = stats.execs + 1
end

function hl.curve(name, t)
    if type(name) ~= "string" then err("hl.curve: name must be string") end
    if type(t) ~= "table" or (t.type ~= "bezier" and t.type ~= "spring") then
        err("hl.curve '" .. name .. "': type must be bezier|spring")
    end
    if t.type == "bezier" then
        if type(t.points) ~= "table" or #t.points ~= 2 then
            err("hl.curve '" .. name .. "': bezier needs 2 points")
        end
    end
end

function hl.animation(t)
    if type(t) ~= "table" or type(t.leaf) ~= "string" then
        err("hl.animation: requires leaf")
    end
    if t.enabled == nil then err("hl.animation '" .. t.leaf .. "': needs enabled") end
    if t.enabled and type(t.speed) ~= "number" then
        err("hl.animation '" .. t.leaf .. "': speed must be a number")
    end
    stats.anims = stats.anims + 1
end

function hl.gesture(t)
    if type(t) ~= "table" or not t.action or not t.direction or not t.fingers then
        err("hl.gesture: needs action, direction, fingers")
    end
end

function hl.window_rule(t)
    if type(t) ~= "table" or type(t.match) ~= "table" then
        err("hl.window_rule: requires match = { ... }")
    end
    stats.rules = stats.rules + 1
    return { set_enabled = function() end }
end

function hl.layer_rule(t)
    if type(t) ~= "table" or type(t.match) ~= "table" then
        err("hl.layer_rule: requires match = { ... }")
    end
    stats.rules = stats.rules + 1
    return { set_enabled = function() end }
end

function hl.workspace_rule(t)
    if type(t) ~= "table" or type(t.workspace) ~= "string" then
        err("hl.workspace_rule: requires workspace selector")
    end
end

function hl.define_submap(name, fn)
    if type(fn) == "function" then fn() end
end

function hl.permission(t) end

-- let require("...") resolve relative to the config's directory
local cfg_path = arg and arg[1] or error("usage: lua5.4 lua_stub_test.lua <config.lua>")
local cfg_dir = cfg_path:match("(.*/)") or "./"
package.path = cfg_dir .. "?.lua;" .. package.path

local chunk, lerr = loadfile(cfg_path)
if not chunk then
    print("LUA SYNTAX/LOAD ERROR: " .. tostring(lerr))
    os.exit(1)
end
local ok, rerr = pcall(chunk)
if not ok then
    print("LUA RUNTIME ERROR: " .. tostring(rerr))
    os.exit(1)
end

if #errors > 0 then
    print("LUA API AUDIT FAILED (" .. #errors .. " problems):")
    for _, e in ipairs(errors) do print("  - " .. e) end
    os.exit(1)
end

print(string.format(
    "lua stub run: OK — %d binds, %d rules, %d animations, %d autostart execs, %d events",
    stats.binds, stats.rules, stats.anims, stats.execs, stats.events))
