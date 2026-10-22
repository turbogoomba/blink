import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Mac-style Alt+Tab: a row of app icons, most recently used first.
// Every window, on every workspace; minimized ones at the end (dimmed).
// The number under an icon is its workspace. Hold Alt, tap Tab to move, let go of Alt to
// switch: goes to that window's workspace and puts the window on top (minimized ones grow
// back out of the dock). Esc cancels.
// Keys call: qs ipc call switcher next | prev
PanelWindow {
    id: sw
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Open on the monitor you are using (matters with two screens)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "switcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool open: false
    property int selected: 0
    property var windows: []

    property real reveal: open ? 1 : 0
    Behavior on reveal { id: openBehavior; NumberAnimation { duration: openBehavior.targetValue > 0.5 ? 320 : 120; easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeMove; easing.overshoot: Tokens.bounce } }
    visible: open || reveal > 0.01

    function addr(t) {
        const a = t.address
        return a.startsWith("0x") ? a : "0x" + a
    }

    function iconFor(t) {
        const id = t.wayland?.appId ?? ""
        const entry = DesktopEntries.heuristicLookup(id)
        return Quickshell.iconPath(entry?.icon ?? id.toLowerCase(), "application-x-executable")
    }

    function isMinimized(t) { return (t.workspace?.name ?? "") === "special:minimized" }

    // Windows sorted by when they were last focused, minimized ones last
    function collect() {
        const list = Hyprland.toplevels.values.filter(t => t.wayland && (t.workspace?.id ?? 0) !== 0
            && (!(t.workspace?.name ?? "").startsWith("special:") || isMinimized(t)))
        list.sort((a, b) => {
            const ma = isMinimized(a) ? 1 : 0, mb = isMinimized(b) ? 1 : 0
            if (ma !== mb) return ma - mb
            return (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999)
        })
        return list
    }

    function step(dir) {
        if (!open) {
            Hyprland.refreshToplevels()
            windows = collect()
            if (windows.length < 2) {
                // Nothing to switch to
                windows = []
                return
            }
            selected = dir > 0 ? 1 : windows.length - 1
            open = true
            keys.forceActiveFocus()
            return
        }
        if (windows.length === 0) return
        selected = (selected + dir + windows.length) % windows.length
    }

    // While open the switcher holds the keyboard. When it lets go, Hyprland gives focus back to
    // the window used before, so focusing the picked one right away was undone. Let go first,
    // then go to the window a moment later.
    property var picked: null
    function confirm() {
        picked = windows[selected] ?? null
        open = false
        land.restart()
    }
    Timer {
        id: land
        interval: 60
        onTriggered: {
            const w = sw.picked
            sw.picked = null
            if (!w) return
            if (sw.isMinimized(w)) {
                MinimizeService.restore(w)   // grows back out of the dock, onto this workspace
                return
            }
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${sw.addr(w)}" })`)
            Hyprland.dispatch(`hl.dsp.window.alter_zorder({ mode = "top", window = "address:${sw.addr(w)}" })`)
        }
    }

    function cancel() { open = false }

    IpcHandler {
        target: "switcher"
        function next(): void { sw.step(1) }
        function prev(): void { sw.step(-1) }
    }

    // Safety: if the Alt release is missed, close after a while
    Timer {
        interval: 8000
        running: sw.open
        onTriggered: sw.confirm()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: sw.cancel()
    }

    Item {
        id: keys
        focus: true
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                sw.confirm()
                event.accepted = true
            }
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) sw.cancel()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) sw.confirm()
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) sw.step(1)
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) sw.step(-1)
            else return
            event.accepted = true
        }
    }

    Rectangle {
        id: panel
        // Soft shadow, so it floats over what is under it
        layer.enabled: Tokens.menuShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Tokens.shadowColor
            shadowBlur: Tokens.shadowBlur
            blurMax: 32
            shadowVerticalOffset: 2
        }
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, row.implicitWidth + 32)
        height: 132
        radius: 26
        color: Tokens.barBg
        border.color: Tokens.ink(0.08)
        border.width: 1
        opacity: sw.reveal
        scale: 0.94 + 0.06 * sw.reveal

        MouseArea { anchors.fill: parent }

        Row {
            id: row
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
            spacing: Tokens.spaceMd

            Repeater {
                model: sw.windows

                Item {
                    id: tile
                    scale: tileMouse.pressed ? Tokens.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: index === sw.selected
                    readonly property bool minimized: sw.isMinimized(modelData)
                    readonly property int wsId: modelData.workspace?.id ?? 0
                    readonly property bool otherWs: !minimized && wsId !== (Hyprland.focusedWorkspace?.id ?? -1)

                    width: 76
                    height: 76

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radiusXl
                        color: Qt.rgba(1, 1, 1, tile.isSelected ? 0.14 : 0)
                        border.color: tile.isSelected ? Tokens.fillHover : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 56
                        height: 56
                        sourceSize: Qt.size(112, 112)
                        source: sw.iconFor(tile.modelData)
                        opacity: tile.minimized ? 0.5 : 1
                        scale: tile.isSelected ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeGrow } }
                    }

                    // Which workspace it is on (or that it is minimized), when it is not this one
                    Rectangle {
                        visible: tile.otherWs || tile.minimized
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: Math.max(18, wsText.implicitWidth + 8)
                        height: 18
                        radius: 9
                        color: Tokens.surface
                        border.color: Tokens.border
                        border.width: 1

                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: tile.minimized ? "\u2013" : tile.wsId
                            color: Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSmall
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: sw.selected = tile.index
                        onClicked: {
                            sw.selected = tile.index
                            sw.confirm()
                        }
                    }
                }
            }
        }

        // Title of the selected window
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            text: {
                const w = sw.windows[sw.selected]
                if (!w) return ""
                const where = sw.isMinimized(w) ? "  ·  Minimized"
                    : (w.workspace?.id ?? 0) !== (Hyprland.focusedWorkspace?.id ?? -1) ? "  ·  Desktop " + w.workspace.id : ""
                return (w.title ?? "") + where
            }
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontBody
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }
}
