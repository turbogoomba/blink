import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../theme" as Theme

Flickable {
    id: panel
    contentHeight: col.implicitHeight + 56
    clip: true

    readonly property var nodes: Pipewire.nodes.values
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream && n.audio)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [panel.sink, panel.source] }

    function nameOf(n) {
        return n?.description || n?.nickname || n?.name || "Unknown"
    }

    // ---------- Volum-rad: mute-knapp, slider, prosent ----------
    component VolumeRow: Rectangle {
        id: vr
        property var node: null
        property string icon: ""
        property string mutedIcon: ""
        readonly property var audio: node?.audio ?? null
        readonly property real volume: audio?.volume ?? 0

        width: col.width
        height: 52
        radius: Theme.Tokens.radiusMd
        color: Theme.Tokens.surface
        border.color: Theme.Tokens.border
        border.width: 1

        Image {
            id: muteIcon
            scale: muteIconMouse.pressed ? Theme.Tokens.pressScaleIcon : 1
            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            sourceSize: Qt.size(40, 40)
            source: Quickshell.iconPath(vr.audio?.muted ? vr.mutedIcon : vr.icon)

            MouseArea {
                id: muteIconMouse
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                anchors.margins: -6
                onClicked: if (vr.audio) vr.audio.muted = !vr.audio.muted
            }
        }

        // Slider
        Item {
            id: slider
            anchors.left: muteIcon.right
            anchors.leftMargin: 12
            anchors.right: pct.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
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
                x: Math.min(vr.volume, 1) * (slider.width - width)
                width: 16
                height: 16
                radius: 8
                color: "white"
            }

            MouseArea {
                anchors.fill: parent
                function setFrom(x) {
                    if (!vr.audio) return
                    vr.audio.volume = Math.max(0, Math.min(1, (x - 8) / (slider.width - 16)))
                }
                onPressed: mouse => setFrom(mouse.x)
                onPositionChanged: mouse => setFrom(mouse.x)
            }
        }

        Text {
            id: pct
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(vr.volume * 100) + "%"
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontBody
        }
    }

    // ---------- Liste over enheter ----------
    component DeviceList: Rectangle {
        id: dl
        property var devices: []
        property var current: null
        signal picked(var node)

        width: col.width
        height: dlCol.implicitHeight
        radius: Theme.Tokens.radiusMd
        color: Theme.Tokens.surface
        border.color: Theme.Tokens.border
        border.width: 1
        visible: devices.length > 0

        Column {
            id: dlCol
            width: parent.width

            Repeater {
                model: dl.devices

                delegate: Item {
                    id: dev
                    scale: devMouse.pressed ? Theme.Tokens.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                    required property var modelData
                    required property int index
                    readonly property bool selected: modelData.id === dl.current?.id

                    width: dlCol.width
                    height: 44

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Theme.Tokens.radiusSm
                        color: Theme.Tokens.surfaceAlt
                        visible: devMouse.containsMouse
                    }

                    MouseArea {
                        id: devMouse
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: dl.picked(dev.modelData)
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: check.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.nameOf(dev.modelData)
                        color: Theme.Tokens.textPrimary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: Theme.Tokens.fontBody
                        font.weight: dev.selected ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Image {
                        id: check
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: dev.selected
                        width: 16
                        height: 16
                        sourceSize: Qt.size(32, 32)
                        source: Quickshell.iconPath("object-select-symbolic")
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        height: 1
                        color: Theme.Tokens.border
                        visible: dev.index < dl.devices.length - 1
                    }
                }
            }
        }
    }

    // ---------- Innholdet ----------
    Column {
        id: col
        x: 28
        y: 28
        width: panel.width - 56
        spacing: 14

        Text {
            text: "Sound"
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontLarge
            font.weight: Font.DemiBold
        }

        Text {
            leftPadding: 4
            text: "Output"
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontBody
            font.weight: Font.Medium
        }

        VolumeRow {
            node: panel.sink
            icon: "audio-volume-high-symbolic"
            mutedIcon: "audio-volume-muted-symbolic"
        }

        DeviceList {
            devices: panel.outputs
            current: panel.sink
            onPicked: node => Pipewire.preferredDefaultAudioSink = node
        }

        Text {
            leftPadding: 4
            text: "Input"
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontBody
            font.weight: Font.Medium
        }

        VolumeRow {
            node: panel.source
            icon: "audio-input-microphone-symbolic"
            mutedIcon: "microphone-sensitivity-muted-symbolic"
        }

        DeviceList {
            devices: panel.inputs
            current: panel.source
            onPicked: node => Pipewire.preferredDefaultAudioSource = node
        }
    }
}
