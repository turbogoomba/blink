---@diagnostic disable: undefined-global
-- Drag a floating window to the edge of the screen, like macOS Sequoia:
--   left or right edge -> fills that half,  top edge -> fills the screen.
-- While you hold it at an edge, Blink shows where it will go (quickshell/snap, which
-- watches $XDG_RUNTIME_DIR/blink-snap).
-- Drag a snapped window away and it gets its old size back.
--
-- Hyprland tells nothing about drags, so a small timer watches the focused window: when it
-- moves while the mouse is at an edge, that is a drag to the edge. Letting go of the mouse
-- button (a release bind that does not take the click from apps) snaps it.

local GAP = 10        -- space around a snapped window
local EDGE = 6        -- how close to the edge the mouse has to be
local BAR = 32        -- the title bar (hyprbars) above floating windows
local TOPBAR = 40     -- Blink's bar

local s = {
    addr = nil,       -- the focused window we are watching
    at = nil,         -- where it was last tick
    moved = 0,        -- ticks since it last moved (big = not being dragged)
    zone = nil,       -- "left", "right", "top" or nil
    saved = {},       -- address -> { w, h } before it was snapped
    skip = 0,         -- ticks to ignore movement (our own move after snapping)
}

local function has_bar(w)
    local c = w.class or ""
    return not (c:match("^org%.gnome%.") or c:match("quickshell") or c:match("noctalia%-qs"))
end

local function glass()
    local ok, c = pcall(dofile, os.getenv("HOME") .. "/.config/blink/glass.lua")
    return ok and type(c) == "table" and c.enabled == true
end

-- The free area of a monitor (inside Blink's bar and frame), in layout coordinates
local function area(mon)
    local sc = mon.scale or 1
    local W, H = mon.width / sc, mon.height / sc
    local frame = glass() and 0 or 16
    return {
        x = mon.x + frame + GAP,
        y = mon.y + TOPBAR + GAP,
        w = W - 2 * (frame + GAP),
        h = H - TOPBAR - frame - 2 * GAP,
        W = W, H = H,
    }
end

-- Where the window goes (its title bar included) for a zone
local function target(zone, a)
    if zone == "left" then
        return { x = a.x, y = a.y, w = math.floor((a.w - GAP) / 2), h = a.h }
    elseif zone == "right" then
        local w = math.floor((a.w - GAP) / 2)
        return { x = a.x + a.w - w, y = a.y, w = w, h = a.h }
    elseif zone == "top" then
        return { x = a.x, y = a.y, w = a.w, h = a.h }
    end
end

local function zone_at(c, mon)
    local sc = mon.scale or 1
    local W, H = mon.width / sc, mon.height / sc
    if c.x <= mon.x + EDGE then return "left" end
    if c.x >= mon.x + W - EDGE then return "right" end
    if c.y <= mon.y + EDGE then return "top" end
    return nil
end

-- Tell Blink where the preview goes by writing a small file it watches (much quicker than
-- starting "qs ipc" for every change): "<monitor> x y w h", or empty to hide it.
local PREVIEW = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/blink-snap"
local function write_preview(text)
    local f = io.open(PREVIEW, "w")
    if f then f:write(text); f:close() end
end

local function preview(zone, mon)
    if not zone then
        write_preview("")
        return
    end
    local r = target(zone, area(mon))
    write_preview(string.format("%s %d %d %d %d", mon.name,
        math.floor(r.x - mon.x), math.floor(r.y - mon.y), math.floor(r.w), math.floor(r.h)))
end

local function tick()
    local w = hl.get_active_window()
    if not w or not w.floating or (w.fullscreen or 0) ~= 0 then
        if s.zone then s.zone = nil; preview(nil) end
        s.addr = nil
        return
    end
    local at = w.at
    if s.skip > 0 then
        s.skip, s.at, s.moved = s.skip - 1, at, 99
        return
    end
    if w.address ~= s.addr then
        s.addr, s.at, s.moved, s.zone = w.address, at, 99, nil
        return
    end
    if at.x ~= s.at.x or at.y ~= s.at.y then
        -- Started moving after resting: a new drag. A snapped window gets its old size back.
        if s.moved > 10 and s.saved[w.address] then
            local o = s.saved[w.address]
            s.saved[w.address] = nil
            hl.dispatch(hl.dsp.window.resize({ x = o.w, y = o.h, window = "address:" .. w.address }))
        end
        s.moved = 0
    else
        s.moved = s.moved + 1
    end
    s.at = at

    -- Being dragged (moved within the last half second): which edge is the mouse at?
    local mon = hl.get_monitor_at_cursor()
    local z = (s.moved < 12 and mon) and zone_at(hl.get_cursor_pos(), mon) or s.zone
    if s.moved >= 12 and s.zone then z = s.zone end
    if z ~= s.zone then
        s.zone = z
        preview(z, mon)
    end
end

-- Mouse button let go: snap the window if it was dragged to an edge
local function release()
    local z = s.zone
    if not z then return end
    s.zone = nil
    preview(nil)
    local w = hl.get_active_window()
    local mon = hl.get_monitor_at_cursor()
    if not w or not w.floating or not mon then return end
    local r = target(z, area(mon))
    local bar = has_bar(w) and BAR or 0
    if not s.saved[w.address] then s.saved[w.address] = { w = w.size.x, h = w.size.y } end
    local sel = "address:" .. w.address
    -- A moment later, so Hyprland has finished its own move first
    hl.timer(function()
        hl.dispatch(hl.dsp.window.resize({ x = r.w, y = r.h - bar, window = sel }))
        hl.dispatch(hl.dsp.window.move({ x = r.x, y = r.y + bar, window = sel }))
        s.skip = 4   -- that move was ours, not a new drag
    end, { timeout = 30, type = "oneshot" })
end

-- Make the file exist from the start, so Blink can watch it
write_preview("")
hl.timer(tick, { timeout = 40, type = "repeat" })

-- Letting go after dragging by the title bar, or with Super held
hl.bind("mouse:272", release, { release = true, non_consuming = true })
hl.bind("SUPER + mouse:272", release, { release = true, non_consuming = true })
