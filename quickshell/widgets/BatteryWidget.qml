import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../theme"
import "../services"

// The iPhone "Batteries" widget on the desktop: a ring per device with its charge.
// This computer (laptops), headsets on a dongle (HeadsetControl), mice and keyboards
// on a dongle (UPower) and Bluetooth devices. Lies under all windows; drag to move.
PanelWindow {
    id: w

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "blink-widget"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { x: card.x; y: card.y; width: card.width; height: card.height }

    // ---------- Position (default: under the timetable widget, top right) ----------
    readonly property real defX: width - card.width - Tokens.frameT - 36
    readonly property real defY: SettingsService.topInset + 32 + 164 + 16
    function clampX(x) { return Math.max(0, Math.min(width - card.width, x)) }
    function clampY(y) { return Math.max(0, Math.min(height - card.height, y)) }
    readonly property real savedX: clampX(SettingsService.batWidgetX >= 0 ? SettingsService.batWidgetX : defX)
    readonly property real savedY: clampY(SettingsService.batWidgetY >= 0 ? SettingsService.batWidgetY : defY)

    // ---------- Devices ----------
    function norm(p) { return p > 1 ? p / 100 : p }
    readonly property var laptop: UPower.displayDevice
    readonly property var bt: Bluetooth.devices.values.filter(d => d.connected && d.batteryAvailable)
    readonly property var dongles: UPower.devices.values.filter(d => !d.isLaptopBattery && !d.powerSupply
        && d.type !== UPowerDeviceType.LinePower && !d.nativePath.startsWith("/org/bluez") && d.percentage > 0
        && !w.bt.some(b => b.name === d.model || b.deviceName === d.model))
    function upowerIcon(d) {
        return d.type === UPowerDeviceType.Mouse ? "input-mouse"
             : d.type === UPowerDeviceType.Keyboard ? "input-keyboard"
             : d.type === UPowerDeviceType.Headset || d.type === UPowerDeviceType.Headphones ? "audio-headset"
             : d.type === UPowerDeviceType.GamingInput ? "input-gaming"
             : "battery"
    }
    readonly property var devices: {
        const list = []
        if (laptop?.isLaptopBattery)
            list.push({ name: "This computer", icon: "computer-laptop", level: norm(laptop.percentage), charging: !UPower.onBattery })
        for (const h of HeadsetService.headsets)
            list.push({ name: h.name, icon: "audio-headset", level: h.level, charging: h.charging })
        for (const d of dongles)
            list.push({ name: d.model || "Device", icon: upowerIcon(d), level: norm(d.percentage), charging: false })
        for (const d of bt)
            list.push({ name: d.name, icon: d.icon || "bluetooth", level: d.battery, charging: false })
        return list.slice(0, 4)
    }

    Rectangle {
        id: card
        x: w.savedX
        y: w.savedY
        width: 340
        height: 164
        radius: 22
        color: Tokens.cardBg
        border.color: Tokens.ink(0.08)
        border.width: 1
        scale: drag.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        GlassEdge { radius: 22; z: 10 }

        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
            drag.target: card
            drag.threshold: 2
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: w.width - card.width
            drag.maximumY: w.height - card.height
            onReleased: {
                SettingsService.batWidgetX = Math.round(card.x)
                SettingsService.batWidgetY = Math.round(card.y)
                card.x = Qt.binding(() => w.savedX)
                card.y = Qt.binding(() => w.savedY)
            }
        }

        Text {
            visible: w.devices.length === 0
            anchors.centerIn: parent
            text: "No devices with a battery"
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontBody
        }

        Row {
            anchors.centerIn: parent
            spacing: 18

            Repeater {
                model: w.devices

                Column {
                    id: dev
                    required property var modelData
                    readonly property real level: Math.max(0, Math.min(1, modelData.level))
                    // Green like on the iPhone, red when low (but not while charging)
                    readonly property color ringColor: level < 0.2 && !modelData.charging ? Tokens.red : Tokens.green
                    spacing: 10
                    width: 64

                    Item {
                        width: 64
                        height: 64

                        // The ring: a grey track and the charge on top, from 12 o'clock
                        Canvas {
                            id: ring
                            anchors.fill: parent
                            readonly property string key: dev.level + "|" + dev.ringColor + "|" + Tokens.themeName
                            onKeyChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d")
                                c.reset()
                                const r = width / 2 - 4
                                c.lineWidth = 6
                                c.lineCap = "round"
                                c.strokeStyle = Tokens.ink(0.14).toString()
                                c.beginPath()
                                c.arc(width / 2, height / 2, r, 0, 2 * Math.PI)
                                c.stroke()
                                if (dev.level > 0) {
                                    c.strokeStyle = dev.ringColor.toString()
                                    c.beginPath()
                                    c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * dev.level)
                                    c.stroke()
                                }
                            }
                            Component.onCompleted: requestPaint()
                        }

                        TintIcon {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            sourceSize: Qt.size(52, 52)
                            source: Quickshell.iconPath(dev.modelData.icon + "-symbolic", dev.modelData.icon)
                        }

                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Math.round(dev.level * 100) + "%" + (dev.modelData.charging ? " +" : "")
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontTitle
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
