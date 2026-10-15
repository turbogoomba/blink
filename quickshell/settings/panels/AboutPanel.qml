import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "../../bar"
import "../../theme" as Theme

// About: what this computer is, and how hard it is working right now.
Flickable {
    id: panel
    contentHeight: col.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    readonly property color accent: Theme.Tokens.accent
    readonly property color card: Theme.Tokens.cardBg
    readonly property color line: Theme.Tokens.ink(0.05)
    function soft(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }

    // Live GPU, temperatures and disk while this page is open
    Component.onCompleted: SystemService.statsUsers += 1
    Component.onDestruction: SystemService.statsUsers -= 1

    // ---------- Facts that do not change (read once) ----------
    property var info: ({})

    Process {
        id: facts
        running: true
        command: ["sh", "-c", `
. /etc/os-release 2>/dev/null
echo "os=\${PRETTY_NAME:-Linux}"
echo "kernel=$(uname -r)"
echo "host=$(cat /etc/hostname 2>/dev/null)"
echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
echo "cores=$(nproc)"
lspci -mm 2>/dev/null | grep -Ei '"(VGA|3D|Display)' | sed -E 's/^[^"]*"[^"]*" "[^"]*" "([^"]*)".*/\\1/' | while read -r g; do echo "gpu=$g"; done
echo "mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
echo "hypr=$(hyprctl version -j 2>/dev/null | grep -m1 '"tag"' | cut -d'"' -f4)"
echo "qs=$(qs --version 2>/dev/null | head -1)"
echo "pkgs=$(pacman -Qq 2>/dev/null | wc -l)"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = { gpus: [] }
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=")
                    if (i < 0) continue
                    const k = l.slice(0, i)
                    const v = l.slice(i + 1).trim()
                    if (k === "gpu") { if (v) out.gpus.push(v.replace(/\[|\]/g, "")) }
                    else out[k] = v
                }
                panel.info = out
            }
        }
    }

    function gb(bytes) { return (bytes / 1073741824).toFixed(bytes >= 107374182400 ? 0 : 1) + " GB" }

    readonly property string screensText: Quickshell.screens
        .map(s => s.width + " × " + s.height).join(",  ")

    // Everything, as plain text, for "Copy"
    readonly property string summary: [
        "Device: " + (info.host || ""),
        "OS: " + (info.os || ""),
        "Kernel: " + (info.kernel || ""),
        "CPU: " + (info.cpu || "") + (info.cores ? " (" + info.cores + " threads)" : ""),
        "GPU: " + (info.gpus ?? []).join(" + "),
        "Memory: " + (info.mem ? gb(Number(info.mem) * 1024) : ""),
        "Storage: " + (SystemService.diskTotal ? gb(SystemService.diskUsed) + " of " + gb(SystemService.diskTotal) : ""),
        "Displays: " + screensText,
        "Hyprland: " + (info.hypr || ""),
        "Quickshell: " + (info.qs || "")
    ].join("\n")

    // ================= Building blocks =================

    component Card: Rectangle {
        default property alias content: inner.data
        width: col.width
        height: inner.implicitHeight
        radius: 16
        color: panel.card
        clip: true
        Column {
            id: inner
            width: parent.width
        }
    }

    component SectionHeader: Text {
        leftPadding: 4
        topPadding: 6
        color: Theme.Tokens.textSecondary
        font.family: Theme.Tokens.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.7
        font.capitalization: Font.AllUppercase
    }

    component InfoRow: Item {
        property string label: ""
        property string value: ""
        property bool divider: true
        width: col.width
        height: Math.max(46, valueText.implicitHeight + 24)
        Text {
            id: labelText
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 120
            text: parent.label
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 13
        }
        Text {
            id: valueText
            anchors.left: labelText.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: parent.value || "–"
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        Rectangle {
            visible: parent.divider
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            height: 1
            color: panel.line
        }
    }

    // Big usage ring: name, percent in the middle, a detail under it
    component BigRing: Column {
        id: br
        property string label: ""
        property real value: 0
        property string detail: ""
        property real shown: Math.max(0, Math.min(1, value))
        Behavior on shown { NumberAnimation { duration: 700; easing.type: Theme.Tokens.easeMove } }
        readonly property color tint: value > 0.85 ? Theme.Tokens.red : value > 0.7 ? Theme.Tokens.orange : panel.accent
        spacing: 8

        Canvas {
            readonly property string paintKey: Theme.Tokens.themeName + Theme.Tokens.accent
            onPaintKeyChanged: requestPaint()
            id: ring
            anchors.horizontalCenter: parent.horizontalCenter
            width: 84
            height: 84
            property real v: br.shown
            property color c: br.tint
            onVChanged: requestPaint()
            onCChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const r = width / 2 - 5
                ctx.lineWidth = 7
                ctx.lineCap = "round"
                ctx.strokeStyle = Theme.Tokens.ink(0.08).toString()
                ctx.beginPath()
                ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI)
                ctx.stroke()
                if (v > 0.003) {
                    ctx.strokeStyle = c.toString()
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * v)
                    ctx.stroke()
                }
            }
            Component.onCompleted: requestPaint()

            Text {
                anchors.centerIn: parent
                text: Math.round(br.shown * 100) + "%"
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: br.label
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: br.detail
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 12
            font.features: { "tnum": 1 }
        }
    }

    component Pill: Rectangle {
        id: pl
        property string text: ""
        property bool accentKind: false
        signal clicked()
        width: plText.implicitWidth + 24
        height: 32
        radius: 9
        color: accentKind ? panel.accent : plMouse.containsMouse ? Theme.Tokens.fillStrong : Theme.Tokens.fillHover
        scale: plMouse.pressed ? Theme.Tokens.pressScale : 1
        Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
        Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
        Text {
            id: plText
            anchors.centerIn: parent
            text: pl.text
            color: pl.accentKind ? Theme.Tokens.onAccent : Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: plMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pl.clicked()
        }
    }

    // ================= The page =================
    Column {
        id: col
        x: 32
        y: 24
        width: panel.width - 64
        spacing: 14

        // ---------- Who and what ----------
        Rectangle {
            width: parent.width
            height: 120
            radius: 18
            color: panel.soft(0.10)
            border.width: 1
            border.color: panel.soft(0.30)

            // Blink's face
            Rectangle {
                id: logo
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                width: 76
                height: 76
                radius: 22
                color: Theme.Tokens.barBg
                border.width: 1
                border.color: Theme.Tokens.ink(0.08)
                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    Repeater {
                        model: 2
                        Rectangle {
                            width: 9
                            height: 16
                            radius: 4.5
                            color: Theme.Tokens.textPrimary
                        }
                    }
                }
            }

            Column {
                anchors.left: logo.right
                anchors.leftMargin: 20
                anchors.right: copyBtn.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: panel.info.host || "This computer"
                    color: Theme.Tokens.textPrimary
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (panel.info.os || "Linux") + "  ·  Hyprland " + (panel.info.hypr || "") + "  ·  Blink"
                    color: Theme.Tokens.textSecondary
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: 13
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: SystemService.uptime > 0 ? "Up for " + SystemService.duration(SystemService.uptime) : ""
                    color: Theme.Tokens.textSecondary
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: 13
                }
            }

            Pill {
                id: copyBtn
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                property bool copied: false
                text: copied ? "Copied" : "Copy info"
                onClicked: {
                    Quickshell.execDetached(["wl-copy", panel.summary])
                    copied = true
                    copiedTimer.restart()
                }
                Timer { id: copiedTimer; interval: 1600; onTriggered: copyBtn.copied = false }
            }
        }

        // ---------- Right now ----------
        SectionHeader { text: "Right now" }
        Card {
            Item {
                width: col.width
                height: 190
                Row {
                    anchors.centerIn: parent
                    spacing: Math.max(24, (col.width - 4 * 110) / 5)
                    BigRing {
                        width: 110
                        label: "CPU"
                        value: SystemService.cpu
                        detail: SystemService.cpuTemp > 0 ? Math.round(SystemService.cpuTemp) + " °C" : (panel.info.cores ? panel.info.cores + " threads" : "")
                    }
                    BigRing {
                        width: 110
                        label: "Memory"
                        value: SystemService.ram
                        detail: SystemService.ramUsedGb.toFixed(1) + " / " + SystemService.ramTotalGb.toFixed(0) + " GB"
                    }
                    BigRing {
                        width: 110
                        visible: SystemService.gpu >= 0
                        label: "GPU"
                        value: Math.max(0, SystemService.gpu)
                        detail: SystemService.gpuTemp > 0 ? Math.round(SystemService.gpuTemp) + " °C" : ""
                    }
                    BigRing {
                        width: 110
                        label: "Storage"
                        value: SystemService.diskTotal > 0 ? SystemService.diskUsed / SystemService.diskTotal : 0
                        detail: SystemService.diskTotal > 0 ? panel.gb(SystemService.diskTotal - SystemService.diskUsed) + " free" : ""
                    }
                }
            }
        }

        // ---------- Hardware ----------
        SectionHeader { text: "Hardware" }
        Card {
            InfoRow { label: "Processor"; value: (panel.info.cpu || "") + (panel.info.cores ? "  ·  " + panel.info.cores + " threads" : "") }
            InfoRow { label: "Graphics"; value: (panel.info.gpus ?? []).join("\n") }
            InfoRow { label: "Memory"; value: panel.info.mem ? panel.gb(Number(panel.info.mem) * 1024) : "" }
            InfoRow { label: "Storage"; value: SystemService.diskTotal ? panel.gb(SystemService.diskUsed) + " used of " + panel.gb(SystemService.diskTotal) : "" }
            InfoRow { label: "Displays"; value: panel.screensText; divider: false }
        }

        // ---------- Software ----------
        SectionHeader { text: "Software" }
        Card {
            InfoRow { label: "System"; value: panel.info.os || "" }
            InfoRow { label: "Kernel"; value: panel.info.kernel || "" }
            InfoRow { label: "Hyprland"; value: panel.info.hypr || "" }
            InfoRow { label: "Quickshell"; value: panel.info.qs || "" }
            InfoRow { label: "Packages"; value: panel.info.pkgs ? panel.info.pkgs + " installed" : ""; divider: false }
        }

        Row {
            spacing: 8
            Pill {
                text: "Open btop"
                onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
            }
        }
    }
}
