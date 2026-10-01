---@diagnostic disable: undefined-global
-- ~/.config/hypr/hyprland.lua
-- Mac-inspirert Hyprland. Utseende og moduser ligger i style.lua.

-----------------
---- MONITORER ----
-----------------
hl.monitor({
    output   = "DP-3",
    mode     = "2560x1440@144",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@60",
    position = "2560x0",
    scale    = 1,
})

------------------
---- MILJØ ----
------------------
hl.env("XDG_DATA_DIRS", "/var/lib/flatpak/exports/share:/home/tallman/.local/share/flatpak/exports/share:/usr/local/share:/usr/share")
hl.env("QS_ICON_THEME", "Papirus-Dark")

-----------------
---- AUTOSTART ----
-----------------
hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    -- Quickshell erstatter waybar og mako
    hl.exec_cmd("qs -p /home/tallman/Documents/GitHub/mac-hypr-rice/quickshell")
end)

-------------
---- INPUT ----
-------------
hl.config({
    input = {
        kb_layout = "no",
        kb_options = "caps:escape",
        follow_mouse = 1,
        sensitivity = -0.45,
    },
})

-------------
---- LÅSING ----
-------------
hl.config({
    misc = {
        allow_session_lock_restore = true, -- kan starte låseskjermen på nytt hvis den krasjer
        session_lock_xray = true,          -- vis skrivebordet bak låseskjermen
        session_lock_blur = true,          -- ... blurret
    },
})

-------------------
---- RESTEN ----
-------------------
require("keybinds")
require("style") -- sist, så den bestemmer utseendet
