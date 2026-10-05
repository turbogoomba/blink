import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "../theme"
import "../services"

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }

    readonly property int notchDrop: 14
    implicitHeight: 320
    exclusiveZone: Tokens.barHeight
    color: "transparent"

    // Batteri (bare hvis maskinen har det)
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real batteryLevel: {
        const p = battery?.percentage ?? 0
        return p > 1 ? p / 100 : p
    }
    readonly property bool charging: !UPower.onBattery


    mask: Region {
        item: barRect
        Region { item: notch }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Lite element: ikon + tekst, klikkbart
    component BarItem: Item {
        id: bi
        scale: biMouse.pressed ? Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
        property url iconSource: ""
        property string text: ""
        property color textColor: Tokens.textPrimary
        signal clicked()

        implicitWidth: biRow.implicitWidth
        implicitHeight: biRow.implicitHeight

        Row {
            id: biRow
            spacing: 5

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 15
                height: 15
                sourceSize: Qt.size(30, 30)
                source: bi.iconSource
                opacity: biMouse.containsMouse ? 1 : 0.85
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bi.text
                color: bi.textColor
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }

        MouseArea {
            id: biMouse
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: bi.clicked()
        }
    }

    // Hollow ring that fills up with the usage. Orange over 70 %, red over 85 %.
    component RingStat: Item {
        id: rs
        scale: rsMouse.pressed ? Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
        property string label: ""
        property real value: 0
        property color baseColor: Tokens.accent

        property real shown: Math.max(0, Math.min(1, value))
        Behavior on shown { NumberAnimation { duration: 600; easing.type: Tokens.easeMove } }

        readonly property color ringColor: value > 0.85 ? "#ff453a"
            : value > 0.7 ? Tokens.orange : baseColor

        implicitWidth: rsRow.implicitWidth
        implicitHeight: 16

        Row {
            id: rsRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Canvas {
                id: ring
                anchors.verticalCenter: parent.verticalCenter
                width: 15
                height: 15

                property real v: rs.shown
                property color c: rs.ringColor
                onVChanged: requestPaint()
                onCChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = width / 2 - 1.5
                    ctx.lineWidth = 2.5
                    ctx.lineCap = "round"
                    ctx.strokeStyle = "rgba(255,255,255,0.15)"
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
            }
        }

        // Name under the bar while hovering
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Tokens.barHeight - 2
            width: tipText.implicitWidth + 14
            height: 22
            radius: Tokens.radiusSm
            color: Tokens.surface
            border.color: Tokens.border
            border.width: 1
            opacity: rsMouse.containsMouse ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }

            Text {
                id: tipText
                anchors.centerIn: parent
                text: rs.label + "  " + Math.round(rs.value * 100) + " %"
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
            }
        }

        MouseArea {
            id: rsMouse
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
        }
    }

    Rectangle {
        id: barRect
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Tokens.barHeight
        color: Tokens.barBg

        // The notch face looks toward the mouse while it is over the bar
        HoverHandler { id: barHover }

        // Workspace switch: a streak of light runs out from the notch in that direction
        Rectangle {
            id: sweep
            y: parent.height - 2
            width: 220
            height: 2
            radius: 1
            opacity: 0
            visible: opacity > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Tokens.accent }
                GradientStop { position: 1; color: "transparent" }
            }

            Connections {
                target: OsdService
                function onWsTickChanged() {
                    if (OsdService.wsMonitor !== (bar.screen?.name ?? "")) return
                    const start = barRect.width / 2 - sweep.width / 2
                    sweepX.from = start
                    sweepX.to = OsdService.wsDir > 0 ? barRect.width * 0.75 : barRect.width * 0.25 - sweep.width
                    sweepAnim.restart()
                }
            }

            ParallelAnimation {
                id: sweepAnim
                NumberAnimation { id: sweepX; target: sweep; property: "x"; duration: 520; easing.type: Tokens.easeMove }
                SequentialAnimation {
                    NumberAnimation { target: sweep; property: "opacity"; from: 0; to: 1; duration: Tokens.durFast }
                    NumberAnimation { target: sweep; property: "opacity"; to: 0; duration: 430; easing.type: Tokens.easeShrink }
                }
            }
        }

        // ---------- Venstre: arbeidsflater + aktivt vindu ----------
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            // Startup: slides out from the notch
            opacity: BootService.bar
            transform: Translate { x: (1 - BootService.bar) * 60 }

            // Arbeidsflater
            Rectangle {
                id: wsArea
                anchors.verticalCenter: parent.verticalCenter
                width: wsRow.implicitWidth + 16
                height: 18
                radius: 9
                color: Tokens.fillIdle

                readonly property var monitor: Hyprland.monitorFor(bar.screen)
                readonly property var workspaces: Hyprland.workspaces.values
                    .filter(w => w.id > 0 && w.monitor?.name === monitor?.name)
                    .sort((a, b) => a.id - b.id)
                readonly property int activeIndex:
                    workspaces.findIndex(w => w.id === monitor?.activeWorkspace?.id)

                readonly property int dot: 7
                readonly property int gap: 10
                readonly property int pillWidth: 20
                property int lastIndex: 0

                function centerOf(i) { return 8 + i * (dot + gap) + dot / 2 }

                // Flytt pillen med "væske"-effekt
                function moveTo(i, animate) {
                    if (i < 0) return
                    const c = centerOf(i)
                    const goingRight = i > lastIndex
                    leftAnim.to = c - pillWidth / 2
                    rightAnim.to = c + pillWidth / 2
                    leftAnim.duration = goingRight ? 320 : 160
                    rightAnim.duration = goingRight ? 160 : 320
                    lastIndex = i
                    if (animate) {
                        liquid.restart()
                    } else {
                        pill.lx = leftAnim.to
                        pill.rx = rightAnim.to
                    }
                }

                onActiveIndexChanged: moveTo(activeIndex, true)
                onWorkspacesChanged: moveTo(activeIndex, false)
                Component.onCompleted: moveTo(activeIndex, false)

                // Prikkene
                Row {
                    id: wsRow
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: wsArea.gap

                    Repeater {
                        model: wsArea.workspaces

                        delegate: Rectangle {
                            id: ws
                            scale: wsMouse.pressed ? Tokens.pressScale : 1
                            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            width: wsArea.dot
                            height: wsArea.dot
                            radius: wsArea.dot / 2
                            color: wsMouse.containsMouse ? Tokens.textPrimary : Tokens.textSecondary
                            Behavior on color { ColorAnimation { duration: Tokens.durFast } }

                            MouseArea {
                                id: wsMouse
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                anchors.margins: -5
                                hoverEnabled: true
                                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws.modelData.id}" })`)
                            }
                        }
                    }
                }

                // Den aktive pillen
                Rectangle {
                    id: pill
                    property real lx: 0
                    property real rx: 0

                    x: lx
                    width: rx - lx
                    anchors.verticalCenter: parent.verticalCenter
                    height: wsArea.dot
                    radius: wsArea.dot / 2
                    color: Tokens.accent

                    ParallelAnimation {
                        id: liquid
                        NumberAnimation { id: leftAnim;  target: pill; property: "lx"; easing.type: Tokens.easeMove }
                        NumberAnimation { id: rightAnim; target: pill; property: "rx"; easing.type: Tokens.easeMove }
                    }
                }

                // Scroll for å bla mellom arbeidsflater
                WheelHandler {
                    onWheel: event => {
                        const dir = event.angleDelta.y > 0 ? "e-1" : "e+1"
                        Hyprland.dispatch(`hl.dsp.focus({ workspace = "${dir}" })`)
                    }
                }
            }

            // Aktivt vindu
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: barRect.width / 3
                text: ToplevelManager.activeToplevel?.title ?? ""
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
        }

        // ---------- Høyre ----------
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            opacity: BootService.bar
            transform: Translate { x: -(1 - BootService.bar) * 60 }

            // Vær
            BarItem {
                id: weatherItem
                visible: WeatherService.ready
                anchors.verticalCenter: parent.verticalCenter
                iconSource: Quickshell.iconPath(WeatherService.icon, "weather-overcast")
                text: Math.round(WeatherService.temperature) + "°"
                onClicked: {
                    ShellState.weatherAnchorX = weatherItem.mapToItem(null, weatherItem.width / 2, 0).x
                    ShellState.weatherOpen = !ShellState.weatherOpen
                }
            }

            // CPU og RAM som ringer
            RingStat {
                anchors.verticalCenter: parent.verticalCenter
                label: "CPU"
                value: SystemService.cpu
                baseColor: Tokens.accent
            }
            RingStat {
                anchors.verticalCenter: parent.verticalCenter
                label: "Memory"
                value: SystemService.ram
                baseColor: "#bf5af2"
            }

            // Lyd: ikonet viser volumet, klikk åpner lydmenyen
            Item {
                id: soundItem
                scale: soundMouse.pressed ? Tokens.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 16
                implicitHeight: 16

                readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
                readonly property real vol: audio?.volume ?? 0
                readonly property bool muted: audio?.muted ?? false

                PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    sourceSize: Qt.size(32, 32)
                    opacity: ShellState.soundOpen || soundMouse.containsMouse ? 1 : 0.85
                    source: Quickshell.iconPath(
                          soundItem.muted || soundItem.vol === 0 ? "audio-volume-muted-symbolic"
                        : soundItem.vol < 0.34 ? "audio-volume-low-symbolic"
                        : soundItem.vol < 0.67 ? "audio-volume-medium-symbolic"
                        : "audio-volume-high-symbolic", "audio-volume-high")
                }

                MouseArea {
                    id: soundMouse
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: {
                        ShellState.soundAnchorX = soundItem.mapToItem(null, soundItem.width / 2, 0).x
                        ShellState.soundOpen = !ShellState.soundOpen
                    }
                }

                // Scroll on the icon to change the volume
                WheelHandler {
                    onWheel: event => {
                        if (!soundItem.audio) return
                        soundItem.audio.muted = false
                        soundItem.audio.volume = Math.max(0, Math.min(1, soundItem.audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)))
                    }
                }
            }

            // Batteri + klokke (klikk åpner kontrollpanelet)
            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: ccRow.implicitWidth
                implicitHeight: ccRow.implicitHeight

                Row {
                    id: ccRow
                    spacing: 14

                    // Control Center icon: two little switches
                    Item {
                        id: ccIcon
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15
                        height: 12
                        opacity: ShellState.controlCenterOpen ? 1 : 0.85

                        Repeater {
                            model: 2
                            Rectangle {
                                required property int index
                                y: index * 7
                                width: 15
                                height: 5
                                radius: 2.5
                                color: "transparent"
                                border.color: Tokens.textPrimary
                                border.width: 1.2

                                Rectangle {
                                    x: index === 0 ? 1.5 : parent.width - width - 1.5
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    color: Tokens.textPrimary
                                }
                            }
                        }
                    }

                    Row {
                        visible: bar.hasBattery
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(bar.batteryLevel * 100) + "%"
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontBody
                            font.weight: Font.Medium
                        }

                        // Liggende batteri
                        Item {
                            id: batIcon
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 11

                            readonly property color fillColor:
                                  bar.charging ? Tokens.green
                                : PowerProfiles.profile === PowerProfile.PowerSaver ? Tokens.orange
                                : bar.batteryLevel < 0.2 ? Tokens.red
                                : Tokens.textPrimary

                            Rectangle {
                                id: batBody
                                width: 21
                                height: parent.height
                                radius: 3
                                color: "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.45)
                                border.width: 1

                                Rectangle {
                                    x: 2
                                    y: 2
                                    width: Math.max(2, (parent.width - 4) * bar.batteryLevel)
                                    height: parent.height - 4
                                    radius: 1.5
                                    color: batIcon.fillColor
                                    Behavior on width { NumberAnimation { duration: Tokens.durSlow } }
                                    Behavior on color { ColorAnimation { duration: Tokens.durNormal } }
                                }
                            }

                            Rectangle {
                                anchors.left: batBody.right
                                anchors.leftMargin: 1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 4
                                radius: 1
                                color: Qt.rgba(1, 1, 1, 0.45)
                            }
                        }
                    }

                    Text {
                        id: clockText
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "ddd d. MMM  HH:mm")
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontBody
                        font.weight: Font.Medium
                    }
                }

                // Clock opens the calendar, the rest (icon + battery) the Control Center
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: mouse => {
                        if (mouse.x - 6 >= clockText.x - 7)
                            ShellState.calendarOpen = !ShellState.calendarOpen
                        else
                            ShellState.controlCenterOpen = !ShellState.controlCenterOpen
                    }
                }
            }
        }
    }

    // Concave corners where the notch meets the bar
    // Never taller than the straight part of the notch's side, so it always lines up
    readonly property real filletSize: Math.max(0, Math.min(10, notch.height - Tokens.barHeight - notch.radius))

    component NotchFillet: Canvas {
        property bool mirrored: false
        y: Tokens.barHeight
        width: bar.filletSize
        height: bar.filletSize
        visible: bar.filletSize >= 1
        opacity: Math.max(0, Math.min(1, (BootService.notch - 0.6) / 0.4))
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            const r = width
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, r, r)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(mirrored ? r : 0, r, r, 0, Math.PI * 2)
            c.fill()
        }
    }
    NotchFillet { x: notch.x - bar.filletSize }
    NotchFillet { x: notch.x + notch.width; mirrored: true }

    Notch {
        id: notch
        onWidthChanged: ShellState.notchWidth = width
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        baseHeight: Tokens.barHeight + bar.notchDrop
        // Startup: drops out of the bar
        transform: Scale {
            origin.x: notch.width / 2
            origin.y: 0
            xScale: 0.2 + 0.8 * BootService.notch
            yScale: Math.max(0, BootService.notch)
        }
        lookTarget: barHover.hovered
            ? Math.max(-1, Math.min(1, (barHover.point.position.x - bar.width / 2) / (bar.width / 3)))
            : NaN
    }
}
