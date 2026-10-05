-- ~/.config/hypr/keybinds.lua
-- Converted from keybinds.conf (hyprlang -> Lua, Hyprland 0.55+)

local qs = "qs -c blink ipc call "
local terminal    = "kitty"
local fileManager = "thunar"
local mainMod      = "SUPER"

----------------------
---- APPLICATIONS ----
----------------------
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs -c blink ipc call launcher toggle"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("Print", hl.dsp.exec_cmd(qs .. "screenshot region"))
hl.bind("F6", hl.dsp.exec_cmd(qs .. "screenshot region"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(qs .. "screenshot screen"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))

------------------------
---- WINDOW CONTROL ----
------------------------
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized"))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("qs -c blink ipc call lock lock"))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("qs -c blink ipc call mission toggle"))
------------------
---- WORKSPACES ----
------------------
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-----------------------
---- FOCUS (VIM) ----
-----------------------
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

------------------------
---- MOVE WINDOWS ----
------------------------
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

--------------------------
---- RESIZE WINDOWS ----
--------------------------
-- old "binde" = repeat while held, not locked
hl.bind(mainMod .. " + ALT + H", hl.dsp.window.resize({ x = -50, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + ALT + L", hl.dsp.window.resize({ x = 50, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + ALT + K", hl.dsp.window.resize({ x = 0, y = -50 }), { repeating = true })
hl.bind(mainMod .. " + ALT + J", hl.dsp.window.resize({ x = 0, y = 50 }), { repeating = true })

------------------------
---- MOUSE BINDINGS ----
------------------------
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-------------
---- AUDIO ----
-------------
-- old "bindel" = repeat + locked (works on lockscreen too)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
local osd = "qs -c blink ipc call osd "
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(osd .. "brightnessUp"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osd .. "brightnessDown"), { locked = true, repeating = true })

-- old "bindl" = locked only, no repeat (single press)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

------------
---- MISC ----
------------
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("hyprctl dispatch dpms off && sleep 1 && hyprctl dispatch dpms on"))
hl.layer_rule({ match = { namespace = "missioncontrol" }, blur = true, ignore_alpha = 0.1 })

-- Bakgrunnsvelger
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -c blink ipc call wallpaper toggle"))

---- ALT+TAB ----
local sw = "qs -c blink ipc call switcher "
hl.bind("ALT + TAB", hl.dsp.exec_cmd(sw .. "next"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd(sw .. "prev"))
