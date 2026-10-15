import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "../theme"
import "../services"

// Caelestia-style bar on the left edge. Used when Settings > Display & Dock > Bar position is "Left".
// Top to bottom: Blink face, workspaces, active window, then status and the clock, power at the bottom.
PanelWindow {
    id: side
    anchors { top: true; bottom: true; left: true }
    implicitWidth: SettingsService.sideWidth
    exclusiveZone: ShellState.gameMode ? 0 : SettingsService.sideWidth
    color: "transparent"
    WlrLayershell.namespace: "sidebar"

    readonly property int w: SettingsService.sideWidth

    // ---------- Game mode: hide until the mouse reaches the left edge ----------
    readonly property bool fullscreenActive: ToplevelManager.activeToplevel?.fullscreen ?? false
    readonly property bool popupOpen: ShellState.controlCenterOpen || ShellState.powerMenuOpen
    property bool revealed: true
    property real hideOffset: revealed ? 0 : w + 4
    Behavior on hideOffset { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }

    function updateReveal() {
        if (!ShellState.gameMode || barHover.hovered || edgeHover.hovered || popupOpen) {
            hideTimer.stop()
            revealed = true
        } else {
            hideTimer.restart()
        }
    }
    Connections {
        target: ShellState
        function onGameModeChanged() { side.updateReveal() }
    }
    onPopupOpenChanged: updateReveal()
    Component.onCompleted: updateReveal()
    Timer { id: hideTimer; interval: 600; onTriggered: side.revealed = false }

    mask: Region {
        item: barRect
        Region { item: edgeZone }
    }

    Item {
        id: edgeZone
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: ShellState.gameMode && !side.fullscreenActive ? 3 : 0
        HoverHandler {
            id: edgeHover
            onHoveredChanged: side.updateReveal()
        }
    }

    // ---------- Data ----------
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real batteryLevel: {
        const p = battery?.percentage ?? 0
        return p > 1 ? p / 100 : p
    }

    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // ---------- Building blocks ----------
    component IconButton: Item {
        id: ib
        property string d: ""
        property color tint: Tokens.textPrimary
        property real size: 18
        property string tip: ""
        signal clicked()
        signal wheel(int delta)

        width: side.w
        height: 30
        scale: ibMouse.pressed ? Tokens.pressScaleIcon : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        Rectangle {
            anchors.centerIn: parent
            width: 34
            height: 30
            radius: Tokens.radiusMd
            color: Tokens.fillHover
            opacity: ibMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
        }

        LineIcon {
            anchors.centerIn: parent
            d: ib.d
            tint: ib.tint
            size: ib.size
        }

        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
            onWheel: wheel => ib.wheel(wheel.angleDelta.y)
        }
    }

    readonly property var icons: ({
        coffee:  "M4 9h12v6a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4zM16 11h2a2 2 0 0 1 0 4h-2M8 3v3M12 3v3",
        volume:  "M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6M19 6a8 8 0 0 1 0 12",
        muted:   "M4 9v6h4l5 4V5L8 9zM17 9l5 6M22 9l-5 6",
        sliders: "M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1M15 4v4M9 10v4M17 16v4",
        power:   "M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0"
    })

    // ================= The bar =================
    Rectangle {
        id: barRect
        x: -side.hideOffset
        width: side.w
        height: parent.height
        color: Tokens.barBg
        opacity: BootService.bar
        HoverHandler {
            id: barHover
            onHoveredChanged: side.updateReveal()
        }

        // ---------- Top: face + workspaces ----------
        Column {
            id: topCol
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            // Blink face: opens the notch panel
            Rectangle {
                id: face
                anchors.horizontalCenter: parent.horizontalCenter
                width: 38
                height: 30
                radius: Tokens.radiusMd
                color: faceMouse.containsMouse ? Tokens.fillStrong : Tokens.fillHover
                scale: faceMouse.pressed ? Tokens.pressScale : 1
                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Repeater {
                        model: 2
                        Rectangle {
                            width: 4
                            height: faceMouse.containsMouse ? 9 : 7
                            radius: 2
                            color: Tokens.textPrimary
                            Behavior on height { NumberAnimation { duration: Tokens.durFast } }
                        }
                    }
                }

                MouseArea {
                    id: faceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.notchToggleTick++
                }
            }

            Workspaces {
                anchors.horizontalCenter: parent.horizontalCenter
                targetScreen: side.screen
                vertical: true
            }
        }

        // ---------- Middle: active window, written upward ----------
        Item {
            anchors.top: topCol.bottom
            anchors.bottom: bottomCol.top
            anchors.topMargin: 16
            anchors.bottomMargin: 16
            width: parent.width

            Text {
                anchors.centerIn: parent
                width: parent.height
                rotation: -90
                horizontalAlignment: Text.AlignHCenter
                text: ToplevelManager.activeToplevel?.title ?? ""
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.barFont
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
        }

        // ---------- Bottom: status, clock, power ----------
        Column {
            id: bottomCol
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: parent.width
            spacing: 6

            IconButton {
                visible: IdleService.awake
                d: side.icons.coffee
                tint: Tokens.accent
                onClicked: ShellState.powerMenuOpen = !ShellState.powerMenuOpen
            }

            // Sound: click to mute, scroll to change the volume
            IconButton {
                d: (side.audio?.muted ?? false) ? side.icons.muted : side.icons.volume
                tint: (side.audio?.muted ?? false) ? Tokens.textSecondary : Tokens.textPrimary
                onClicked: if (side.audio) side.audio.muted = !side.audio.muted
                onWheel: delta => {
                    if (!side.audio) return
                    side.audio.volume = Math.max(0, Math.min(1, side.audio.volume + (delta > 0 ? 0.05 : -0.05)))
                }
            }

            IconButton {
                d: side.icons.sliders
                tint: ShellState.controlCenterOpen ? Tokens.accent : Tokens.textPrimary
                onClicked: ShellState.controlCenterOpen = !ShellState.controlCenterOpen
            }

            // Battery: percent over a small upright battery
            Column {
                visible: side.hasBattery
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                topPadding: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(side.batteryLevel * 100)
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 11
                    height: 18
                    radius: 3
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.45)
                    border.width: 1.2

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 4
                        height: Math.max(2, (parent.height - 4) * side.batteryLevel)
                        radius: 1.5
                        color: !UPower.onBattery ? Tokens.green
                             : side.batteryLevel < 0.2 ? Tokens.red
                             : Tokens.textPrimary
                    }
                }
            }

            // Clock, hours over minutes
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6
                bottomPadding: 4

                Repeater {
                    model: [Qt.formatDateTime(clock.date, "HH"), Qt.formatDateTime(clock.date, "mm")]
                    Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.barFont + 1
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        lineHeight: 0.95
                    }
                }
            }

            // Power menu
            Item {
                width: parent.width
                height: 38
                Rectangle {
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                    radius: 17
                    color: Qt.rgba(1, 0.27, 0.23, powerMouse.containsMouse || ShellState.powerMenuOpen ? 0.3 : 0.18)
                    scale: powerMouse.pressed ? Tokens.pressScaleIcon : 1
                    Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                    Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

                    LineIcon {
                        anchors.centerIn: parent
                        d: side.icons.power
                        tint: "#ff6961"
                        size: 16
                    }
                }
                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.powerMenuOpen = !ShellState.powerMenuOpen
                }
            }
        }
    }
}
