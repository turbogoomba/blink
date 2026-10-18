---@diagnostic disable: undefined-global
-- ~/.config/hypr/hyprland.lua
-- Felles for alle maskiner. Skjermer og touchpad ligger i machines/<maskinnavn>.lua

local home = os.getenv("HOME")
local hyprDir = home .. "/.config/hypr/"

---- MILJØ ----
hl.env("XDG_DATA_DIRS", "/var/lib/flatpak/exports/share:" .. home .. "/.local/share/flatpak/exports/share:/usr/local/share:/usr/share")
hl.env("QS_ICON_THEME", "Papirus-Dark")

---- AUTOSTART ----
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'dbus-update-activation-environment --systemd --all; systemctl --user start blink.service hypridle.service'")
    hl.exec_cmd("awww-daemon")
    -- WhatsApp starts hidden in special:whatsapp, so notifications always work
    hl.exec_cmd("flatpak run com.rtosta.zapzap")
end)

---- INPUT (felles) ----
hl.config({
    input = {
        kb_layout = "no",
        kb_options = "caps:escape",
        follow_mouse = 1,
    },
})

---- LÅSING ----
hl.config({ misc = { allow_session_lock_restore = true, initial_workspace_tracking = 0 } })

---- MASKINSPESIFIKT ----
local function hostname()
    local f = io.open("/etc/hostname", "r")
    if not f then return "default" end
    local h = f:read("*l") or "default"
    f:close()
    return h
end

local ok, err = pcall(dofile, hyprDir .. "machines/" .. hostname() .. ".lua")
if not ok then
    print("Fant ikke maskinfil, bruker default: " .. tostring(err))
    dofile(hyprDir .. "machines/default.lua")
end

---- RESTEN ----
require("keybinds")
require("style")

---- VINDUSREGLER ----
-- Ignorer apper som ber om å starte maksimert (f.eks. kitty)
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- Thunar always opens floating and centered, like a Finder window
hl.window_rule({
    name = "thunar-float",
    match = { class = "^([Tt]hunar)$" },
    float = true,
    center = true,
    size = { "(monitor_w*0.55)", "(monitor_h*0.6)" },
})
hl.window_rule({ match = { class = "steam_app_.*" }, fullscreen = true })

-- Blink Settings (a Quickshell window) always floats, centered
hl.window_rule({
    name = "blink-settings-float",
    -- The class depends on the Quickshell build (org.quickshell, dev.noctalia.noctalia-qs ...)
    match = { class = ".*(quickshell|noctalia-qs).*", title = "^(Settings)$" },
    float = true,
    center = true,
    size = { 1040, 700 },
})

-- WhatsApp lives in its own hidden special workspace. SUPER+A or "whatsapp" in the launcher shows it.
hl.window_rule({
    name = "whatsapp-hidden",
    match = { class = ".*([Zz]ap[Zz]ap|whatsapp).*" },
    workspace = "special:whatsapp silent",
    float = true,
    center = true,
    size = { "(monitor_w*0.5)", "(monitor_h*0.7)" },
})
