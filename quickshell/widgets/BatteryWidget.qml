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
        // A small square, like the iPhone Batteries widget
        width: 164
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

        // A ring with the device in it. The charge goes round from 12 o'clock.
        component Ring: Item {
            id: ringItem
            property var dev: null
            property real thickness: 5
            property real iconSize: 20
            readonly property real level: Math.max(0, Math.min(1, dev?.level ?? 0))
            readonly property bool low: level < 0.2 && !(dev?.charging ?? false)
            // Green like on the iPhone, red when low (but not while charging)
            readonly property color ringColor: low ? Tokens.red : Tokens.green

            Canvas {
                anchors.fill: parent
                readonly property string key: ringItem.level + "|" + ringItem.ringColor + "|" + Tokens.themeName + "|" + width
                onKeyChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    const t = ringItem.thickness
                    const r = width / 2 - t / 2 - 1
                    c.lineWidth = t
                    c.lineCap = "round"
                    c.strokeStyle = Tokens.ink(0.14).toString()
                    c.beginPath()
                    c.arc(width / 2, height / 2, r, 0, 2 * Math.PI)
                    c.stroke()
                    if (ringItem.level > 0) {
                        c.strokeStyle = ringItem.ringColor.toString()
                        c.beginPath()
                        c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * ringItem.level)
                        c.stroke()
                    }
                }
                Component.onCompleted: requestPaint()
            }
            TintIcon {
                anchors.centerIn: parent
                width: ringItem.iconSize
                height: ringItem.iconSize
                sourceSize: Qt.size(ringItem.iconSize * 2, ringItem.iconSize * 2)
                source: ringItem.dev ? Quickshell.iconPath(ringItem.dev.icon + "-symbolic", ringItem.dev.icon) : ""
            }
        }

        // One device: the ring in the corner and the charge big underneath (iPhone small widget)
        Item {
            visible: w.devices.length === 1
            anchors.fill: parent

            Ring {
                x: 16
                y: 16
                width: 48
                height: 48
                dev: w.devices[0] ?? null
            }
            Text {
                x: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                text: Math.round(Math.max(0, Math.min(1, w.devices[0]?.level ?? 0)) * 100) + "%"
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 44
                font.weight: Font.Light
                font.features: { "tnum": 1 }
            }
        }

        // Several devices: a ring each, two by two
        Grid {
            visible: w.devices.length > 1
            anchors.centerIn: parent
            columns: 2
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: w.devices.length > 1 ? w.devices : []
                Ring {
                    required property var modelData
                    width: 58
                    height: 58
                    dev: modelData
                    iconSize: 22
                }
            }
        }
    }
}
