import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Mac-style Alt+Tab: a row of app icons, most recently used first.
// Hold Alt, tap Tab to move, let go of Alt to switch. Esc cancels.
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
    Behavior on reveal { NumberAnimation { duration: sw.open ? 220 : 120; easing.type: Tokens.easeMove } }
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

    // Windows sorted by when they were last focused
    function collect() {
        const list = Hyprland.toplevels.values.filter(t =>
            t.wayland && (t.workspace?.name ?? "") !== "special:minimized")
        list.sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999))
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

    function confirm() {
        const w = windows[selected]
        open = false
        if (w) Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(w)}" })`)
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
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, row.implicitWidth + 32)
        height: 132
        radius: 26
        color: Tokens.barBg
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        opacity: sw.reveal
        scale: 0.94 + 0.06 * sw.reveal

        MouseArea { anchors.fill: parent }

        Row {
            id: row
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
            spacing: 10

            Repeater {
                model: sw.windows

                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: index === sw.selected

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
                        scale: tile.isSelected ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeGrow } }
                    }

                    MouseArea {
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
            text: sw.windows[sw.selected]?.title ?? ""
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontBody
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }
}
