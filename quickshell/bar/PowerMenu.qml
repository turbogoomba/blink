import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../theme"
import "../services"

// Power menu that slides out of the right edge of the frame, from the bottom-right corner.
// Opened by the bottom-right hot corner (Settings > Hot Corners) or:
//   qs -c blink ipc call power toggle
// Closes when the mouse leaves it.
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "powermenu"

    readonly property bool open: ShellState.powerMenuOpen
    // Out of the side bar (bottom left) or out of the right edge of the frame (bottom right).
    // Only changes while closed, so it does not jump during the close animation.
    property bool fromLeft: false
    readonly property int frameT: ShellState.gameMode ? 0 : Tokens.frameT
    readonly property int sheetW: 340

    // 0 = hidden inside the frame, 1 = fully out
    property real reveal: open ? 1 : 0
    // Same open/close motion as the other sheets (SoundMenu, Calendar, Weather)
    Behavior on reveal {
        id: openBehavior   // targetValue = where it is going, read before the animation starts
        NumberAnimation {
            duration: openBehavior.targetValue > 0.5 ? 440 : 240
            easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: Tokens.bounce
        }
    }

    visible: open || reveal > 0.001

    // Only the sheet takes clicks
    mask: Region { x: sheet.x; y: sheet.y; width: sheet.width; height: sheet.height }

    // ---------- Power buttons that need a second click ----------
    property string armed: ""
    Timer {
        id: armTimer
        interval: 3000
        onTriggered: win.armed = ""
    }

    function close() {
        ShellState.powerMenuOpen = false
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

    function iconFile(name) { return Qt.resolvedUrl("../icons/" + name + ".svg") }

    onOpenChanged: {
        if (open) fromLeft = SettingsService.sideBar && ShellState.powerMenuFrom === "left"
        armed = ""
        entered = false
        if (open) IdleService.update()
    }

    // ---------- Close when the mouse leaves ----------
    // Only after it has been inside once, so opening it from a keybind does not close it right away.
    property bool entered: false
    Timer {
        id: leaveTimer
        interval: 350
        onTriggered: win.close()
    }

    // Only one of power menu / control center / calendar at a time
    Connections {
        target: ShellState
        function onPowerMenuOpenChanged() {
            if (ShellState.powerMenuOpen) {
                ShellState.controlCenterOpen = false
                ShellState.calendarOpen = false
            }
        }
        function onControlCenterOpenChanged() { if (ShellState.controlCenterOpen) ShellState.powerMenuOpen = false }
        function onCalendarOpenChanged() { if (ShellState.calendarOpen) ShellState.powerMenuOpen = false }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { ShellState.powerMenuOpen = !ShellState.powerMenuOpen }
    }

    // ---------- Battery line ----------
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property string batteryText: {
        if (!hasBattery) return ""
        const p = battery.percentage > 1 ? battery.percentage : battery.percentage * 100
        let t = Math.round(p) + " %"
        const secs = UPower.onBattery ? battery.timeToEmpty : battery.timeToFull
        if (secs > 0) {
            const h = Math.floor(secs / 3600)
            const m = Math.round((secs % 3600) / 60)
            t += " · " + (h > 0 ? h + " h " : "") + m + " min" + (UPower.onBattery ? " left" : " to full")
        }
        return t
    }

    // ================= Building blocks =================

    // Concave corner where the sheet meets the frame. The hole is centred on (cx, cy).
    component Fillet: Canvas {
        property real cx: 0
        property real cy: 0
        width: 14
        height: 14
        visible: win.reveal > 0.001
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(cx, cy, 14, 0, Math.PI * 2)
            c.fill()
        }
    }

    component ProfileTile: Rectangle {
        id: tile
        property int value: PowerProfile.Balanced
        property string icon: ""
        property string label: ""
        readonly property bool selected: PowerProfiles.profile === value
        readonly property bool usable: value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

        height: 74
        radius: Tokens.radiusLg
        opacity: usable ? 1 : 0.4
        color: selected ? Tokens.accent : tileMouse.containsMouse ? Tokens.fillHover : Tokens.fillIdle
        scale: tileMouse.pressed ? Tokens.pressScale : 1
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        Column {
            anchors.centerIn: parent
            spacing: 7

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 20
                height: 20
                sourceSize: Qt.size(40, 40)
                source: win.iconFile(tile.icon)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                color: tile.selected ? "white" : Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall + 1
                font.weight: tile.selected ? Font.DemiBold : Font.Medium
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: tile.usable
            onClicked: PowerProfiles.profile = tile.value
        }
    }

    component Chip: Rectangle {
        id: chip
        property int mins: 0
        property string label: ""
        readonly property bool selected: IdleService.awake && IdleService.minutes === mins

        width: chipText.implicitWidth + 20
        height: 26
        radius: 13
        color: selected ? Tokens.fillStrong : chipMouse.containsMouse ? Tokens.fillHover : Tokens.fillIdle
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
            font.weight: chip.selected ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: IdleService.keepAwake(chip.mins)
        }
    }

    component PowerButton: Item {
        id: pb
        property string powerId: ""
        property string icon: ""
        property string label: ""
        property var command: []
        property bool confirm: true
        property bool danger: false
        readonly property bool isArmed: win.armed === powerId

        width: 52
        height: 64

        Rectangle {
            id: circle
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: 44
            radius: 22
            color: pb.isArmed ? Tokens.red
                 : pb.danger ? Qt.rgba(1, 0.27, 0.23, pbMouse.containsMouse ? 0.3 : 0.18)
                 : pbMouse.containsMouse ? Tokens.fillStrong : Tokens.fillIdle
            scale: pbMouse.pressed ? Tokens.pressScaleIcon : 1
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

            SequentialAnimation {
                running: pb.isArmed
                loops: Animation.Infinite
                NumberAnimation { target: circle; property: "opacity"; to: 0.65; duration: Tokens.durSlow; easing.type: Easing.InOutSine }
                NumberAnimation { target: circle; property: "opacity"; to: 1; duration: Tokens.durSlow; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) circle.opacity = 1
            }

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                sourceSize: Qt.size(36, 36)
                source: win.iconFile(pb.icon)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: circle.bottom
            anchors.topMargin: 5
            text: pb.isArmed ? "Sure?" : pb.label
            color: pb.isArmed ? Tokens.textPrimary : Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
            font.weight: pb.isArmed ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.power(pb.powerId, pb.command, pb.confirm)
        }
    }

    // ================= The sheet =================

    // Above the sheet, where it meets the right edge of the frame
    Fillet {
        cx: win.fromLeft ? 14 : 0; cy: 0
        onCxChanged: requestPaint()
        x: win.fromLeft ? SettingsService.sideWidth : win.width - win.frameT - 14
        y: sheet.y - 14
    }
    // Beside the sheet, where it meets the bottom edge of the frame
    Fillet {
        cx: win.fromLeft ? 14 : 0; cy: 0
        onCxChanged: requestPaint()
        x: win.fromLeft ? sheet.x + sheet.width : sheet.x - 14
        y: win.height - win.frameT - 14
    }

    Item {
        id: sheet
        width: win.sheetW * win.reveal
        // Soft shadow, so it floats over what is under it
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Tokens.shadowColor
            shadowBlur: Tokens.shadowBlur
            blurMax: 32
            shadowVerticalOffset: 2
        }
        height: content.implicitHeight + 2 * 18
        x: win.fromLeft ? SettingsService.sideWidth : win.width - win.frameT - width
        y: win.height - win.frameT - height
        clip: true

        // Black like the frame, square where it joins it, round at the free corner
        Rectangle {
            x: win.fromLeft ? -30 : 0
            width: parent.width + 30
            height: parent.height + 30
            radius: 22
            color: Tokens.barBg
        }

        HoverHandler {
            id: sheetHover
            onHoveredChanged: {
                if (hovered) {
                    win.entered = true
                    leaveTimer.stop()
                } else if (win.entered && win.open) {
                    leaveTimer.restart()
                }
            }
        }

        // The content keeps its full width and slides in with the leading edge
        Column {
            id: content
            x: win.fromLeft ? sheet.width - win.sheetW + 18 : 20
            y: 18
            width: win.sheetW - 38
            spacing: 14

            // Header
            Item {
                width: parent.width
                height: 20
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Power"
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontTitle
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.batteryText
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall
                }
            }

            // Power profiles
            Row {
                id: profiles
                width: parent.width
                spacing: Tokens.spaceSm
                readonly property real tileW: (width - 2 * spacing) / 3

                ProfileTile { width: profiles.tileW; value: PowerProfile.PowerSaver; icon: "saver"; label: "Saver" }
                ProfileTile { width: profiles.tileW; value: PowerProfile.Balanced; icon: "balanced"; label: "Balanced" }
                ProfileTile { width: profiles.tileW; value: PowerProfile.Performance; icon: "performance"; label: "Performance" }
            }

            // Keep awake
            Rectangle {
                width: parent.width
                height: awakeCol.implicitHeight + 24
                radius: Tokens.radiusLg
                color: Tokens.fillIdle

                Column {
                    id: awakeCol
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 32

                        Rectangle {
                            id: cup
                            width: 32
                            height: 32
                            radius: 16
                            color: IdleService.awake ? Tokens.accent : Tokens.fillHover
                            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                sourceSize: Qt.size(32, 32)
                                source: win.iconFile("coffee")
                            }
                        }

                        Column {
                            anchors.left: cup.right
                            anchors.leftMargin: 10
                            anchors.right: awakeSwitch.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: "Keep awake"
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: !IdleService.awake ? "No dimming, locking or sleep"
                                    : IdleService.left > 0 ? "On for " + IdleService.left + " more min"
                                    : "On until you turn it off"
                                color: Tokens.textSecondary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSmall
                            }
                        }

                        // Switch
                        Rectangle {
                            id: awakeSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 22
                            radius: 11
                            color: IdleService.awake ? Tokens.accent : Tokens.fillStrong
                            Behavior on color { ColorAnimation { duration: Tokens.durFast } }

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                y: 2
                                x: IdleService.awake ? parent.width - width - 2 : 2
                                color: "white"
                                Behavior on x { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IdleService.toggle()
                            }
                        }
                    }

                    Row {
                        spacing: 6
                        Chip { mins: 30; label: "30 min" }
                        Chip { mins: 60; label: "1 h" }
                        Chip { mins: 120; label: "2 h" }
                        Chip { mins: 0; label: "Until off" }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Tokens.divider
            }

            // Session buttons
            Row {
                width: parent.width
                spacing: (width - 5 * 52) / 4

                PowerButton { powerId: "lock"; icon: "lock"; label: "Lock"; confirm: false; command: ["loginctl", "lock-session"] }
                PowerButton { powerId: "sleep"; icon: "sleep"; label: "Sleep"; confirm: false; command: ["systemctl", "suspend"] }
                PowerButton { powerId: "logout"; icon: "logout"; label: "Log Out"; command: ["hyprctl", "dispatch", "hl.dsp.exit()"] }
                PowerButton { powerId: "restart"; icon: "restart"; label: "Restart"; command: ["systemctl", "reboot"] }
                PowerButton { powerId: "shutdown"; icon: "power"; label: "Shut Down"; danger: true; command: ["systemctl", "poweroff"] }
            }
        }
    }
}
