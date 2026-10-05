import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../theme"
import "../services"

// Sound menu that grows out of the bar under the speaker icon.
// Main volume and output device on top, one slider per app below.
PanelWindow {
    id: snd
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Open on the monitor you are using (matters with two screens)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "soundmenu"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool open: ShellState.soundOpen
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: snd.open ? 440 : 240
            easing.type: snd.open ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: 0.9
        }
    }
    visible: open || reveal > 0.01

    function close() { ShellState.soundOpen = false }

    // Only one sheet from the bar at a time
    Connections {
        target: ShellState
        function onSoundOpenChanged() {
            if (ShellState.soundOpen) {
                ShellState.controlCenterOpen = false
                ShellState.calendarOpen = false
                ShellState.weatherOpen = false
                sheet.forceActiveFocus()
            }
        }
        function onControlCenterOpenChanged() { if (ShellState.controlCenterOpen) snd.close() }
        function onCalendarOpenChanged() { if (ShellState.calendarOpen) snd.close() }
        function onWeatherOpenChanged() { if (ShellState.weatherOpen) snd.close() }
    }

    // ---------- Pipewire ----------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    // Apps that are playing sound right now
    readonly property var apps: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)

    PwObjectTracker { objects: [snd.sink, ...snd.apps] }

    function appName(n) {
        const p = n.properties ?? {}
        return p["application.name"] || n.description || n.nickname || n.name || "App"
    }
    function appIcon(n) {
        const p = n.properties ?? {}
        const name = p["application.icon-name"] || p["application.process.binary"] || appName(n)
        const entry = DesktopEntries.heuristicLookup(name)
        return Quickshell.iconPath(entry?.icon ?? name.toLowerCase(), "audio-x-generic")
    }
    function nameOf(n) { return n?.description || n?.nickname || n?.name || "Unknown" }

    function nextOutput() {
        if (outputs.length < 2) return
        const i = outputs.indexOf(sink)
        Pipewire.preferredDefaultAudioSink = outputs[(i + 1) % outputs.length]
    }

    function volumeIcon(v, muted) {
        if (muted || v === 0) return "audio-volume-muted-symbolic"
        if (v < 0.34) return "audio-volume-low-symbolic"
        if (v < 0.67) return "audio-volume-medium-symbolic"
        return "audio-volume-high-symbolic"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: snd.close()
    }

    // ---------- Pieces ----------
    component Fillet: Canvas {
        property bool mirrored: false
        y: Tokens.barHeight
        width: 14
        height: 14
        opacity: Math.min(1, snd.reveal * 4)
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(mirrored ? 14 : 0, 14, 14, 0, Math.PI * 2)
            c.fill()
        }
    }
    Fillet { x: sheet.x - 14 }
    Fillet { x: sheet.x + sheet.width; mirrored: true }

    // Icon (click = mute) + slider + percent
    component VolumeRow: Item {
        id: vr
        property var node: null
        property string icon: ""
        property bool small: false
        readonly property var audio: node?.audio ?? null
        readonly property real volume: audio?.volume ?? 0
        readonly property bool muted: audio?.muted ?? false

        width: parent ? parent.width : 0
        height: small ? 30 : 36

        Rectangle {
            id: muteBtn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: vr.small ? 26 : 30
            height: width
            radius: width / 2
            color: vr.muted ? Qt.rgba(1, 1, 1, 0.08) : Tokens.fillHover
            scale: muteMouse.pressed ? Tokens.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

            Image {
                anchors.centerIn: parent
                width: vr.small ? 16 : 16
                height: width
                sourceSize: Qt.size(32, 32)
                source: vr.icon !== "" ? vr.icon
                    : Quickshell.iconPath(snd.volumeIcon(vr.volume, vr.muted), "audio-volume-high")
                opacity: vr.muted ? 0.45 : 1
            }

            MouseArea {
                id: muteMouse
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: if (vr.audio) vr.audio.muted = !vr.audio.muted
            }
        }

        Item {
            id: track
            anchors.left: muteBtn.right
            anchors.leftMargin: Tokens.spaceMd
            anchors.right: pct.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 20

            readonly property real shown: vr.muted ? 0 : Math.min(1, vr.volume)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: dragArea.containsMouse || dragArea.pressed ? 8 : 6
                radius: height / 2
                color: Tokens.fillHover
                Behavior on height { NumberAnimation { duration: Tokens.durFast } }

                Rectangle {
                    width: parent.width * track.shown
                    height: parent.height
                    radius: parent.radius
                    color: vr.muted ? Tokens.textSecondary : Tokens.accent
                }
            }

            Rectangle {
                x: track.width * track.shown - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: "white"
                opacity: dragArea.containsMouse || dragArea.pressed ? 1 : 0
                scale: dragArea.pressed ? 1.15 : 1
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                function set(mx) {
                    if (!vr.audio) return
                    vr.audio.muted = false
                    vr.audio.volume = Math.max(0, Math.min(1, (mx - 6) / track.width))
                }
                onPressed: mouse => set(mouse.x)
                onPositionChanged: mouse => { if (pressed) set(mouse.x) }
            }

            WheelHandler {
                onWheel: event => {
                    if (!vr.audio) return
                    vr.audio.volume = Math.max(0, Math.min(1, vr.audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)))
                }
            }
        }

        Text {
            id: pct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: vr.muted ? "Mute" : Math.round(vr.volume * 100) + "%"
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
            font.features: { "tnum": 1 }
        }
    }

    // ---------- Sheet ----------
    Item {
        id: sheet
        width: 320
        x: Math.max(6, Math.min(snd.width - width - 6, ShellState.soundAnchorX - width / 2))
        y: Tokens.barHeight
        readonly property real fullHeight: body.implicitHeight + 28
        height: fullHeight * Math.max(0, snd.reveal)
        clip: true
        focus: true
        Keys.onEscapePressed: snd.close()

        Rectangle {
            y: -20
            width: parent.width
            height: parent.height + 20
            radius: Tokens.radiusXl
            color: Tokens.barBg
        }

        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 10
            opacity: Math.max(0, Math.min(1, (snd.reveal - 0.3) / 0.5))

            Text {
                text: "Sound"
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontTitle
                font.weight: Font.DemiBold
            }

            // ---------- Main volume ----------
            Rectangle {
                width: parent.width
                height: mainCol.implicitHeight + 20
                radius: Tokens.radiusLg
                color: Tokens.fillIdle
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                Column {
                    id: mainCol
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: Tokens.spaceSm

                    VolumeRow { node: snd.sink }

                    // Output device (click to switch when there are several)
                    Rectangle {
                        scale: devMouse.pressed ? Tokens.pressScale : 1
                        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                        width: parent.width
                        height: 30
                        radius: Tokens.radiusMd
                        color: devMouse.containsMouse && snd.outputs.length > 1 ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Image {
                            id: devIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            sourceSize: Qt.size(28, 28)
                            opacity: 0.7
                            source: Quickshell.iconPath("audio-speakers-symbolic", "audio-card")
                        }

                        Text {
                            anchors.left: devIcon.right
                            anchors.leftMargin: Tokens.spaceSm
                            anchors.right: devArrow.left
                            anchors.rightMargin: Tokens.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            text: snd.nameOf(snd.sink)
                            color: Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontBody
                            elide: Text.ElideRight
                        }

                        Text {
                            id: devArrow
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            visible: snd.outputs.length > 1
                            text: "⇄"
                            color: Tokens.textSecondary
                            font.pixelSize: Tokens.fontBody
                        }

                        MouseArea {
                            id: devMouse
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: snd.nextOutput()
                        }
                    }
                }
            }

            // ---------- Apps ----------
            Text {
                text: "Apps"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
                font.weight: Font.Medium
            }

            Text {
                visible: snd.apps.length === 0
                text: "No apps are playing sound"
                color: Tokens.textSecondary
                opacity: 0.7
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
            }

            Repeater {
                model: snd.apps

                Column {
                    id: appCol
                    required property var modelData
                    width: body.width
                    spacing: 2

                    Text {
                        leftPadding: 38
                        width: parent.width
                        text: snd.appName(appCol.modelData)
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontBody
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    VolumeRow {
                        node: appCol.modelData
                        icon: snd.appIcon(appCol.modelData)
                        small: true
                    }
                }
            }
        }
    }
}
