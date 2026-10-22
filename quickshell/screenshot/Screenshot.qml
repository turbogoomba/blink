import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../theme"
import "../services"

Scope {
    id: root
    property bool selecting: false
    property string pendingArgs: ""

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    // Ta bildet og kopier det. Then a small preview slides in at the bottom right
    // (like on a Mac): click to open, drag it into an app, or edit / show / delete it.
    property string shotFile: ""
    property string shotScreen: ""
    function capture(grimArgs) {
        const name = "Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png"
        const file = dir + "/" + name
        shotFile = file
        shotScreen = Hyprland.focusedMonitor?.name ?? ""
        shot.command = ["sh", "-c",
            `mkdir -p "${dir}" && grim ${grimArgs} "${file}" && wl-copy < "${file}"`]
        shot.running = true
        ShellState.screenshotTick++
    }

    Process {
        id: shot
        onExited: code => {
            if (code === 0) root.showPreview(root.shotFile, root.shotScreen)
        }
    }

    // ---------- Preview ----------
    property string previewFile: ""
    property string previewScreen: ""
    property int previewTick: 0           // restarts the slide-in for a new picture
    function showPreview(file, screenName) {
        previewFile = file
        previewScreen = screenName
        previewTick++
    }
    function closePreview() { previewFile = "" }

    // An editor if one is installed (satty, swappy), otherwise the image viewer
    property string editor: ""
    Process {
        running: true
        command: ["sh", "-c", "command -v satty || command -v swappy || true"]
        stdout: StdioCollector { onStreamFinished: root.editor = text.trim() }
    }
    function edit(file) {
        if (root.editor.endsWith("satty"))
            Quickshell.execDetached([root.editor, "--filename", file, "--output-filename", file])
        else if (root.editor.endsWith("swappy"))
            Quickshell.execDetached([root.editor, "-f", file, "-o", file])
        else
            Quickshell.execDetached(["xdg-open", file])
    }

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

    // The preview, on the screen the picture was taken on
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: pv
            required property var modelData
            screen: modelData
            readonly property bool shown: root.previewFile !== "" && root.previewScreen === (modelData?.name ?? "")
            visible: shown || slide.running

            anchors { bottom: true; right: true }
            margins { bottom: Tokens.frameT + 18; right: Tokens.frameT + 18 }
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 340
            implicitHeight: card.height + 8
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "screenshot-preview"

            readonly property int seconds: 6
            property real remaining: 1  // 1 -> 0 while it waits
            property bool paused: cardHover.hovered

            // Slide in from the right for every new picture
            Connections {
                target: root
                function onPreviewTickChanged() {
                    if (!pv.shown) return
                    pv.remaining = 1
                    card.x = pv.width
                    slide.to = 4
                    slide.restart()
                }
            }
            NumberAnimation { id: slide; target: card; property: "x"; duration: Tokens.durSlow; easing.type: Tokens.easeGrow; easing.overshoot: 1.2 }

            // Count down; pointing at it stops the clock and gives it its full time again
            Timer {
                interval: 50
                repeat: true
                running: pv.shown && !pv.paused
                onTriggered: {
                    pv.remaining -= interval / (pv.seconds * 1000)
                    if (pv.remaining <= 0) root.closePreview()
                }
            }
            onPausedChanged: if (paused) remaining = 1

            Rectangle {
                id: card
                x: 4
                width: parent.width - 8
                height: column.implicitHeight + 20
                radius: Tokens.radiusXl
                color: Tokens.bg
                border.color: Tokens.border
                border.width: 1

                HoverHandler { id: cardHover }

                Column {
                    id: column
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: Tokens.spaceSm

                    // The picture: click opens it, drag takes the file into an app
                    ClippingRectangle {
                        id: thumb
                        width: parent.width
                        height: 168
                        radius: Tokens.radiusMd
                        color: Tokens.surface

                        Image {
                            anchors.fill: parent
                            source: pv.shown ? "file://" + root.previewFile : ""
                            sourceSize: Qt.size(640, 340)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }

                        // Time left
                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            height: 3
                            width: parent.width * pv.remaining
                            color: Tokens.accent
                        }

                        Item {
                            id: dragProxy
                            Drag.active: thumbMouse.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.mimeData: { "text/uri-list": "file://" + root.previewFile }
                            Drag.onDragFinished: root.closePreview()
                        }
                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            drag.target: dragProxy
                            onClicked: {
                                Quickshell.execDetached(["xdg-open", root.previewFile])
                                root.closePreview()
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 34

                        Column {
                            anchors.left: parent.left
                            anchors.right: buttons.left
                            anchors.rightMargin: Tokens.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "Copied to clipboard"
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: root.previewFile.replace(Quickshell.env("HOME"), "~")
                                color: Tokens.textSecondary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSmall
                                elide: Text.ElideMiddle
                            }
                        }

                        Row {
                            id: buttons
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spaceXs

                            PreviewButton {
                                icon: "document-edit-symbolic"
                                onClicked: { root.edit(root.previewFile); root.closePreview() }
                            }
                            PreviewButton {
                                icon: "folder-open-symbolic"
                                onClicked: { Quickshell.execDetached(["xdg-open", root.dir]); root.closePreview() }
                            }
                            PreviewButton {
                                icon: "user-trash-symbolic"
                                onClicked: { Quickshell.execDetached(["rm", "-f", root.previewFile]); root.closePreview() }
                            }
                            PreviewButton {
                                icon: "window-close-symbolic"
                                onClicked: root.closePreview()
                            }
                        }
                    }
                }
            }
        }
    }

    component PreviewButton: Rectangle {
        id: pb
        property string icon: ""
        signal clicked()
        width: 30
        height: 30
        radius: Tokens.radiusSm
        color: pbMouse.containsMouse ? Tokens.accent : Tokens.fillIdle
        scale: pbMouse.pressed ? Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        TintIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: Quickshell.iconPath(pb.icon)
            tint: pbMouse.containsMouse ? Tokens.onAccent : Tokens.textPrimary
        }
        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
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
