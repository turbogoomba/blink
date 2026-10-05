import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

Scope {
    id: root
    property bool selecting: false
    property string pendingArgs: ""

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    // Ta bildet, kopier det, og send varsel
    function capture(grimArgs) {
        const name = "Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png"
        const file = dir + "/" + name
        shot.command = ["sh", "-c",
            `mkdir -p "${dir}" && grim ${grimArgs} "${file}" && wl-copy < "${file}" && ` +
            `notify-send -a "Screenshot" -i "${file}" "Screenshot saved" "${name}"`]
        shot.running = true
        ShellState.screenshotTick++
    }

    Process { id: shot }

    // Vent litt så overlegget er borte før bildet tas
    Timer {
        id: delay
        interval: 150
        onTriggered: root.capture(root.pendingArgs)
    }

    // Kommandoer fra keybinds
    IpcHandler {
        target: "screenshot"
        function region(): void { root.selecting = true }
        function screen(): void {
            root.pendingArgs = "-o " + (Hyprland.focusedMonitor?.name ?? "")
            delay.restart()
        }
    }

    // Ett overlegg per skjerm
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.selecting
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "screenshot"
            WlrLayershell.keyboardFocus: root.selecting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            property point p0: Qt.point(0, 0)
            property point p1: Qt.point(0, 0)
            property bool dragging: false

            readonly property real sx: Math.min(p0.x, p1.x)
            readonly property real sy: Math.min(p0.y, p1.y)
            readonly property real sw: Math.abs(p1.x - p0.x)
            readonly property real sh: Math.abs(p1.y - p0.y)

            readonly property color dim: Qt.rgba(0, 0, 0, 0.3)

            onVisibleChanged: {
                if (visible) {
                    dragging = false
                    keys.forceActiveFocus()
                }
            }

            // ---------- Demping ----------
            // Før du drar: hele skjermen dempet
            Rectangle {
                anchors.fill: parent
                color: win.dim
                visible: !win.dragging
            }
            // Mens du drar: alt utenom området er dempet
            Rectangle { visible: win.dragging; color: win.dim; x: 0; y: 0; width: parent.width; height: win.sy }
            Rectangle { visible: win.dragging; color: win.dim; x: 0; y: win.sy + win.sh; width: parent.width; height: parent.height - y }
            Rectangle { visible: win.dragging; color: win.dim; x: 0; y: win.sy; width: win.sx; height: win.sh }
            Rectangle { visible: win.dragging; color: win.dim; x: win.sx + win.sw; y: win.sy; width: parent.width - x; height: win.sh }

            // ---------- Markeringen ----------
            Rectangle {
                visible: win.dragging
                x: win.sx
                y: win.sy
                width: win.sw
                height: win.sh
                color: "transparent"
                border.color: "white"
                border.width: 1
            }

            // Størrelse ved siden av musepekeren
            Rectangle {
                visible: win.dragging && win.sw > 0
                x: win.p1.x + 12
                y: win.p1.y + 12
                width: sizeText.implicitWidth + 14
                height: 22
                radius: Tokens.radiusSm
                color: Qt.rgba(0, 0, 0, 0.7)

                Text {
                    id: sizeText
                    anchors.centerIn: parent
                    text: Math.round(win.sw) + " × " + Math.round(win.sh)
                    color: "white"
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall
                    font.weight: Font.Medium
                }
            }

            // ---------- Mus ----------
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor

                onPressed: mouse => {
                    win.p0 = Qt.point(mouse.x, mouse.y)
                    win.p1 = win.p0
                    win.dragging = true
                }
                onPositionChanged: mouse => {
                    if (win.dragging) win.p1 = Qt.point(mouse.x, mouse.y)
                }
                onReleased: {
                    win.dragging = false
                    root.selecting = false
                    // For lite område = avbryt
                    if (win.sw < 4 || win.sh < 4) return
                    const gx = Math.round(win.modelData.x + win.sx)
                    const gy = Math.round(win.modelData.y + win.sy)
                    root.pendingArgs = `-g "${gx},${gy} ${Math.round(win.sw)}x${Math.round(win.sh)}"`
                    delay.restart()
                }
            }

            // ---------- Tastatur ----------
            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: {
                    win.dragging = false
                    root.selecting = false
                }
            }
        }
    }
}
