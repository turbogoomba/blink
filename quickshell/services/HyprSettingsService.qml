pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland options for Settings > Hyprland and settings search.
// A change applies right away with `hyprctl eval`, is saved to ~/.config/blink/hyprland.json,
// and is written to ~/.config/hypr/overrides.lua, which style.lua loads when Hyprland starts.
// Only options you changed are saved. Reset removes one again, so the normal config wins.
Singleton {
    id: root

    readonly property var sections: [
        { id: "windows",    label: "Windows" },
        { id: "look",       label: "Look" },
        { id: "animations", label: "Animations" },
        { id: "mouse",      label: "Mouse & Touchpad" },
        { id: "keyboard",   label: "Keyboard" },
        { id: "other",      label: "Other" }
    ]

    // type: "slider" (min, max, step, unit, decimals, percent), "switch" (optional on/off values),
    //       "choice" (choices: [{ value, label }], optional empty = what "" means)
    readonly property var options: [
        { key: "general.gaps_in", section: "windows", type: "slider", min: 0, max: 30, step: 1, unit: "px",
          label: "Gaps between windows", desc: "Space between windows next to each other" },
        { key: "general.gaps_out", section: "windows", type: "slider", min: 0, max: 60, step: 1, unit: "px",
          label: "Gaps to screen edge", desc: "Space between the windows and the edge of the screen" },
        { key: "general.border_size", section: "windows", type: "slider", min: 0, max: 6, step: 1, unit: "px",
          label: "Border width", desc: "A colored line around each window. 0 hides it" },
        { key: "general.layout", section: "windows", type: "choice",
          choices: [{ value: "dwindle", label: "Dwindle" }, { value: "master", label: "Master" }],
          label: "Tiling layout", desc: "Dwindle keeps splitting space in half. Master keeps one big window on the left" },
        { key: "general.resize_on_border", section: "windows", type: "switch",
          label: "Resize from the edges", desc: "Drag the edge of a window to resize it" },

        { key: "decoration.rounding", section: "look", type: "slider", min: 0, max: 30, step: 1, unit: "px",
          label: "Corner radius", desc: "How round the window corners are" },
        { key: "decoration.blur.enabled", section: "look", type: "switch",
          label: "Blur", desc: "Blur what is behind see-through windows and panels" },
        { key: "decoration.blur.size", section: "look", type: "slider", min: 1, max: 20, step: 1,
          label: "Blur strength", desc: "Higher is softer, but uses more GPU" },
        { key: "decoration.blur.passes", section: "look", type: "slider", min: 1, max: 4, step: 1,
          label: "Blur quality", desc: "More passes look smoother, but use more GPU" },
        { key: "decoration.shadow.enabled", section: "look", type: "switch",
          label: "Shadows", desc: "A soft shadow under every window" },
        { key: "decoration.active_opacity", section: "look", type: "slider", min: 0.5, max: 1, step: 0.05, percent: true,
          label: "Focused window opacity", desc: "How see-through the window you are using is" },
        { key: "decoration.inactive_opacity", section: "look", type: "slider", min: 0.5, max: 1, step: 0.05, percent: true,
          label: "Other windows opacity", desc: "How see-through windows are when they are not focused" },

        { key: "animations.enabled", section: "animations", type: "switch",
          label: "Window animations", desc: "Windows slide and fade when they open, close and move" },

        { key: "input.sensitivity", section: "mouse", type: "slider", min: -1, max: 1, step: 0.05, decimals: 2,
          label: "Mouse speed", desc: "How fast the pointer moves. 0 is the normal speed" },
        { key: "input.accel_profile", section: "mouse", type: "choice", empty: "adaptive",
          choices: [{ value: "adaptive", label: "On" }, { value: "flat", label: "Off" }],
          label: "Pointer acceleration", desc: "Fast movements send the pointer further. Off feels the same at every speed" },
        { key: "input.natural_scroll", section: "mouse", type: "switch",
          label: "Natural scrolling (mouse)", desc: "Content follows the wheel, like on a phone" },
        { key: "input.touchpad.natural_scroll", section: "mouse", type: "switch",
          label: "Natural scrolling (touchpad)", desc: "Content follows your fingers" },
        { key: "input.touchpad.tap-to-click", section: "mouse", type: "switch",
          label: "Tap to click", desc: "Tap the touchpad instead of pressing it down" },
        { key: "input.follow_mouse", section: "mouse", type: "switch", on: 1, off: 0,
          label: "Focus follows mouse", desc: "The window under the mouse gets focus without a click" },

        { key: "input.kb_layout", section: "keyboard", type: "choice",
          choices: [{ value: "no", label: "NO" }, { value: "us", label: "US" }, { value: "gb", label: "UK" },
                    { value: "se", label: "SE" }, { value: "dk", label: "DK" }, { value: "de", label: "DE" }],
          label: "Keyboard layout", desc: "Which letters and symbols your keys type" },
        { key: "input.repeat_rate", section: "keyboard", type: "slider", min: 10, max: 60, step: 1, unit: "/s",
          label: "Key repeat speed", desc: "How fast a held key repeats" },
        { key: "input.repeat_delay", section: "keyboard", type: "slider", min: 150, max: 1000, step: 50, unit: "ms",
          label: "Key repeat delay", desc: "How long to hold a key before it starts repeating" },

        { key: "misc.vrr", section: "other", type: "choice",
          choices: [{ value: "0", label: "Off" }, { value: "1", label: "On" }, { value: "2", label: "Fullscreen" }],
          label: "Variable refresh rate", desc: "Smoother games on FreeSync or G-Sync monitors. Fullscreen is the safest" },
        { key: "cursor.hide_on_key_press", section: "other", type: "switch",
          label: "Hide pointer while typing", desc: "It comes back when you move the mouse" }
    ]

    property var values: ({})   // key -> value Hyprland uses now ("?" = not available)
    property var saved: ({})    // key -> value set in Settings
    property bool ready: false

    function option(key) { return options.find(o => o.key === key) }
    function sectionLabel(id) { return (sections.find(s => s.id === id) ?? { label: "" }).label }
    function isChanged(key) { return saved[key] !== undefined }
    function available(key) { return values[key] !== undefined && values[key] !== "?" }

    // Value for a control, in the type the control wants
    function valueOf(o) {
        const v = values[o.key]
        if (v === undefined || v === "?") return o.type === "switch" ? false : o.type === "slider" ? o.min : ""
        if (o.type === "switch") return o.on !== undefined ? String(v) === String(o.on) : (v === "true" || v === "1")
        if (o.type === "slider") return parseFloat(v)
        return v === "" && o.empty !== undefined ? o.empty : String(v)
    }

    function set(key, value) {
        const o = option(key)
        let v = value
        if (o.type === "switch" && o.on !== undefined) v = value ? o.on : o.off
        if (o.type === "slider") v = Math.round(value / o.step) * o.step
        if (o.type === "slider" && o.step < 1) v = parseFloat(v.toFixed(2))
        if (o.type === "choice" && /^\d+$/.test(String(v))) v = parseInt(v)

        const nv = Object.assign({}, values); nv[key] = String(v); values = nv
        const ns = Object.assign({}, saved); ns[key] = v; saved = ns
        Quickshell.execDetached(["hyprctl", "eval", luaFor(key, v)])
        save()
    }

    function reset(key) {
        const ns = Object.assign({}, saved); delete ns[key]; saved = ns
        save()
        Quickshell.execDetached(["hyprctl", "reload"])
        rereadTimer.restart()
    }

    function resetAll() {
        saved = {}
        save()
        Quickshell.execDetached(["hyprctl", "reload"])
        rereadTimer.restart()
    }

    function refresh() { reader.running = true }

    // { a = { b = value } } for "a.b"; keys with a dash are quoted
    function luaFor(key, v) {
        let s = typeof v === "boolean" ? String(v) : typeof v === "number" ? String(v) : JSON.stringify(String(v))
        const parts = key.split(".")
        for (let i = parts.length - 1; i >= 0; i--) {
            const k = /^[A-Za-z_]\w*$/.test(parts[i]) ? parts[i] : `["${parts[i]}"]`
            s = `{ ${k} = ${s} }`
        }
        return "hl.config(" + s + ")"
    }

    function save() {
        jsonFile.setText(JSON.stringify(saved, null, 2) + "\n")
        const lines = Object.keys(saved).sort().map(k => luaFor(k, saved[k]))
        overrides.setText("-- Written by Blink Settings > Hyprland. Change these there, not here.\n"
                          + lines.join("\n") + "\n")
    }

    Component.onCompleted: refresh()

    Timer {
        id: rereadTimer
        interval: 600
        onTriggered: root.refresh()
    }

    // Ask Hyprland for every option in one go. A missing option comes back as "?".
    Process {
        id: reader
        command: ["hyprctl", "repl",
            "(function() local out = {} for _, k in ipairs({"
            + root.options.map(o => JSON.stringify(o.key)).join(",")
            + "}) do local ok, x = pcall(hl.get_config, k) if ok and type(x) == 'table' then x = x.top end "
            + "out[#out + 1] = (ok and x ~= nil) and tostring(x) or '?' end return table.concat(out, '\\t') end)()"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.replace(/\n$/, "").split("\t")
                if (parts.length !== root.options.length) {
                    console.warn("HyprSettingsService: unexpected reply:", text.trim())
                    return
                }
                const nv = {}
                root.options.forEach((o, i) => nv[o.key] = parts[i].trim())
                root.values = nv
                root.ready = true
            }
        }
    }

    FileView {
        id: jsonFile
        path: Quickshell.env("HOME") + "/.config/blink/hyprland.json"
        printErrors: false
        onLoaded: {
            try { root.saved = JSON.parse(text()) } catch (e) { root.saved = {} }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) oldOverrides.reload()
        }
    }

    FileView {
        id: overrides
        path: Quickshell.env("HOME") + "/.config/hypr/overrides.lua"
        printErrors: false
    }

    // One time: keep what the old Hyprland page saved (gaps, radius, mouse speed)
    FileView {
        id: oldOverrides
        path: Quickshell.env("HOME") + "/.config/hypr/overrides.lua"
        printErrors: false
        preload: false
        onLoaded: {
            const t = text()
            if (t.indexOf("Skrevet av Settings-appen") < 0) return
            const s = {}
            const pick = (re, key, f) => { const m = t.match(re); if (m) s[key] = f(m[1]) }
            pick(/gaps_in = (\d+)/, "general.gaps_in", parseInt)
            pick(/gaps_out = (\d+)/, "general.gaps_out", parseInt)
            pick(/rounding = (\d+)/, "decoration.rounding", parseInt)
            pick(/sensitivity = (-?[\d.]+)/, "input.sensitivity", parseFloat)
            root.saved = s
            root.save()
        }
    }
}
