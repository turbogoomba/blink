import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

// Where a window will go when you let go of it at the edge of the screen (hypr/snap.lua
// tells us: qs -c blink ipc call snap show <monitor> x y w h / hide). A soft rounded
// box grows into place under the window, like on macOS.
PanelWindow {
    id: p
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blink-snap"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}
    visible: shown || box.opacity > 0.01
    screen: Quickshell.screens.find(s => s.name === p.monitor) ?? Quickshell.screens[0]

    property string monitor: ""
    property bool shown: false
    property rect target: Qt.rect(0, 0, 0, 0)

    IpcHandler {
        target: "snap"
        function show(monitor: string, x: int, y: int, w: int, h: int): void {
            const wasShown = p.shown
            p.monitor = monitor
            p.target = Qt.rect(x, y, w, h)
            // Grow out from the middle of where it goes the first time
            if (!wasShown) {
                box.x = x + w / 2 - 20; box.y = y + h / 2 - 20
                box.width = 40; box.height = 40
            }
            p.shown = true
        }
        function hide(): void { p.shown = false }
    }

    Rectangle {
        id: box
        x: p.target.x
        y: p.target.y
        width: p.target.width
        height: p.target.height
        radius: Tokens.radiusXl
        color: Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.16)
        border.color: Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.55)
        border.width: 2
        opacity: p.shown ? 1 : 0
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }
}
