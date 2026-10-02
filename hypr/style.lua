---@diagnostic disable: undefined-global
-- Mac-stil for Hyprland, med to moduser: "tiling" og "floating"

----------------------
---- FELLES UTSEENDE ----
----------------------
hl.config({
    general = {
        gaps_in = 8,
        gaps_out = 16,
        border_size = 0,
        resize_on_border = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 12,
        rounding_power = 4.0,
        blur = { enabled = true, size = 8, passes = 2 },
        shadow = {
            enabled = true,
            range = 30,
            render_power = 3,
            offset = { 0, 8 },
            color = "rgba(00000070)",
        },
    },
})

---------------------
---- ANIMASJONER ----
---------------------
-- Same feel as the shell: soft ease-out, a small bounce on open, quick close
hl.curve("macOut", { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.curve("macPop", { type = "bezier", points = { { 0.34, 1.36 }, { 0.64, 1 } } })
hl.curve("macIn",  { type = "bezier", points = { { 0.32, 0 }, { 0.67, 0 } } })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 1.8, bezier = "macPop", style = "popin 88%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1.2,   bezier = "macIn",  style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.8, bezier = "macOut" })
hl.animation({ leaf = "fade",        enabled = true, speed = 1.5, bezier = "macOut" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 2.5,   bezier = "macOut", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "macOut", style = "slidevert" })
hl.animation({ leaf = "layers",      enabled = false })

-------------------------
---- TO MODUSER ----
-------------------------
local styles = {
    tiling = {
        decoration = { dim_inactive = true, dim_strength = 0.12 },
    },
    floating = {
        decoration = { dim_inactive = false },
    },
}

local floatAll = hl.window_rule({
    name = "mac-float-all",
    match = { class = ".*" },
    float = true,
    center = true,
    size = { "(monitor_w*0.6)", "(monitor_h*0.65)" },
})

local stateFile = os.getenv("HOME") .. "/.cache/hypr-mac-style"

local function loadMode()
    local ok, mode = pcall(function()
        local f = io.open(stateFile, "r")
        if not f then return "tiling" end
        local m = f:read("*l")
        f:close()
        return m
    end)
    if ok and mode == "floating" then return "floating" end
    return "tiling"
end

local function saveMode(mode)
    pcall(function()
        local f = io.open(stateFile, "w")
        if f then f:write(mode) f:close() end
    end)
end

MacStyle = { mode = "tiling" }

function MacStyle.set(mode, quiet)
    MacStyle.mode = mode
    hl.config(styles[mode])

    local floating = (mode == "floating")
    floatAll:set_enabled(floating)

    for _, w in pairs(hl.get_windows()) do
        hl.dispatch(hl.dsp.window.float({ action = floating and "set" or "unset", window = w }))
    end

    saveMode(mode)
    if not quiet then
        hl.exec_cmd('notify-send -a "Hyprland" "Window mode" "' .. (floating and "Floating" or "Tiling") .. '"')
    end
end

function MacStyle.toggle()
    MacStyle.set(MacStyle.mode == "tiling" and "floating" or "tiling")
end

MacStyle.set(loadMode(), true)

hl.bind("SUPER + T", function() MacStyle.toggle() end)

------------------------------------
---- INNSTILLINGER FRA SETTINGS-APPEN ----
------------------------------------
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/overrides.lua")
