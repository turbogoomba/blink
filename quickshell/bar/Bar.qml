import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "../theme"
import "../services"

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }

    readonly property int notchDrop: 8
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
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging

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

        // ---------- Venstre: aktivt vindu ----------
        Text {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 3
            text: ToplevelManager.activeToplevel?.title ?? ""
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        // ---------- Høyre ----------
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            // Vær
            BarItem {
                visible: WeatherService.ready
                anchors.verticalCenter: parent.verticalCenter
                iconSource: Quickshell.iconPath(WeatherService.icon, "weather-overcast")
                text: Math.round(WeatherService.temperature) + "°"
                onClicked: Quickshell.execDetached(["xdg-open", "https://www.yr.no/nb/v%C3%A6rvarsel/daglig-tabell/1-72837/Norge/Oslo/Oslo/Oslo"])
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

                    Row {
                        visible: bar.hasBattery
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(bar.batteryLevel * 100) + "%"
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            sourceSize: Qt.size(36, 36)
                            source: Quickshell.iconPath(
                                "battery-level-" + Math.round(bar.batteryLevel * 10) * 10
                                + (bar.charging ? "-charging" : "") + "-symbolic", "battery")
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "ddd d. MMM  HH:mm")
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: ShellState.controlCenterOpen = !ShellState.controlCenterOpen
                }
            }
        }
    }

    Notch {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        baseHeight: Tokens.barHeight + bar.notchDrop
    }
}
