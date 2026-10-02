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

    // ---------- Åpne/lukke ----------
    readonly property bool open: ShellState.controlCenterOpen
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    visible: open || progress > 0

    onOpenChanged: {
        if (open) {
            StyleService.refresh()
            NetworkService.refreshStatus()
            armed = ""
            panel.forceActiveFocus()
        }
    }

    // Kortene kommer inn ett og ett: order 0 først, så 1, 2 ...
    function stagger(order) {
        return Math.max(0, Math.min(1, progress * 1.6 - order * 0.1))
    }

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
    readonly property bool charging: !UPower.onBattery

    // "Charging · 1 h 20 min til fullt", "3 h 10 min igjen" osv.
    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return ""
        const h = Math.floor(seconds / 3600)
        const m = Math.round((seconds % 3600) / 60)
        return h > 0 ? h + " h " + m + " min" : m + " min"
    }
    readonly property string batteryStatus: {
        if (charging) {
            if (batteryLevel >= 0.99) return "Fully charged"
            const t = formatTime(battery?.timeToFull ?? 0)
            return t !== "" ? "Charging · " + t + " to full" : "Charging"
        }
        const t = formatTime(battery?.timeToEmpty ?? 0)
        return t !== "" ? t + " remaining" : "On battery"
    }

    function volumeIcon(v, muted) {
        if (muted || v <= 0.001) return "audio-volume-muted-symbolic"
        if (v < 0.34) return "audio-volume-low-symbolic"
        if (v < 0.67) return "audio-volume-medium-symbolic"
        return "audio-volume-high-symbolic"
    }

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

    // ============================================================
    // BYGGEKLOSSER
    // ============================================================

    // Kort som glir inn og lyser litt opp ved hover
    component Card: Rectangle {
        id: card
        property int order: 0
        readonly property real appear: cc.stagger(order)

        radius: 14
        color: cardHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.07)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        opacity: appear
        transform: Translate { y: (1 - card.appear) * 14 }

        Behavior on color { ColorAnimation { duration: 150 } }

        HoverHandler { id: cardHover }
    }

    // Rundt ikon som "popper" når det slås av/på
    component IconCircle: Rectangle {
        id: ic
        property string icon: ""
        property string fallback: "application-x-executable"
        property url iconSource: ""
        property bool active: false
        property color activeColor: Tokens.accent
        property int size: 30

        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: active ? activeColor : Qt.rgba(1, 1, 1, 0.12)
        Behavior on color { ColorAnimation { duration: 200 } }

        onActiveChanged: pop.restart()

        SequentialAnimation {
            id: pop
            NumberAnimation { target: ic; property: "scale"; to: 1.18; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: ic; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutBack }
        }

        Image {
            anchors.centerIn: parent
            width: ic.size * 0.5
            height: ic.size * 0.5
            sourceSize: Qt.size(width * 2, height * 2)
            source: ic.iconSource.toString() !== "" ? ic.iconSource : Quickshell.iconPath(ic.icon, ic.fallback)
        }
    }

    // Rad med ikon, tittel og undertekst. Gir etter når du trykker.
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
        scale: trMouse.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.06)
            opacity: trMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
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

    // Slider som blir tykkere ved hover og får en knott når du drar
    component SliderCard: Card {
        id: sc
        property string title: ""
        property string icon: ""
        property real value: 0
        signal moved(real v)
        signal iconClicked()

        readonly property real clamped: Math.max(0, Math.min(1, value))
        readonly property bool active: scMouse.containsMouse || scMouse.pressed

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
            scale: iconMouse.pressed ? 0.85 : 1
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            MouseArea {
                id: iconMouse
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

            // Sporet
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: sc.active ? 10 : 6
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.15)
                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                // Fyllet
                Rectangle {
                    width: parent.width * sc.clamped
                    height: parent.height
                    radius: parent.radius
                    color: Tokens.textPrimary
                    Behavior on width {
                        enabled: !scMouse.pressed
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }

            // Knotten
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(scSlider.width - width, scSlider.width * sc.clamped - width / 2))
                width: 16
                height: 16
                radius: 8
                color: "white"
                border.color: Qt.rgba(0, 0, 0, 0.2)
                border.width: 1
                opacity: sc.active ? 1 : 0
                scale: scMouse.pressed ? 1.15 : sc.active ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }

            MouseArea {
                id: scMouse
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                hoverEnabled: true
                onPressed: mouse => sc.moved(Math.max(0, Math.min(1, mouse.x / scSlider.width)))
                onPositionChanged: mouse => {
                    if (pressed) sc.moved(Math.max(0, Math.min(1, mouse.x / scSlider.width)))
                }
            }
        }

        Text {
            id: scPct
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: scIcon.verticalCenter
            width: 32
            horizontalAlignment: Text.AlignRight
            text: Math.round(sc.clamped * 100) + "%"
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
    }

    // Strømknapp: gir etter ved trykk, pulserer mens den venter på bekreftelse
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
            scale: pbMouse.pressed ? 0.88 : 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

            SequentialAnimation {
                running: pb.isArmed
                loops: Animation.Infinite
                NumberAnimation { target: pbCircle; property: "opacity"; to: 0.65; duration: 380; easing.type: Easing.InOutSine }
                NumberAnimation { target: pbCircle; property: "opacity"; to: 1; duration: 380; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) pbCircle.opacity = 1
            }

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

    // ============================================================
    // VINDUET
    // ============================================================

    // Klikk utenfor lukker
    MouseArea {
        anchors.fill: parent
        onClicked: cc.close()
    }

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

        opacity: Math.min(1, cc.progress * 2)
        scale: 0.92 + 0.08 * cc.progress
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
                    order: 0
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
                            subtitle: !NetworkService.wifiEnabled ? "Off"
                                : NetworkService.connected ? NetworkService.ssid
                                : NetworkService.ethernetConnected ? "Ethernet"
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
                        order: 1
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
                        order: 2
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
                order: 3
                visible: BrightnessService.available
                title: "Display"
                icon: "display-brightness-symbolic"
                value: BrightnessService.value
                onMoved: v => BrightnessService.set(v)
            }

            // ---------- Lyd ----------
            SliderCard {
                order: 4
                title: "Sound"
                icon: cc.volumeIcon(cc.audio?.volume ?? 0, cc.audio?.muted ?? false)
                value: cc.audio?.muted ? 0 : (cc.audio?.volume ?? 0)
                onMoved: v => {
                    if (!cc.audio) return
                    cc.audio.muted = false
                    cc.audio.volume = v
                }
                onIconClicked: if (cc.audio) cc.audio.muted = !cc.audio.muted
            }

            // ---------- Batteri ----------
            Card {
                order: 5
                Layout.fillWidth: true
                implicitHeight: 64
                visible: cc.hasBattery

                // Samme liggende batteri som i baren, bare større
                Item {
                    id: bigBattery
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 17

                    readonly property color fillColor:
                          cc.charging ? "#30d158"
                        : cc.batteryLevel < 0.2 ? "#ff453a"
                        : Tokens.textPrimary

                    Rectangle {
                        id: bigBody
                        width: 32
                        height: parent.height
                        radius: 4.5
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.45)
                        border.width: 1.2

                        Rectangle {
                            x: 2.5
                            y: 2.5
                            width: Math.max(3, (parent.width - 5) * cc.batteryLevel)
                            height: parent.height - 5
                            radius: 2.5
                            color: bigBattery.fillColor
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    Rectangle {
                        anchors.left: bigBody.right
                        anchors.leftMargin: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2.5
                        height: 6
                        radius: 1.25
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }
                }

                Column {
                    anchors.left: bigBattery.right
                    anchors.leftMargin: 14
                    anchors.right: bigPct.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "Battery"
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: cc.batteryStatus
                        color: cc.charging ? "#30d158" : Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: bigPct
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(cc.batteryLevel * 100) + "%"
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            // ---------- Strøm ----------
            Card {
                order: 6
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
