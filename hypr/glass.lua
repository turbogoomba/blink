---@diagnostic disable: undefined-global
-- Glass themes (Settings > Appearance > Glass): Hyprland blurs what is behind Blink's
-- see-through bar, dock, menus, notifications and widgets.
-- ThemeService writes ~/.config/blink/glass.lua ({ enabled = true/false }) and calls
-- BlinkGlass.apply() when the theme changes; other themes are solid, so no blur is needed.

-- Blink's layers (the bar and dock have Quickshell's default name)
local NAMESPACES = "^(quickshell|controlcenter|launcher|notifications|calendar|soundmenu|weather|powermenu|"
    .. "blink-widget|switcher|drawer|notchpanel|sideosd|sidebar)$"

BlinkGlass = {}

function BlinkGlass.apply()
    local ok, c = pcall(dofile, os.getenv("HOME") .. "/.config/blink/glass.lua")
    local on = ok and type(c) == "table" and c.enabled == true
    -- Blur only with a glass theme: with it on, see-through kitty flickered on the solid
    -- themes (where the dock is nearly solid and does not need it)
    hl.config({ decoration = { blur = { enabled = on } } })
    hl.layer_rule({
        name = "blink-glass",
        enabled = on,
        match = { namespace = NAMESPACES },
        blur = true,
        -- Only blur behind what is really there (not the clear parts around the shapes)
        ignore_alpha = 0.15,
    })
    -- The dock can be glass on its own too (Settings > Dock > Glass)
    hl.layer_rule({
        name = "blink-glass-dock",
        enabled = on or (ok and type(c) == "table" and c.dock == true),
        match = { namespace = "^blink-dock$" },
        blur = true,
        ignore_alpha = 0.15,
    })
end

BlinkGlass.apply()
