import QtQuick
import Quickshell
import "../services"
import "../theme" as Theme

// One Hyprland option: name, description, and the right control on the right.
// A dot and a reset button show when the option is changed from the normal config.
Item {
    id: row
    required property var opt
    property string crumb: ""         // "Hyprland › Look", shown in search results
    property bool divider: true
    signal jump()

    readonly property bool changed: HyprSettingsService.isChanged(opt.key)
    readonly property bool usable: HyprSettingsService.available(opt.key)
    readonly property var value: HyprSettingsService.valueOf(opt)

    width: parent ? parent.width : 0
    height: Math.max(56, textCol.implicitHeight + 2 * Theme.Tokens.spaceMd)
    opacity: HyprSettingsService.ready && !usable ? 0.4 : 1

    Column {
        id: textCol
        anchors.left: parent.left
        anchors.leftMargin: Theme.Tokens.spaceLg
        anchors.right: controls.left
        anchors.rightMargin: Theme.Tokens.spaceLg
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Row {
            spacing: Theme.Tokens.spaceSm
            Rectangle {
                visible: row.changed
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: Theme.Tokens.accent
            }
            Text {
                text: row.opt.label
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
                font.weight: Font.Medium
            }
        }
        Text {
            width: parent.width
            text: HyprSettingsService.ready && !row.usable ? "Not available in this Hyprland version" : row.opt.desc
            wrapMode: Text.WordWrap
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontSmall
        }
        Text {
            visible: row.crumb !== ""
            text: row.crumb
            color: Theme.Tokens.textSecondary
            opacity: 0.7
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontSmall
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: Theme.Tokens.spaceLg
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.Tokens.spaceMd
        enabled: row.usable

        // Reset to the normal config
        Rectangle {
            id: resetBtn
            visible: row.changed
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: Theme.Tokens.radiusSm
            color: resetMouse.containsMouse ? Theme.Tokens.fillStrong : Theme.Tokens.fillHover
            scale: resetMouse.pressed ? Theme.Tokens.pressScaleIcon : 1
            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
            Text {
                anchors.centerIn: parent
                text: "↺"
                color: Theme.Tokens.textSecondary
                font.pixelSize: Theme.Tokens.fontBody
            }
            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HyprSettingsService.reset(row.opt.key)
            }
        }

        // ---------- Slider ----------
        Row {
            visible: row.opt.type === "slider"
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.Tokens.spaceMd

            property bool dragging: false
            property real dragValue: 0
            readonly property real shown: dragging ? dragValue : (typeof row.value === "number" ? row.value : 0)
            readonly property real ratio: Math.max(0, Math.min(1, (shown - row.opt.min) / (row.opt.max - row.opt.min)))
            id: slider

            Item {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: 160
                height: 20

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.Tokens.fillStrong
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
                    x: slider.ratio * (track.width - width)
                    width: 16
                    height: 16
                    radius: 8
                    color: "white"
                    scale: dragArea.pressed ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                }
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function setFrom(x) {
                        const r = Math.max(0, Math.min(1, (x - 8) / (track.width - 16)))
                        const raw = row.opt.min + r * (row.opt.max - row.opt.min)
                        slider.dragValue = Math.round(raw / row.opt.step) * row.opt.step
                    }
                    onPressed: mouse => { slider.dragging = true; setFrom(mouse.x) }
                    onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                    onReleased: {
                        HyprSettingsService.set(row.opt.key, slider.dragValue)
                        slider.dragging = false
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                horizontalAlignment: Text.AlignRight
                text: row.opt.percent ? Math.round(slider.shown * 100) + "%"
                    : slider.shown.toFixed(row.opt.decimals ?? 0) + (row.opt.unit ? " " + row.opt.unit : "")
                color: Theme.Tokens.textSecondary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
            }
        }

        // ---------- Switch ----------
        Rectangle {
            id: sw
            visible: row.opt.type === "switch"
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool checked: row.value === true
            width: 38
            height: 22
            radius: 11
            color: checked ? Theme.Tokens.accent : Theme.Tokens.fillStrong
            Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
            scale: swMouse.pressed ? Theme.Tokens.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
            Rectangle {
                width: 18
                height: 18
                radius: 9
                y: 2
                x: sw.checked ? sw.width - width - 2 : 2
                color: "white"
                Behavior on x { NumberAnimation { duration: Theme.Tokens.durNormal; easing.type: Theme.Tokens.easeMove } }
            }
            MouseArea {
                id: swMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HyprSettingsService.set(row.opt.key, !sw.checked)
            }
        }

        // ---------- Choice ----------
        Rectangle {
            visible: row.opt.type === "choice"
            anchors.verticalCenter: parent.verticalCenter
            width: segRow.implicitWidth + 4
            height: 28
            radius: Theme.Tokens.radiusSm
            color: Theme.Tokens.fillIdle

            Row {
                id: segRow
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: row.opt.type === "choice" ? row.opt.choices : []
                    delegate: Rectangle {
                        id: seg
                        required property var modelData
                        readonly property bool selected: String(row.value) === String(modelData.value)
                        width: segText.implicitWidth + 2 * Theme.Tokens.spaceMd
                        height: 24
                        radius: Theme.Tokens.radiusSm
                        color: selected ? Theme.Tokens.accent : segMouse.containsMouse ? Theme.Tokens.fillHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
                        scale: segMouse.pressed ? Theme.Tokens.pressScale : 1
                        Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                        Text {
                            id: segText
                            anchors.centerIn: parent
                            text: seg.modelData.label
                            color: seg.selected ? Theme.Tokens.onAccent : Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: Theme.Tokens.fontSmall
                            font.weight: seg.selected ? Font.Medium : Font.Normal
                        }
                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!seg.selected) HyprSettingsService.set(row.opt.key, seg.modelData.value)
                        }
                    }
                }
            }
        }

        // Open the page this option lives on (search results)
        Rectangle {
            visible: row.crumb !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: Theme.Tokens.radiusSm
            color: jumpMouse.containsMouse ? Theme.Tokens.fillHover : "transparent"
            Text {
                anchors.centerIn: parent
                text: "›"
                color: Theme.Tokens.textSecondary
                font.pixelSize: Theme.Tokens.fontTitle
            }
            MouseArea {
                id: jumpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.jump()
            }
        }
    }

    Rectangle {
        visible: row.divider
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: Theme.Tokens.spaceLg
        anchors.right: parent.right
        height: 1
        color: Theme.Tokens.divider
    }
}
