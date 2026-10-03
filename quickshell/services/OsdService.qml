pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Hyprland

// Volume / brightness changes. The notch shows them (bar/Notch.qml).
Singleton {
    id: root

    property string kind: "volume"     // "volume", "brightness" or "workspace"
    property real value: 0
    property bool muted: false
    property bool shown: false

    // Ignore the changes that happen while the shell starts
    property bool ready: false
    Timer { interval: 2000; running: true; onTriggered: root.ready = true }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    function show(k, v, m) {
        if (!ready || ShellState.controlCenterOpen) return
        kind = k
        value = Math.max(0, Math.min(1, v))
        muted = m === true
        shown = true
        hideTimer.interval = k === "workspace" ? 1000 : 1500
        hideTimer.restart()
    }

    // ---------- Volume ----------
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.show("volume", root.sink.audio.volume, root.sink.audio.muted) }
        function onMutedChanged() { root.show("volume", root.sink.audio.volume, root.sink.audio.muted) }
    }

    // ---------- Workspace switch ----------
    // The bar sweeps a light out from the notch in that direction
    property int wsId: Hyprland.focusedWorkspace?.id ?? 1
    property int wsDir: 1              // 1 = to the right, -1 = to the left
    property string wsMonitor: ""
    property int wsTick: 0
    readonly property int focusedWs: Hyprland.focusedWorkspace?.id ?? 0
    onFocusedWsChanged: {
        const id = focusedWs
        if (id <= 0 || id === wsId) return   // special workspaces (scratchpad, minimized)
        wsDir = id > wsId ? 1 : -1
        wsId = id
        wsMonitor = Hyprland.focusedMonitor?.name ?? ""
        if (!ready) return
        wsTick++
    }

    // ---------- Brightness ----------
    Connections {
        target: BrightnessService
        function onValueChanged() { root.show("brightness", BrightnessService.value, false) }
    }

    // ---------- Actions (used by the keys) ----------
    function volumeUp() {
        const a = root.sink?.audio
        if (!a) return
        a.muted = false
        a.volume = Math.min(1, Math.round((a.volume + 0.05) * 20) / 20)
    }
    function volumeDown() {
        const a = root.sink?.audio
        if (!a) return
        a.volume = Math.max(0, Math.round((a.volume - 0.05) * 20) / 20)
    }
    function toggleMute() {
        const a = root.sink?.audio
        if (a) a.muted = !a.muted
    }
    function brightnessUp() {
        if (BrightnessService.available)
            BrightnessService.set(Math.min(1, BrightnessService.value + 0.05))
    }
    function brightnessDown() {
        if (BrightnessService.available)
            BrightnessService.set(Math.max(0.01, BrightnessService.value - 0.05))
    }

    function iconName() {
        if (kind === "brightness") return "display-brightness-symbolic"
        if (muted || value === 0) return "audio-volume-muted-symbolic"
        if (value < 0.34) return "audio-volume-low-symbolic"
        if (value < 0.67) return "audio-volume-medium-symbolic"
        return "audio-volume-high-symbolic"
    }
}
