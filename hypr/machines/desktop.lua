---@diagnostic disable: undefined-global
-- Stasjonær. Gi filen navnet til maskinen (cat /etc/hostname) når du er der.

hl.monitor({ output = "DP-3", mode = "2560x1440@144", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "2560x0", scale = 1 })

hl.config({ input = { sensitivity = -0.45 } })
