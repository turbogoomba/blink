import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../theme"
import "../services"

PanelWindow {
    id: cc
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "controlcenter"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---------- Åpne/lukke-animasjon ----------
    readonly property bool open: ShellState.controlCenterOpen
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    visible: open || progress > 0

    onOpenChanged: {
        if (open) {
            StyleService.refresh()
            armed = ""
            panel.forceActiveFocus()
        }
    }

    // Egne ikoner i quickshell/icons/
    function iconFile(name) { return Qt.resolvedUrl("../icons/" + name + ".svg") }

    // ---------- Data ----------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevice: btAdapter?.devices.values.find(d => d.connected) ?? null
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real batteryLevel: {
        const p = battery?.percentage ?? 0
        return p > 1 ? p / 100 : p
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging

    // ---------- Strøm ----------
    property string armed: ""
    Timer {
        id: armTimer
        interval: 3000
        onTriggered: cc.armed = ""
    }

    function close() {
        ShellState.controlCenterOpen = false
    }

    function power(id, cmd, needsConfirm) {
        if (needsConfirm && armed !== id) {
            armed = id
            armTimer.restart()
            return
        }
        armed = ""
        close()
        Quickshell.execDetached(cmd)
    }

    // ---------- Byggeklosser ----------
    component Card: Rectangle {
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.07)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
    }

    component IconCircle: Rectangle {
        id: ic
        property string icon: ""
        property string fallback: "application-x-executable"
        property url iconSource: ""   // egen SVG, brukes i stedet for icon hvis satt
        property bool active: false
        property int size: 30

        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: active ? Tokens.accent : Qt.rgba(1, 1, 1, 0.12)
        Behavior on color { ColorAnimation { duration: 150 } }

        Image {
            anchors.centerIn: parent
            width: ic.size * 0.5
            height: ic.size * 0.5
            sourceSize: Qt.size(width * 2, height * 2)
            source: ic.iconSource.toString() !== "" ? ic.iconSource : Quickshell.iconPath(ic.icon, ic.fallback)
        }
    }

    component ToggleRow: Item {
        id: tr
        property string icon: ""
        property string fallback: ""
        property url iconSource: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        signal clicked()

        implicitHeight: 44

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.06)
            visible: trMouse.containsMouse
        }

        IconCircle {
            id: trIcon
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            icon: tr.icon
            fallback: tr.fallback
            iconSource: tr.iconSource
            active: tr.active
        }

        Column {
            anchors.left: trIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: tr.title
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: tr.subtitle
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: trMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tr.clicked()
        }
    }

    component PowerButton: Item {
        id: pb
        property string powerId: ""
        property string icon: ""
        property string label: ""
        property var command: []
        property bool confirm: true
        readonly property bool isArmed: cc.armed === powerId

        Layout.fillWidth: true
        implicitHeight: 64

        Rectangle {
            id: pbCircle
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 40
            height: 40
            radius: 20
            color: pb.isArmed ? "#ff453a"
                 : pbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2)
                 : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: 150 } }

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                sourceSize: Qt.size(36, 36)
                source: cc.iconFile(pb.icon)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: pbCircle.bottom
            anchors.topMargin: 6
            text: pb.isArmed ? "Confirm?" : pb.label
            color: pb.isArmed ? Tokens.textPrimary : Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: 11
            font.weight: pb.isArmed ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: cc.power(pb.powerId, pb.command, pb.confirm)
        }
    }

    // En slider-rad (brukes av lysstyrke og lyd)
    component SliderCard: Card {
        id: sc
        property string title: ""
        property string icon: ""
        property real value: 0
        signal moved(real v)
        signal iconClicked()

        Layout.fillWidth: true
        implicitHeight: 76

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 12
            text: sc.title
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Image {
            id: scIcon
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)
            source: Quickshell.iconPath(sc.icon)

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: sc.iconClicked()
            }
        }

        Item {
            id: scSlider
            anchors.left: scIcon.right
            anchors.leftMargin: 10
            anchors.right: scPct.left
            anchors.rightMargin: 10
            anchors.verticalCenter: scIcon.verticalCenter
            height: 20

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.15)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, sc.value))
                    height: parent.height
                    radius: 3
                    color: Tokens.textPrimary
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => sc.moved(Math.max(0, Math.min(1, mouse.x / scSlider.width)))
                onPositionChanged: mouse => sc.moved(Math.max(0, Math.min(1, mouse.x / scSlider.width)))
            }
        }

        Text {
            id: scPct
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: scIcon.verticalCenter
            width: 32
            horizontalAlignment: Text.AlignRight
            text: Math.round(sc.value * 100) + "%"
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: 11
        }
    }

    // ---------- Klikk utenfor lukker ----------
    MouseArea {
        anchors.fill: parent
        onClicked: cc.close()
    }

    // ---------- Selve panelet ----------
    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Tokens.barHeight + 8
        anchors.rightMargin: 8
        width: 340
        height: content.implicitHeight + 24
        radius: 20
        color: Tokens.bg
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        opacity: cc.progress
        scale: 0.94 + 0.06 * cc.progress
        transformOrigin: Item.TopRight

        focus: true
        Keys.onEscapePressed: cc.close()

        // Klikk inni panelet skal ikke lukke
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            // ---------- Tilkobling + fliser ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 104

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        ToggleRow {
                            Layout.fillWidth: true
                            icon: "network-wireless-symbolic"
                            fallback: "network-wireless"
                            title: "Wi-Fi"
                            subtitle: NetworkService.ethernetConnected ? "Ethernet"
                                : !NetworkService.wifiEnabled ? "Off"
                                : NetworkService.connected ? NetworkService.ssid
                                : "Not connected"
                            active: NetworkService.wifiEnabled
                            onClicked: NetworkService.toggleWifi()
                        }

                        ToggleRow {
                            Layout.fillWidth: true
                            icon: "bluetooth-active-symbolic"
                            fallback: "bluetooth"
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
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 10

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 47

                        ToggleRow {
                            anchors.fill: parent
                            anchors.margins: 2
                            icon: "notifications-disabled-symbolic"
                            fallback: "notification-disabled"
                            title: "Focus"
                            subtitle: ShellState.doNotDisturb ? "On" : "Off"
                            active: ShellState.doNotDisturb
                            onClicked: ShellState.doNotDisturb = !ShellState.doNotDisturb
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 47

                        ToggleRow {
                            anchors.fill: parent
                            anchors.margins: 2
                            iconSource: cc.iconFile(StyleService.mode === "floating" ? "floating" : "tiling")
                            title: "Windows"
                            subtitle: StyleService.mode === "floating" ? "Floating" : "Tiling"
                            active: StyleService.mode === "floating"
                            onClicked: StyleService.toggle()
                        }
                    }
                }
            }

            // ---------- Lysstyrke ----------
            SliderCard {
                visible: BrightnessService.available
                title: "Display"
                icon: "display-brightness-symbolic"
                value: BrightnessService.value
                onMoved: v => BrightnessService.set(v)
            }

            // ---------- Lyd ----------
            SliderCard {
                title: "Sound"
                icon: cc.audio?.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                value: cc.audio?.muted ? 0 : Math.min(cc.audio?.volume ?? 0, 1)
                onMoved: v => {
                    if (!cc.audio) return
                    cc.audio.muted = false
                    cc.audio.volume = v
                }
                onIconClicked: if (cc.audio) cc.audio.muted = !cc.audio.muted
            }

            // ---------- Batteri (bare på maskiner med batteri) ----------
            Card {
                Layout.fillWidth: true
                implicitHeight: 64
                visible: cc.hasBattery

                IconCircle {
                    id: batIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "battery-level-" + Math.round(cc.batteryLevel * 10) * 10
                          + (cc.charging ? "-charging" : "") + "-symbolic"
                    fallback: "battery"
                    active: cc.charging
                }

                Column {
                    anchors.left: batIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            text: "Battery"
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.right: parent.right
                            text: Math.round(cc.batteryLevel * 100) + "%"
                                  + (cc.charging ? "  ·  Charging" : "")
                            color: Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.15)

                        Rectangle {
                            width: parent.width * cc.batteryLevel
                            height: parent.height
                            radius: 2
                            color: cc.batteryLevel < 0.2 && !cc.charging ? "#ff453a" : Tokens.textPrimary
                        }
                    }
                }
            }

            // ---------- Strøm ----------
            Card {
                Layout.fillWidth: true
                implicitHeight: 84

                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: 12
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 0

                    PowerButton {
                        powerId: "sleep"
                        icon: "sleep"
                        label: "Sleep"
                        command: ["systemctl", "suspend"]
                        confirm: false
                    }
                    PowerButton {
                        powerId: "logout"
                        icon: "logout"
                        label: "Log Out"
                        command: ["hyprctl", "dispatch", "hl.dsp.exit()"]
                    }
                    PowerButton {
                        powerId: "restart"
                        icon: "restart"
                        label: "Restart"
                        command: ["systemctl", "reboot"]
                    }
                    PowerButton {
                        powerId: "shutdown"
                        icon: "power"
                        label: "Shut Down"
                        command: ["systemctl", "poweroff"]
                    }
                }
            }
        }
    }
}
