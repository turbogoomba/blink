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
    Component.onCompleted: {
        updateReveal()
        SystemService.barStats = true   // the GPU ring needs the extra stats
    }
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

    Component.onDestruction: SystemService.barStats = false
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // ---------- Building blocks ----------
    component IconButton: Item {
        id: ib
        property string d: ""
        property color tint: Tokens.textPrimary
        property real size: 18
        property string tip: ""
        signal clicked()
        signal rightClicked()
        signal wheel(int delta)

        width: parent ? parent.width : side.w
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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? ib.rightClicked() : ib.clicked()
            onWheel: wheel => ib.wheel(wheel.angleDelta.y)
        }
    }

    // Rounded group of bar items
    component Island: Rectangle {
        default property alias content: islandCol.data
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        width: side.w - 12
        height: islandCol.implicitHeight + 8
        radius: 14
        color: Tokens.ink(0.06)
        Column {
            id: islandCol
            y: 4
            width: parent.width
            spacing: 2
        }
    }

    // Usage ring with the percent inside and a small label under it
    component StatRing: Item {
        id: sr
        property string label: ""
        property real value: 0
        property real shown: Math.max(0, Math.min(1, value))
        Behavior on shown { NumberAnimation { duration: 600; easing.type: Tokens.easeMove } }
        readonly property color tint: value > 0.85 ? Tokens.red : value > 0.7 ? Tokens.orange : Tokens.accent

        width: parent ? parent.width : side.w
        height: 44

        Canvas {
            readonly property string paintKey: Tokens.themeName + Tokens.accent
            onPaintKeyChanged: requestPaint()
            id: srRing
            anchors.horizontalCenter: parent.horizontalCenter
            y: 3
            width: 28
            height: 28
            property real v: sr.shown
            property color c: sr.tint
            onVChanged: requestPaint()
            onCChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const r = width / 2 - 2
                ctx.lineWidth = 2.5
                ctx.lineCap = "round"
                ctx.strokeStyle = Tokens.ink(0.12).toString()
                ctx.beginPath()
                ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI)
                ctx.stroke()
                if (v > 0.005) {
                    ctx.strokeStyle = c.toString()
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * v)
                    ctx.stroke()
                }
            }
            Component.onCompleted: requestPaint()

            Text {
                anchors.centerIn: parent
                text: Math.round(sr.shown * 100)
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: srRing.bottom
            anchors.topMargin: 1
            text: sr.label
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
            font.letterSpacing: 0.4
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
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

            // Blink face: opens the notch panel (Nook, Tray, Notifications)
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
            spacing: 8

            // CPU, RAM and GPU as rings
            Island {
                StatRing { label: "CPU"; value: SystemService.cpu }
                StatRing { label: "RAM"; value: SystemService.ram }
                StatRing { label: "GPU"; value: SystemService.gpu; visible: SystemService.gpu >= 0 }
            }

            // Weather, sound and control center
            Island {
                IconButton {
                    visible: IdleService.awake
                    d: side.icons.coffee
                    tint: Tokens.accent
                    onClicked: {
                        ShellState.powerMenuFrom = "left"
                        ShellState.powerMenuOpen = !ShellState.powerMenuOpen
                    }
                }

                // Weather: icon over the temperature, click for the forecast
                Item {
                    id: weatherBtn
                    visible: WeatherService.ready
                    width: parent.width
                    height: weatherCol.implicitHeight + 8
                    scale: weatherMouse.pressed ? Tokens.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 38
                        height: parent.height
                        radius: Tokens.radiusMd
                        color: Tokens.fillHover
                        opacity: weatherMouse.containsMouse || ShellState.weatherOpen ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                    }

                    Column {
                        id: weatherCol
                        anchors.centerIn: parent
                        spacing: 2
                        LineIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: Tokens.barIcon
                            d: WeatherService.glyph
                            tint: Tokens.textPrimary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(WeatherService.temperature) + "°"
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSmall
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: weatherMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ShellState.weatherAnchorY = weatherBtn.mapToItem(null, 0, weatherBtn.height / 2).y
                            ShellState.weatherOpen = !ShellState.weatherOpen
                        }
                    }
                }

                // Sound: click for the sound menu, right-click to mute, scroll to change the volume
                IconButton {
                    id: soundBtn
                    d: (side.audio?.muted ?? false) ? side.icons.muted : side.icons.volume
                    tint: ShellState.soundOpen ? Tokens.accent
                        : (side.audio?.muted ?? false) ? Tokens.textSecondary : Tokens.textPrimary
                    onClicked: {
                        ShellState.soundAnchorY = soundBtn.mapToItem(null, 0, soundBtn.height / 2).y
                        ShellState.soundOpen = !ShellState.soundOpen
                    }
                    onRightClicked: if (side.audio) side.audio.muted = !side.audio.muted
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
                    border.color: Tokens.ink(0.45)
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

            // Clock, hours over minutes (click for the calendar)
            Island {
                Item {
                    width: parent.width
                    height: clockCol.implicitHeight
                    scale: clockMouse.pressed ? Tokens.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 38
                        height: parent.height
                        radius: Tokens.radiusMd
                        color: Tokens.fillHover
                        opacity: clockMouse.containsMouse || ShellState.calendarOpen ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                    }

                    Column {
                        id: clockCol
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 6
                        bottomPadding: 6

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

                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.calendarOpen = !ShellState.calendarOpen
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
                    onClicked: {
                    ShellState.powerMenuFrom = "left"
                    ShellState.powerMenuOpen = !ShellState.powerMenuOpen
                }
                }
            }
        }
    }
}
