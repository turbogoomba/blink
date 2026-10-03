import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
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

    function iconFile(name) { return Qt.resolvedUrl("../icons/" + name + ".svg") }

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
                font.pixelSize: 12
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }

        MouseArea {
            id: biMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: bi.clicked()
        }
    }

    Rectangle {
        id: barRect
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Tokens.barHeight
        color: Tokens.barBg

        // The notch face looks toward the mouse while it is over the bar
        HoverHandler { id: barHover }

        // ---------- Venstre: arbeidsflater + aktivt vindu ----------
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // Arbeidsflater
            Rectangle {
                id: wsArea
                anchors.verticalCenter: parent.verticalCenter
                width: wsRow.implicitWidth + 16
                height: 18
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.07)

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
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            width: wsArea.dot
                            height: wsArea.dot
                            radius: wsArea.dot / 2
                            color: wsMouse.containsMouse ? Tokens.textPrimary : Tokens.textSecondary
                            Behavior on color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: wsMouse
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
                        NumberAnimation { id: leftAnim;  target: pill; property: "lx"; easing.type: Easing.OutCubic }
                        NumberAnimation { id: rightAnim; target: pill; property: "rx"; easing.type: Easing.OutCubic }
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
                font.pixelSize: 13
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

            // CPU
            BarItem {
                anchors.verticalCenter: parent.verticalCenter
                iconSource: bar.iconFile("cpu")
                text: Math.round(SystemService.cpu * 100) + "%"
                textColor: SystemService.cpu > 0.85 ? "#ff453a" : Tokens.textPrimary
                onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
            }

            // RAM
            BarItem {
                anchors.verticalCenter: parent.verticalCenter
                iconSource: bar.iconFile("memory")
                text: Math.round(SystemService.ram * 100) + "%"
                textColor: SystemService.ram > 0.85 ? "#ff453a" : Tokens.textPrimary
                onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
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
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        // Liggende batteri
                        Item {
                            id: batIcon
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 11

                            readonly property color fillColor:
                                  bar.charging ? "#30d158"
                                : PowerProfiles.profile === PowerProfile.PowerSaver ? "#ff9f0a"
                                : bar.batteryLevel < 0.2 ? "#ff453a"
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
                                    Behavior on width { NumberAnimation { duration: 300 } }
                                    Behavior on color { ColorAnimation { duration: 200 } }
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
                        font.pixelSize: 13
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
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        baseHeight: Tokens.barHeight + bar.notchDrop
        lookTarget: barHover.hovered
            ? Math.max(-1, Math.min(1, (barHover.point.position.x - bar.width / 2) / (bar.width / 3)))
            : NaN
    }
}
