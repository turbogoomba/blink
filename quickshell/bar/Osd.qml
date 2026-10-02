import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../services"
import "../theme"

// Volume / brightness popup in the top right corner.
// Shows up by itself when the volume or brightness changes.
// Keys call: qs ipc call osd volumeUp | volumeDown | mute | brightnessUp | brightnessDown
Scope {
    id: root

    property string kind: "volume"     // "volume" or "brightness"
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

    // ---------- Brightness ----------
    Connections {
        target: BrightnessService
        function onValueChanged() { root.show("brightness", BrightnessService.value, false) }
    }

    IpcHandler {
        target: "osd"

        function volumeUp(): void {
            const a = root.sink?.audio
            if (!a) return
            a.muted = false
            a.volume = Math.min(1, Math.round((a.volume + 0.05) * 20) / 20)
        }
        function volumeDown(): void {
            const a = root.sink?.audio
            if (!a) return
            a.volume = Math.max(0, Math.round((a.volume - 0.05) * 20) / 20)
        }
        function mute(): void {
            const a = root.sink?.audio
            if (a) a.muted = !a.muted
        }
        function brightnessUp(): void {
            if (BrightnessService.available)
                BrightnessService.set(Math.min(1, BrightnessService.value + 0.05))
        }
        function brightnessDown(): void {
            if (BrightnessService.available)
                BrightnessService.set(Math.max(0.01, BrightnessService.value - 0.05))
        }
    }

    function iconName() {
        if (kind === "brightness") return "display-brightness-symbolic"
        if (muted || value === 0) return "audio-volume-muted-symbolic"
        if (value < 0.34) return "audio-volume-low-symbolic"
        if (value < 0.67) return "audio-volume-medium-symbolic"
        return "audio-volume-high-symbolic"
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: card.opacity > 0
        color: "transparent"
        anchors.top: true
        anchors.right: true
        margins.top: Tokens.barHeight + 10
        margins.right: 16
        implicitWidth: 260
        implicitHeight: 70
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "osd"
        mask: Region {}

        Rectangle {
            id: card
            width: 240
            height: 52
            anchors.right: parent.right
            radius: 14
            color: Tokens.surface
            border.color: Tokens.border
            border.width: 1

            opacity: root.shown ? 1 : 0
            y: root.shown ? 0 : -10
            scale: root.shown ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Image {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                sourceSize: Qt.size(40, 40)
                source: Quickshell.iconPath(root.iconName(), "audio-volume-high")
            }

            Rectangle {
                id: track
                anchors.left: icon.right
                anchors.leftMargin: 12
                anchors.right: pct.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: Tokens.border

                Rectangle {
                    width: parent.width * (root.muted ? 0 : root.value)
                    height: parent.height
                    radius: 3
                    color: root.muted ? Tokens.textSecondary : "white"
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                id: pct
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "Mute" : Math.round(root.value * 100) + "%"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
            }
        }
    }
}
