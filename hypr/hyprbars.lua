---@diagnostic disable: undefined-global
-- Mac-style title bars on floating windows (the hyprbars plugin).
-- Round close / minimize / maximize on the left, symbols when you point at them,
-- the title in the middle. Double-click the bar to maximize. Tiled windows get no bar.
--
-- The plugin is installed once with hyprpm (install.sh does it):
--   hyprpm update && hyprpm add https://github.com/hyprwm/hyprland-plugins && hyprpm enable hyprbars
-- hyprland.lua loads it at startup (hyprpm reload). Hyprland reads the config again
-- once the plugin is in, so everything below waits for hl.plugin.hyprbars.
--
-- Colors follow Blink's theme: ThemeService writes ~/.config/blink/hyprbars-colors.lua
-- and calls BlinkBars.apply() when the theme changes.

local function has_plugin()
    return hl.plugin ~= nil and hl.plugin.hyprbars ~= nil
end

local function colors()
    local ok, c = pcall(dofile, os.getenv("HOME") .. "/.config/blink/hyprbars-colors.lua")
    if ok and type(c) == "table" then return c end
    return { bar = "rgb(242426)", text = "rgb(e5e5e7)", inactive = "rgb(48484c)" }
end

BlinkBars = {}

function BlinkBars.apply()
    if not has_plugin() then return end
    local c = colors()
    hl.config({
        plugin = {
            hyprbars = {
                bar_color = c.bar,
                col = { text = c.text },
                inactive_button_color = c.inactive,
            },
        },
    })
end

if has_plugin() then
    hl.config({
        plugin = {
            hyprbars = {
                enabled = true,
                bar_height = 32,
                bar_text_font = "IBM Plex Sans",
                bar_text_size = 11,
                bar_text_weight = "medium",
                bar_text_align = "center",
                bar_buttons_alignment = "left",
                bar_padding = 14,
                bar_button_padding = 8,
                bar_part_of_window = true,
                bar_precedence_over_border = true,
                icon_on_hover = true,
                on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
            },
        },
    })
    BlinkBars.apply()

    -- With the buttons on the left, the first one added sits furthest left
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(ee5d5b)",
        fg_color = "rgb(4a0f0f)",
        size = 13,
        icon = "×",
        action = [[hyprctl dispatch 'hl.dsp.window.close()']],
    })
    -- Minimize: the same hidden workspace the dock uses, so it shows up there
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(f0b443)",
        fg_color = "rgb(5a3a05)",
        size = 13,
        icon = "−",
        action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:minimized", follow = false })']],
    })
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(4fbf68)",
        fg_color = "rgb(0d3d18)",
        size = 13,
        icon = "+",
        action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
    })

    -- Only floating windows get a bar (Super+T switches to floating mode)
    hl.window_rule({
        name = "hyprbars-tiled",
        match = { float = false },
        ["hyprbars:no_bar"] = true,
    })
    -- Apps that draw their own title bar (GTK 4 / libadwaita like Nautilus, Blink Settings)
    hl.window_rule({
        name = "hyprbars-own-titlebar",
        match = { class = "^(org\\.gnome\\..*|.*(quickshell|noctalia-qs).*)$" },
        ["hyprbars:no_bar"] = true,
    })
end
