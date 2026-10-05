import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

// What is inside the drawer: system graphs, favorite apps and folders.
Column {
    id: content
    spacing: Tokens.spaceLg

    // Set by the drawer while a folder is dragged over it
    property bool dropActive: false

    FileView { id: hostFile; path: "/etc/hostname"; printErrors: false }
    readonly property string host: (hostFile.text() ?? "").trim()

    // ---------- Pieces ----------
    component SectionTitle: Text {
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.fontBody
        font.weight: Font.DemiBold
    }

    // Line graph with a soft fill under it
    component Sparkline: Canvas {
        id: spark
        property var values: []
        property real maxValue: 1
        property color lineColor: Tokens.accent
        height: 32
        onValuesChanged: requestPaint()
        onLineColorChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            const v = values
            if (!v || v.length < 2) return
            const max = Math.max(maxValue, ...v, 0.0001)
            const n = SystemService.historyLength
            const step = width / (n - 1)
            const start = (n - v.length) * step
            const yOf = x => height - 2 - (x / max) * (height - 4)

            c.beginPath()
            c.moveTo(start, height)
            for (let i = 0; i < v.length; i++) c.lineTo(start + i * step, yOf(v[i]))
            c.lineTo(start + (v.length - 1) * step, height)
            c.closePath()
            c.globalAlpha = 0.18
            c.fillStyle = lineColor.toString()
            c.fill()

            c.globalAlpha = 1
            c.beginPath()
            for (let i = 0; i < v.length; i++) {
                const x = start + i * step
                if (i === 0) c.moveTo(x, yOf(v[i])); else c.lineTo(x, yOf(v[i]))
            }
            c.strokeStyle = lineColor.toString()
            c.lineWidth = 1.8
            c.lineJoin = "round"
            c.stroke()
        }
    }

    component StatCard: Rectangle {
        id: card
        property string title: ""
        property string note: ""
        property string value: ""
        property string unit: ""
        property var history: []
        property real maxValue: 1
        property color lineColor: Tokens.accent

        width: (content.width - 8) / 2
        height: 96
        radius: Tokens.radiusMd
        color: Tokens.fillIdle
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: Tokens.spaceMd
            spacing: 2

            Item {
                width: parent.width
                height: 14
                Text {
                    text: card.title
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall
                }
                Text {
                    anchors.right: parent.right
                    text: card.note
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall
                    font.features: { "tnum": 1 }
                }
            }

            Row {
                spacing: Tokens.spaceXs
                Text {
                    id: valueText
                    text: card.value
                    color: "#f2f2f4"
                    font.family: Tokens.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.baseline: valueText.baseline
                    text: card.unit
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall
                }
            }

            Sparkline {
                width: parent.width
                values: card.history
                maxValue: card.maxValue
                lineColor: card.lineColor
            }
        }
    }

    component Tile: Item {
        id: tile
        scale: tileMouse.pressed ? Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
        property string icon: ""
        property string label: ""
        property bool dashed: false
        signal clicked()
        signal rightClicked()

        width: (content.width - 3 * 8) / 4
        height: 68

        Rectangle {
            id: tileBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: 46
            height: 46
            radius: Tokens.radiusMd
            color: tile.dashed ? "transparent" : tileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Tokens.fillIdle
            border.width: tile.dashed ? 1.5 : 0
            border.color: Tokens.border
            scale: tileMouse.pressed ? 0.92 : 1
            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

            Image {
                anchors.centerIn: parent
                visible: !tile.dashed
                width: 32
                height: 32
                sourceSize: Qt.size(64, 64)
                source: tile.icon
            }
            Text {
                anchors.centerIn: parent
                visible: tile.dashed
                text: "+"
                color: Tokens.textSecondary
                font.pixelSize: Tokens.fontLarge
            }
        }

        Text {
            anchors.top: tileBox.bottom
            anchors.topMargin: Tokens.spaceXs
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
            elide: Text.ElideRight
        }

        MouseArea {
            id: tileMouse
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? tile.rightClicked() : tile.clicked()
        }
    }

    // ---------- System ----------
    Item {
        width: parent.width
        height: 20

        SectionTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "System"
            font.pixelSize: Tokens.fontTitle
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: content.host + (SystemService.uptime > 0 ? "  ·  up " + SystemService.duration(SystemService.uptime) : "")
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
        }
    }

    Grid {
        columns: 2
        spacing: Tokens.spaceSm

        StatCard {
            title: "CPU"
            note: SystemService.cpuTemp >= 0 ? Math.round(SystemService.cpuTemp) + "°C" : ""
            value: Math.round(SystemService.cpu * 100) + "%"
            history: SystemService.cpuHistory
            lineColor: Tokens.accent
        }
        StatCard {
            title: "Memory"
            note: Math.round(SystemService.ram * 100) + "%"
            value: SystemService.ramUsedGb.toFixed(1)
            unit: "/ " + Math.round(SystemService.ramTotalGb) + " GB"
            history: SystemService.ramHistory
            lineColor: "#bf5af2"
        }
        StatCard {
            title: "GPU"
            note: SystemService.gpuTemp >= 0 ? Math.round(SystemService.gpuTemp) + "°C" : ""
            value: SystemService.gpu >= 0 ? Math.round(SystemService.gpu * 100) + "%" : "–"
            history: SystemService.gpuHistory
            lineColor: Tokens.orange
        }
        StatCard {
            title: "Network"
            note: "↑ " + SystemService.rate(SystemService.netUp)
            value: "↓ " + SystemService.rate(SystemService.netDown)
            history: SystemService.netDownHistory
            maxValue: 102400   // graph scale starts at 100 KB/s
            lineColor: "#64d2ff"
        }
    }

    // Disk
    Column {
        width: parent.width
        spacing: Tokens.spaceSm

        Item {
            width: parent.width
            height: 14
            Text {
                text: "Disk"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
            }
            Text {
                anchors.right: parent.right
                text: SystemService.diskTotal > 0
                    ? Math.round(SystemService.diskUsed / 1e9) + " / " + Math.round(SystemService.diskTotal / 1e9) + " GB" : ""
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
                font.features: { "tnum": 1 }
            }
        }
        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.1)
            Rectangle {
                width: parent.width * (SystemService.diskTotal > 0 ? SystemService.diskUsed / SystemService.diskTotal : 0)
                height: parent.height
                radius: 3
                color: Tokens.accent
            }
        }
    }

    // ---------- Favorite apps ----------
    Item {
        width: parent.width
        height: 18
        SectionTitle { text: "Favorites" }
        Text {
            anchors.right: parent.right
            text: "Right-click to remove"
            color: Tokens.textSecondary
            opacity: 0.7
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
            visible: SettingsService.favApps.length > 0
        }
    }

    Flow {
        width: parent.width
        spacing: Tokens.spaceSm

        Repeater {
            model: SettingsService.favApps

            Tile {
                required property string modelData
                readonly property var entry: DesktopEntries.byId(modelData) ?? DesktopEntries.heuristicLookup(modelData)
                icon: Quickshell.iconPath(entry?.icon ?? modelData, "application-x-executable")
                label: entry?.name ?? modelData
                onClicked: entry?.execute()
                onRightClicked: SettingsService.removeFavorite(modelData)
            }
        }

        // Add: opens the launcher, where right-click > Add to Favorites
        Tile {
            dashed: true
            label: "Add"
            onClicked: ShellState.launcherOpen = true
        }
    }

    // ---------- Folders ----------
    SectionTitle { text: "Folders" }

    Grid {
        columns: 2
        spacing: Tokens.spaceSm

        Repeater {
            model: SettingsService.favFolders

            Rectangle {
                id: folderRow
                scale: folderMouse.pressed ? Tokens.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                required property string modelData
                width: (content.width - 6) / 2
                height: 34
                radius: Tokens.radiusMd
                color: folderMouse.containsMouse ? Tokens.fillHover : Tokens.fillIdle

                Image {
                    id: folderIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spaceMd
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    sourceSize: Qt.size(32, 32)
                    source: Quickshell.iconPath("folder", "folder-symbolic")
                }
                Text {
                    anchors.left: folderIcon.right
                    anchors.leftMargin: Tokens.spaceSm
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spaceSm
                    anchors.verticalCenter: parent.verticalCenter
                    text: folderRow.modelData.split("/").pop()
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontBody
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: folderMouse
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) SettingsService.removeFolder(folderRow.modelData)
                        else Quickshell.execDetached(["xdg-open", folderRow.modelData])
                    }
                }
            }
        }

        // Drop zone hint, lights up while dragging
        Rectangle {
            width: (content.width - 6) / 2
            height: 34
            radius: Tokens.radiusMd
            color: content.dropActive ? Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.15) : "transparent"
            border.width: 1.5
            border.color: content.dropActive ? Tokens.accent : Tokens.border
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }

            Text {
                anchors.centerIn: parent
                text: content.dropActive ? "Drop to add" : "+ Drop a folder"
                color: content.dropActive ? Tokens.textPrimary : Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
            }
        }
    }
}
