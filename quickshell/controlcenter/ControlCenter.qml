import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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

    // Open on the monitor you are using (matters with two screens)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "controlcenter"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---------- Åpne/lukke ----------
    readonly property bool open: ShellState.controlCenterOpen
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Tokens.durSlow; easing.type: Tokens.easeMove } }
    // Height of the sheet: grows out of the bar with a little bounce
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: cc.open ? 460 : 260
            easing.type: cc.open ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: 0.9
        }
    }
    visible: open || progress > 0 || reveal > 0

    onOpenChanged: {
        if (open) {
            StyleService.refresh()
            NetworkService.refreshStatus()
            armed = ""
            modesOpen = false
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

    // The Modes tile unfolds a list (Do Not Disturb, Focus, Game Mode)
    property bool modesOpen: false
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

    // Small pill button (screen recording card)
    component SmallButton: Rectangle {
        id: sb
        property string label: ""
        property bool on: false
        signal clicked()
        width: sbText.implicitWidth + 18
        height: 26
        radius: 13
        color: on ? Tokens.accent
             : sbMouse.containsMouse ? Tokens.fillHover : Qt.rgba(1, 1, 1, 0.08)
        scale: sbMouse.pressed ? Tokens.pressScale : 1
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
        Text {
            id: sbText
            anchors.centerIn: parent
            text: sb.label
            color: sb.on ? "white" : Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
        }
        MouseArea {
            id: sbMouse
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            hoverEnabled: true
            onClicked: sb.clicked()
        }
    }

    // Kort som glir inn og lyser litt opp ved hover
    component Card: Rectangle {
        id: card
        property int order: 0
        readonly property real appear: cc.stagger(order)

        radius: Tokens.radiusLg
        color: cardHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Tokens.fillIdle
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        opacity: appear
        transform: Translate { y: (1 - card.appear) * 14 }

        Behavior on color { ColorAnimation { duration: Tokens.durFast } }

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
        color: active ? activeColor : Tokens.fillHover
        Behavior on color { ColorAnimation { duration: Tokens.durNormal } }

        onActiveChanged: pop.restart()

        SequentialAnimation {
            id: pop
            NumberAnimation { target: ic; property: "scale"; to: 1.18; duration: Tokens.durFast; easing.type: Tokens.easeMove }
            NumberAnimation { target: ic; property: "scale"; to: 1; duration: Tokens.durNormal; easing.type: Tokens.easeGrow }
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
        scale: trMouse.pressed ? Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusMd
            color: Qt.rgba(1, 1, 1, 0.06)
            opacity: trMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
        }

        IconCircle {
            id: trIcon
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            icon: tr.icon
            fallback: tr.fallback
            iconSource: tr.iconSource
            active: tr.active
        }

        Column {
            anchors.left: trIcon.right
            anchors.leftMargin: Tokens.spaceMd
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spaceSm
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: tr.title
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: tr.subtitle
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: trMouse
            cursorShape: Qt.PointingHandCursor
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
            anchors.leftMargin: Tokens.spaceLg
            anchors.top: parent.top
            anchors.topMargin: Tokens.spaceMd
            text: sc.title
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontBody
            font.weight: Font.DemiBold
        }

        Image {
            id: scIcon
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spaceLg
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.spaceLg
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)
            source: Quickshell.iconPath(sc.icon)
            scale: iconMouse.pressed ? Tokens.pressScaleIcon : 1
            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

            MouseArea {
                id: iconMouse
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                anchors.margins: -6
                onClicked: sc.iconClicked()
            }
        }

        Item {
            id: scSlider
            anchors.left: scIcon.right
            anchors.leftMargin: Tokens.spaceMd
            anchors.right: scPct.left
            anchors.rightMargin: Tokens.spaceMd
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
                Behavior on height { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

                // Fyllet
                Rectangle {
                    width: parent.width * sc.clamped
                    height: parent.height
                    radius: parent.radius
                    color: Tokens.textPrimary
                    Behavior on width {
                        enabled: !scMouse.pressed
                        NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove }
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
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
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
            anchors.rightMargin: Tokens.spaceLg
            anchors.verticalCenter: scIcon.verticalCenter
            width: 32
            horizontalAlignment: Text.AlignRight
            text: Math.round(sc.clamped * 100) + "%"
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
            font.features: { "tnum": 1 }
        }
    }

    // Strømknapp: gir etter ved trykk, pulserer mens den venter på bekreftelse
    component PowerButton: Item {
        id: pb
        scale: pbMouse.pressed ? Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
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
            color: pb.isArmed ? Tokens.red
                 : pbMouse.containsMouse ? Tokens.fillStrong
                 : Tokens.fillHover
            scale: pbMouse.pressed ? 0.88 : 1
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

            SequentialAnimation {
                running: pb.isArmed
                loops: Animation.Infinite
                NumberAnimation { target: pbCircle; property: "opacity"; to: 0.65; duration: Tokens.durSlow; easing.type: Easing.InOutSine }
                NumberAnimation { target: pbCircle; property: "opacity"; to: 1; duration: Tokens.durSlow; easing.type: Easing.InOutSine }
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
            anchors.topMargin: Tokens.spaceSm
            text: pb.isArmed ? "Confirm?" : pb.label
            color: pb.isArmed ? Tokens.textPrimary : Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
            font.weight: pb.isArmed ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: pbMouse
            cursorShape: Qt.PointingHandCursor
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

    // Concave corners where the sheet meets the bar and the right edge
    component Fillet: Canvas {
        width: 14
        height: 14
        opacity: Math.min(1, cc.reveal * 4)
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(0, 14, 14, 0, Math.PI * 2)
            c.fill()
        }
    }

    Fillet {
        id: filletTop
        x: panel.x - 14
        y: panel.y
    }

    Fillet {
        id: filletSide
        x: panel.x + panel.width - 14
        y: panel.y + panel.height
        visible: panel.height > 1
    }

    Item {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Tokens.barHeight
        anchors.rightMargin: Tokens.spaceSm
        width: 340
        readonly property real fullHeight: content.implicitHeight + 24
        height: fullHeight * Math.max(0, cc.reveal)
        clip: true

        focus: true
        Keys.onEscapePressed: cc.close()

        // Same black as the bar and frame. Only the bottom-left corner is rounded.
        Rectangle {
            x: 0
            y: -20
            width: parent.width + 20
            height: parent.height + 20
            radius: Tokens.radiusXl
            color: Tokens.barBg
        }

        // Klikk inni panelet skal ikke lukke
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: Tokens.spaceMd

            // ---------- Tilkobling + fliser ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spaceMd

                Card {
                    order: 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.spaceSm
                        spacing: Tokens.spaceXs

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

                        ToggleRow {
                            Layout.fillWidth: true
                            readonly property bool airplane: !NetworkService.wifiEnabled && !(cc.btAdapter?.enabled ?? false)
                            icon: "airplane-mode-symbolic"
                            fallback: "airplane-mode"
                            title: "Airplane Mode"
                            subtitle: airplane ? "On" : "Off"
                            active: airplane
                            onClicked: {
                                const on = !airplane
                                if (NetworkService.wifiEnabled === on) NetworkService.toggleWifi()
                                if (cc.btAdapter) cc.btAdapter.enabled = !on
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Tokens.spaceMd

                    Card {
                        order: 1
                        Layout.fillWidth: true
                        implicitHeight: 47

                        ToggleRow {
                            anchors.fill: parent
                            anchors.margins: 2
                            readonly property var current: ModeService.info(ShellState.mode)
                            icon: current?.icon ?? "notifications-disabled-symbolic"
                            fallback: "notification-disabled"
                            title: current?.label ?? "Modes"
                            subtitle: current ? "On" : cc.modesOpen ? "Choose a mode" : "Off"
                            active: current !== null
                            onClicked: cc.modesOpen = !cc.modesOpen
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

                    Card {
                        order: 2
                        Layout.fillWidth: true
                        implicitHeight: 47
                        visible: NightLightService.available

                        ToggleRow {
                            anchors.fill: parent
                            anchors.margins: 2
                            icon: "night-light-symbolic"
                            fallback: "weather-clear-night"
                            title: "Night Shift"
                            subtitle: NightLightService.enabled ? NightLightService.temperature + " K" : "Off"
                            active: NightLightService.enabled
                            onClicked: NightLightService.toggle()
                        }
                    }
                }
            }

            // ---------- Modes (unfolds from the Modes tile) ----------
            Card {
                id: modesCard
                order: 1
                Layout.fillWidth: true
                implicitHeight: cc.modesOpen ? modesCol.implicitHeight + 12 : 0
                visible: implicitHeight > 0.5
                clip: true
                Behavior on implicitHeight { NumberAnimation { duration: Tokens.durSlow; easing.type: Tokens.easeMove } }

                Column {
                    id: modesCol
                    x: 6
                    y: 6
                    width: parent.width - 12
                    spacing: 2
                    opacity: cc.modesOpen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.durNormal } }

                    Repeater {
                        model: ModeService.modes

                        delegate: Item {
                            id: mrow
                            required property var modelData
                            readonly property bool on: ShellState.mode === modelData.id

                            width: modesCol.width
                            height: 48
                            scale: mrowMouse.pressed ? Tokens.pressScale : 1
                            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

                            Rectangle {
                                anchors.fill: parent
                                radius: Tokens.radiusMd
                                color: Qt.rgba(1, 1, 1, 0.06)
                                opacity: mrowMouse.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                            }

                            IconCircle {
                                id: mIcon
                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.spaceSm
                                anchors.verticalCenter: parent.verticalCenter
                                icon: mrow.modelData.icon
                                active: mrow.on
                            }

                            Column {
                                anchors.left: mIcon.right
                                anchors.leftMargin: Tokens.spaceMd
                                anchors.right: mCheck.left
                                anchors.rightMargin: Tokens.spaceSm
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    width: parent.width
                                    text: mrow.modelData.label
                                    color: Tokens.textPrimary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: Tokens.fontBody
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: mrow.modelData.hint
                                    color: Tokens.textSecondary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: Tokens.fontSmall
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                id: mCheck
                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.spaceMd
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✓"
                                color: Tokens.accent
                                font.pixelSize: Tokens.fontTitle
                                font.weight: Font.Bold
                                opacity: mrow.on ? 1 : 0
                                scale: mrow.on ? 1 : 0.4
                                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                                Behavior on scale { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeGrow } }
                            }

                            MouseArea {
                                id: mrowMouse
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ModeService.toggle(mrow.modelData.id)
                            }
                        }
                    }
                }
            }

            // ---------- Screen recording ----------
            Card {
                order: 2
                Layout.fillWidth: true
                implicitHeight: 52

                ToggleRow {
                    anchors.left: parent.left
                    anchors.right: recButtons.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.spaceXs
                    icon: "media-record-symbolic"
                    fallback: "media-record"
                    title: "Screen Recording"
                    subtitle: RecordService.recording ? "Recording · " + RecordService.elapsed
                        : RecordService.compressing ? "Shrinking for Discord..."
                        : (RecordService.withAudio ? "With sound" : "No sound")
                          + (RecordService.forDiscord ? " · under 20 MB" : "")
                    active: RecordService.recording
                    onClicked: {
                        if (RecordService.recording) {
                            RecordService.stop()
                        } else {
                            cc.close()
                            startDelay.mode = "screen"
                            startDelay.restart()
                        }
                    }
                }

                // Wait for the panel to slide away so it is not in the video
                Timer {
                    id: startDelay
                    property string mode: "screen"
                    interval: 400
                    onTriggered: RecordService.start(mode)
                }

                Row {
                    id: recButtons
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spaceMd
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spaceSm
                    visible: !RecordService.recording

                    SmallButton {
                        label: "Sound"
                        on: RecordService.withAudio
                        onClicked: RecordService.withAudio = !RecordService.withAudio
                    }
                    SmallButton {
                        label: "Discord"
                        on: RecordService.forDiscord
                        onClicked: RecordService.forDiscord = !RecordService.forDiscord
                    }
                    SmallButton {
                        label: "Area"
                        onClicked: {
                            cc.close()
                            startDelay.mode = "area"
                            startDelay.restart()
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
                implicitHeight: 64 + 40
                visible: cc.hasBattery

                // Top part: battery, status and percentage
                Item {
                    id: batTop
                    anchors.top: parent.top
                    width: parent.width
                    height: 64
                }

                // Samme liggende batteri som i baren, bare større
                Item {
                    id: bigBattery
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spaceLg
                    anchors.verticalCenter: batTop.verticalCenter
                    width: 36
                    height: 17

                    readonly property color fillColor:
                          cc.charging ? Tokens.green
                        : PowerProfiles.profile === PowerProfile.PowerSaver ? Tokens.orange
                        : cc.batteryLevel < 0.2 ? Tokens.red
                        : Tokens.textPrimary

                    Rectangle {
                        id: bigBody
                        width: 32
                        height: parent.height
                        radius: Tokens.radiusSm
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
                            Behavior on width { NumberAnimation { duration: Tokens.durSlow; easing.type: Tokens.easeMove } }
                            Behavior on color { ColorAnimation { duration: Tokens.durNormal } }
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
                    anchors.leftMargin: Tokens.spaceLg
                    anchors.right: bigPct.left
                    anchors.rightMargin: Tokens.spaceMd
                    anchors.verticalCenter: batTop.verticalCenter
                    spacing: 1

                    Text {
                        text: "Battery"
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontBody
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: cc.batteryStatus
                        color: cc.charging ? Tokens.green : Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSmall
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: bigPct
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spaceLg
                    anchors.verticalCenter: batTop.verticalCenter
                    text: Math.round(cc.batteryLevel * 100) + "%"
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }

                // Power mode (needs power-profiles-daemon)
                Row {
                    id: profiles
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spaceMd
                    height: 28
                    spacing: Tokens.spaceSm

                    readonly property var options: [
                        { label: "Saver", value: PowerProfile.PowerSaver },
                        { label: "Balanced", value: PowerProfile.Balanced },
                        { label: "Performance", value: PowerProfile.Performance }
                    ]

                    Repeater {
                        model: profiles.options

                        Rectangle {
                            id: prof
                            required property var modelData
                            readonly property bool selected: PowerProfiles.profile === modelData.value
                            readonly property bool usable: modelData.value !== PowerProfile.Performance
                                || PowerProfiles.hasPerformanceProfile

                            width: (profiles.width - profiles.spacing * 2) / 3
                            height: profiles.height
                            radius: Tokens.radiusMd
                            opacity: usable ? 1 : 0.4
                            color: selected ? Tokens.accent
                                 : profMouse.containsMouse ? Tokens.fillHover : Qt.rgba(1, 1, 1, 0.06)
                            scale: profMouse.pressed ? Tokens.pressScale : 1
                            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

                            Text {
                                anchors.centerIn: parent
                                text: prof.modelData.label
                                color: prof.selected ? "white" : Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSmall
                                font.weight: prof.selected ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: profMouse
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: prof.usable
                                onClicked: PowerProfiles.profile = prof.modelData.value
                            }
                        }
                    }
                }
            }

            // ---------- Strøm ----------
            Card {
                order: 6
                Layout.fillWidth: true
                implicitHeight: 84

                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: Tokens.spaceMd
                    anchors.leftMargin: Tokens.spaceSm
                    anchors.rightMargin: Tokens.spaceSm
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
