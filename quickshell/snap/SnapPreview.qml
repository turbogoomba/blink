import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

// Where a window will go when you let go of it at the edge of the screen. hypr/snap.lua
// writes "<monitor> x y w h" (or nothing, to hide it) to $XDG_RUNTIME_DIR/blink-snap and
// this watches the file. qs -c blink ipc call snap place/clear does the same by hand.
// A soft rounded box grows into place, like on macOS.
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

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/blink-snap"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const v = text().trim().split(/\s+/)
            if (v.length === 5) {
                p.monitor = v[0]
                p.target = Qt.rect(+v[1], +v[2], +v[3], +v[4])
                p.shown = true
            } else {
                p.shown = false
            }
        }
    }

    IpcHandler {
        target: "snap"
        function place(monitor: string, x: int, y: int, w: int, h: int): void {
            p.monitor = monitor
            p.target = Qt.rect(x, y, w, h)
            p.shown = true
        }
        function clear(): void { p.shown = false }
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
        // Grows a little into place, like on macOS
        scale: p.shown ? 1 : 0.94
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        // Gone quickly when the window lands in it
        Behavior on opacity { NumberAnimation { duration: p.shown ? 140 : 70 } }
    }
}
