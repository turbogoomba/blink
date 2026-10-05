import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "../../theme" as Theme

Flickable {
    id: panel
    contentHeight: col.implicitHeight + 56
    clip: true

    property int gapsIn: 8
    property int gapsOut: 16
    property int rounding: 12
    property real sensitivity: 0

    Component.onCompleted: {
        readProc.running = true
        StyleService.refresh()
    }

    // Les nåværende verdier fra Hyprland
    Process {
        id: readProc
        command: ["hyprctl", "repl",
            'hl.get_config("general.gaps_in").top .. "," .. hl.get_config("general.gaps_out").top .. "," .. hl.get_config("decoration.rounding") .. "," .. hl.get_config("input.sensitivity")']
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",")
                if (p.length !== 4) return
                panel.gapsIn = parseInt(p[0])
                panel.gapsOut = parseInt(p[1])
                panel.rounding = parseInt(p[2])
                panel.sensitivity = parseFloat(p[3])
            }
        }
    }

    // Lagres her, og lastes inn av style.lua ved oppstart
    FileView {
        id: overrides
        path: Quickshell.env("HOME") + "/.config/hypr/overrides.lua"
        printErrors: false
    }

    function luaConfig() {
        return `hl.config({ general = { gaps_in = ${gapsIn}, gaps_out = ${gapsOut} }, `
             + `decoration = { rounding = ${rounding} }, `
             + `input = { sensitivity = ${sensitivity.toFixed(2)} } })`
    }

    function apply() {
        overrides.setText("-- Skrevet av Settings-appen\n" + luaConfig() + "\n")
        Quickshell.execDetached(["hyprctl", "eval", luaConfig()])
    }

    function resetDefaults() {
        overrides.setText("")
        Quickshell.execDetached(["hyprctl", "reload"])
        resetTimer.restart()
    }

    Timer {
        id: resetTimer
        interval: 500
        onTriggered: readProc.running = true
    }

    // ---------- Én rad med navn, verdi og slider ----------
    component SliderRow: Item {
        id: sr
        property string label: ""
        property real from: 0
        property real to: 1
        property real value: 0
        property int decimals: 0
        property bool divider: true
        signal moved(real v)
        signal released()

        readonly property real ratio: Math.max(0, Math.min(1, (value - from) / (to - from)))

        width: parent ? parent.width : 0
        height: 64

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 12
            text: sr.label
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontBody
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 12
            text: sr.value.toFixed(sr.decimals)
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontBody
        }

        // Slider
        Item {
            id: track
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            height: 20

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Theme.Tokens.border

                Rectangle {
                    width: knob.x + knob.width / 2
                    height: parent.height
                    radius: 2
                    color: Theme.Tokens.accent
                }
            }

            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                x: sr.ratio * (track.width - width)
                width: 16
                height: 16
                radius: 8
                color: "white"
            }

            MouseArea {
                anchors.fill: parent
                function setFrom(x) {
                    const r = Math.max(0, Math.min(1, (x - 8) / (track.width - 16)))
                    sr.moved(sr.from + r * (sr.to - sr.from))
                }
                onPressed: mouse => setFrom(mouse.x)
                onPositionChanged: mouse => setFrom(mouse.x)
                onReleased: sr.released()
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            height: 1
            color: Theme.Tokens.border
            visible: sr.divider
        }
    }

    // ---------- Kort-bakgrunn ----------
    component CardBox: Rectangle {
        width: col.width
        radius: Theme.Tokens.radiusMd
        color: Theme.Tokens.surface
        border.color: Theme.Tokens.border
        border.width: 1
    }

    // ---------- Seksjonsoverskrift ----------
    component SectionTitle: Text {
        leftPadding: 4
        color: Theme.Tokens.textSecondary
        font.family: Theme.Tokens.fontFamily
        font.pixelSize: Theme.Tokens.fontBody
        font.weight: Font.Medium
    }

    // ---------- Innholdet ----------
    Column {
        id: col
        x: 28
        y: 28
        width: panel.width - 56
        spacing: 14

        Text {
            text: "Hyprland"
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontLarge
            font.weight: Font.DemiBold
        }

        // Vindusmodus
        CardBox {
            height: 52

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "Window mode"
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                height: 30
                radius: Theme.Tokens.radiusMd
                color: Theme.Tokens.bg
                border.color: Theme.Tokens.border
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 3

                    Repeater {
                        model: [
                            { id: "tiling", label: "Tiling" },
                            { id: "floating", label: "Floating" }
                        ]

                        delegate: Rectangle {
                            scale: press252.pressed ? Theme.Tokens.pressScale : 1
                            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                            required property var modelData
                            width: (200 - 6) / 2
                            height: 24
                            radius: Theme.Tokens.radiusSm
                            color: StyleService.mode === modelData.id ? Theme.Tokens.accent : (press252.containsMouse ? Theme.Tokens.fillHover : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: Theme.Tokens.textPrimary
                                font.family: Theme.Tokens.fontFamily
                                font.pixelSize: Theme.Tokens.fontBody
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: press252
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                onClicked: if (StyleService.mode !== modelData.id) StyleService.toggle()
                            }
                        }
                    }
                }
            }
        }

        // Utseende
        SectionTitle { text: "Appearance" }

        CardBox {
            height: appearance.implicitHeight

            Column {
                id: appearance
                width: parent.width

                SliderRow {
                    label: "Gaps between windows"
                    from: 0
                    to: 30
                    value: panel.gapsIn
                    onMoved: v => panel.gapsIn = Math.round(v)
                    onReleased: panel.apply()
                }
                SliderRow {
                    label: "Gaps to screen edge"
                    from: 0
                    to: 60
                    value: panel.gapsOut
                    onMoved: v => panel.gapsOut = Math.round(v)
                    onReleased: panel.apply()
                }
                SliderRow {
                    label: "Corner radius"
                    from: 0
                    to: 30
                    value: panel.rounding
                    divider: false
                    onMoved: v => panel.rounding = Math.round(v)
                    onReleased: panel.apply()
                }
            }
        }

        // Mus
        SectionTitle { text: "Mouse" }

        CardBox {
            height: 64

            SliderRow {
                label: "Sensitivity"
                from: -1
                to: 1
                decimals: 2
                value: panel.sensitivity
                divider: false
                onMoved: v => panel.sensitivity = Math.round(v * 20) / 20
                onReleased: panel.apply()
            }
        }

        // Tilbakestill
        Rectangle {
            scale: resetMouse.pressed ? Theme.Tokens.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
            width: resetText.implicitWidth + 28
            height: 30
            radius: Theme.Tokens.radiusSm
            color: resetMouse.containsMouse ? Theme.Tokens.border : Theme.Tokens.surface
            border.color: Theme.Tokens.border
            border.width: 1

            Text {
                id: resetText
                anchors.centerIn: parent
                text: "Reset to defaults"
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
            }

            MouseArea {
                id: resetMouse
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                hoverEnabled: true
                onClicked: panel.resetDefaults()
            }
        }
    }
}
