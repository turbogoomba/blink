---@diagnostic disable: undefined-global
-- Laptop (archie)

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })

hl.config({
    input = {
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },
    },
})

local qs = "qs -c blink ipc call "

-- Tre fingre sidelengs: bytt arbeidsflate
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Tre fingre opp: Mission Control
hl.gesture({ fingers = 3, direction = "up", action = function()
    hl.exec_cmd(qs .. "mission toggle")
end })
