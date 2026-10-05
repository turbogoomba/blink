import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../theme"
import "../services"

Scope {
    id: root
    property bool open: false
    property int index: 0

    // Må stemme med Frame.qml
    readonly property int frameThickness: 6
    readonly property int fillet: 14

    function syncIndex() {
        const i = WallpaperService.files.indexOf(WallpaperService.current)
        if (i >= 0) index = i
    }
    function toggle() {
        if (!open) {
            WallpaperService.refresh()
            syncIndex()
        }
        open = !open
    }
    function close() { open = false }
    function choose() {
        const f = WallpaperService.files[index]
        if (f) WallpaperService.apply(f, "grow")
        close()
    }

    Connections {
        target: WallpaperService
        function onFilesChanged() { if (root.open) root.syncIndex() }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle() }
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wallpaper"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property real progress: root.open ? 1 : 0
        Behavior on progress { NumberAnimation { duration: Tokens.durSlow; easing.type: Tokens.easeMove } }
        visible: root.open || progress > 0

        onVisibleChanged: if (visible) keys.forceActiveFocus()

        // Demp resten av skjermen
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35 * win.progress)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Item {
            id: keys
            focus: true
            Keys.onLeftPressed: root.index = Math.max(0, root.index - 1)
            Keys.onRightPressed: root.index = Math.min(WallpaperService.files.length - 1, root.index + 1)
            Keys.onReturnPressed: root.choose()
            Keys.onEnterPressed: root.choose()
            Keys.onEscapePressed: root.close()
        }

        // ---------- Panelet som vokser opp av rammen ----------
        Item {
            id: sheet
            readonly property real fullHeight: content.implicitHeight + 44 + root.frameThickness

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 780
            height: fullHeight * win.progress

            // Svart flate, avrundet bare øverst
            Rectangle {
                anchors.fill: parent
                radius: Tokens.radiusXl
                color: Tokens.barBg
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.min(20, parent.height)
                color: Tokens.barBg
            }

            // Myke overganger der panelet møter rammen
            component Fillet: Canvas {
                property bool rightSide: false
                width: root.fillet
                height: root.fillet
                visible: sheet.height > root.fillet + root.frameThickness
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    c.fillStyle = Tokens.barBg.toString()
                    c.fillRect(0, 0, width, height)
                    c.globalCompositeOperation = "destination-out"
                    c.beginPath()
                    c.arc(rightSide ? width : 0, 0, width, 0, 2 * Math.PI)
                    c.fill()
                }
                Component.onCompleted: requestPaint()
            }
            Fillet {
                x: -width
                y: sheet.height - root.frameThickness - height
            }
            Fillet {
                rightSide: true
                x: sheet.width
                y: sheet.height - root.frameThickness - height
            }

            // Klikk inni panelet skal ikke lukke
            MouseArea { anchors.fill: parent }

            Item {
                anchors.fill: parent
                clip: true

                Column {
                    id: content
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    width: 720
                    spacing: Tokens.spaceLg
                    opacity: win.progress
                    readonly property string selected: WallpaperService.files[root.index] ?? ""

                    // Stor forhåndsvisning
                    ClippingRectangle {
                        width: parent.width
                        height: width * 9 / 16
                        radius: Tokens.radiusLg
                        color: Tokens.surface

                        Image {
                            anchors.fill: parent
                            source: content.selected !== "" ? "file://" + content.selected : ""
                            sourceSize.width: 1440
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: WallpaperService.files.length === 0
                            text: "Put pictures in ~/Pictures/Wallpapers"
                            color: Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontBody
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: content.selected !== "" ? WallpaperService.nameOf(content.selected) : ""
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontBody
                        font.weight: Font.DemiBold
                    }

                    // Stripe med små bilder
                    ListView {
                        id: strip
                        width: parent.width
                        height: 100
                        orientation: ListView.Horizontal
                        spacing: Tokens.spaceMd
                        clip: true
                        model: WallpaperService.files
                        currentIndex: root.index
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: width / 2 - 70
                        preferredHighlightEnd: width / 2 + 70
                        highlightMoveDuration: 250

                        delegate: Item {
                            id: thumb
                            scale: thumbMouse.pressed ? Tokens.pressScale : 1
                            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                            required property string modelData
                            required property int index
                            readonly property bool selected: index === root.index
                            readonly property bool isCurrent: modelData === WallpaperService.current

                            width: 140
                            height: 100

                            Rectangle {
                                anchors.fill: thumbImg
                                anchors.margins: -4
                                radius: Tokens.radiusMd
                                color: "transparent"
                                border.color: Tokens.accent
                                border.width: 2
                                visible: thumb.selected
                            }

                            ClippingRectangle {
                                id: thumbImg
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 4
                                width: 132
                                height: 74
                                radius: Tokens.radiusMd
                                color: Tokens.surface
                                opacity: thumb.selected ? 1 : 0.7

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + thumb.modelData
                                    sourceSize.width: 264
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            // Prikk under den som er i bruk nå
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: thumbImg.bottom
                                anchors.topMargin: Tokens.spaceSm
                                width: 5
                                height: 5
                                radius: 2.5
                                color: Tokens.textPrimary
                                visible: thumb.isCurrent
                            }

                            MouseArea {
                                id: thumbMouse
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                onClicked: root.index = thumb.index
                                onDoubleClicked: {
                                    root.index = thumb.index
                                    root.choose()
                                }
                            }
                        }
                    }

                    // ---------- Slideshow + velg ----------
                    Item {
                        width: parent.width
                        height: 34

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spaceMd

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Slideshow"
                                color: Tokens.textSecondary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: segRow.implicitWidth + 6
                                height: 28
                                radius: Tokens.radiusMd
                                color: Tokens.surface

                                Row {
                                    id: segRow
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Repeater {
                                        model: [
                                            { label: "Off", minutes: 0 },
                                            { label: "15 min", minutes: 15 },
                                            { label: "30 min", minutes: 30 },
                                            { label: "1 h", minutes: 60 }
                                        ]

                                        delegate: Rectangle {
                                            scale: press320.pressed ? Tokens.pressScale : 1
                                            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                                            required property var modelData
                                            readonly property bool on: WallpaperService.slideshowMinutes === modelData.minutes

                                            width: segText.implicitWidth + 18
                                            height: 22
                                            radius: Tokens.radiusSm
                                            color: on ? Tokens.accent : (press320.containsMouse ? Tokens.fillHover : "transparent")

                                            Text {
                                                id: segText
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: Tokens.textPrimary
                                                font.family: Tokens.fontFamily
                                                font.pixelSize: Tokens.fontBody
                                                font.weight: Font.Medium
                                            }

                                            MouseArea {
                                                id: press320
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                anchors.fill: parent
                                                onClicked: WallpaperService.setSlideshow(modelData.minutes)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            scale: setMouse.pressed ? Tokens.pressScale : 1
                            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: setText.implicitWidth + 28
                            height: 30
                            radius: Tokens.radiusMd
                            color: setMouse.containsMouse ? Qt.lighter(Tokens.accent, 1.1) : Tokens.accent

                            Text {
                                id: setText
                                anchors.centerIn: parent
                                text: "Set Wallpaper"
                                color: "white"
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: setMouse
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.choose()
                            }
                        }
                    }
                }
            }
        }
    }
}
