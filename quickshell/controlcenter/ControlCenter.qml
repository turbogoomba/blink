import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../theme"
import "../services"

PanelWindow {
    id: cc
    visible: ShellState.controlCenterOpen
    anchors { top: true; right: true }
    margins { top: Tokens.barHeight + 8; right: 8 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 320
    implicitHeight: content.implicitHeight + 24
    color: "transparent"

    // Sjekk modus hver gang panelet åpnes (i tilfelle du brukte Super+T)
    onVisibleChanged: if (visible) StyleService.refresh()

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevice: btAdapter?.devices.values.find(d => d.connected) ?? null

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Tokens.bg
        border.color: Tokens.border
        border.width: 1

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            // Wi-Fi og Bluetooth side om side
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Tile {
                    icon: "network-wireless-symbolic"
                    fallbackIcon: "network-wireless"
                    title: "Wi-Fi"
                    subtitle: NetworkService.ethernetConnected ? "Ethernet"
                        : !NetworkService.wifiEnabled ? "Off"
                        : NetworkService.connected ? NetworkService.ssid
                        : "Not connected"
                    active: NetworkService.wifiEnabled
                    onClicked: NetworkService.toggleWifi()
                }

                Tile {
                    icon: "bluetooth-active-symbolic"
                    fallbackIcon: "bluetooth"
                    title: "Bluetooth"
                    subtitle: !cc.btAdapter ? "Unavailable"
                        : !cc.btAdapter.enabled ? "Off"
                        : cc.btDevice ? cc.btDevice.name
                        : "On"
                    active: cc.btAdapter?.enabled ?? false
                    onClicked: {
                        if (cc.btAdapter)
                            cc.btAdapter.enabled = !cc.btAdapter.enabled
                    }
                }
            }

            // Ikke forstyrr og vindusmodus side om side
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Tile {
                    icon: "notifications-disabled-symbolic"
                    fallbackIcon: "notification-disabled"
                    title: "Do Not Disturb"
                    subtitle: ShellState.doNotDisturb ? "On" : "Off"
                    active: ShellState.doNotDisturb
                    onClicked: ShellState.doNotDisturb = !ShellState.doNotDisturb
                }

                Tile {
                    icon: StyleService.mode === "floating" ? "window-new-symbolic" : "view-grid-symbolic"
                    fallbackIcon: "preferences-system-windows"
                    title: "Window Mode"
                    subtitle: StyleService.mode === "floating" ? "Floating" : "Tiling"
                    active: StyleService.mode === "floating"
                    onClicked: StyleService.toggle()
                }
            }

            // Volum
            Rectangle {
                id: vol
                readonly property var audio: Pipewire.defaultAudioSink?.audio

                Layout.fillWidth: true
                implicitHeight: 64
                radius: 14
                color: Tokens.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "Sound"
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Item {
                        id: slider
                        Layout.fillWidth: true
                        implicitHeight: 20

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Tokens.border

                            Rectangle {
                                width: parent.width * Math.min(vol.audio?.volume ?? 0, 1)
                                height: parent.height
                                radius: 3
                                color: Tokens.textPrimary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            function setVolume(x) {
                                if (vol.audio)
                                    vol.audio.volume = Math.max(0, Math.min(1, x / slider.width))
                            }
                            onPressed: mouse => setVolume(mouse.x)
                            onPositionChanged: mouse => setVolume(mouse.x)
                        }
                    }
                }
            }
        }
    }
}
