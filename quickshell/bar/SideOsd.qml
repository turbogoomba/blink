import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Volume and brightness for the side bar: a tall pill that slides out of the
// bar in the middle of the screen, Caelestia-style. Drag the bar to change it.
// (With the top bar the notch shows these instead.)
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sideosd"

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    readonly property bool active: OsdService.shown && OsdService.kind !== "workspace"
    // Stays out while the mouse is on it
    readonly property bool open: active || sheetHover.hovered || drag.pressed

    // Keep showing the last kind while it slides back in
    property string kind: "volume"
    Connections {
        target: OsdService
        function onShownChanged() { if (OsdService.shown && OsdService.kind !== "workspace") win.kind = OsdService.kind }
        function onKindChanged() { if (OsdService.kind !== "workspace") win.kind = OsdService.kind }
    }

    readonly property real level: kind === "brightness" ? BrightnessService.value
        : (OsdService.sink?.audio?.volume ?? 0)
    readonly property bool muted: kind === "volume" && (OsdService.sink?.audio?.muted ?? false)

    property real reveal: open ? 1 : 0
    Behavior on reveal {
        id: openBehavior
        NumberAnimation {
            duration: openBehavior.targetValue > 0.5 ? Tokens.durOpen : Tokens.durClose
            easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: Tokens.bounce
        }
    }
    visible: !ShellState.gameMode && (open || reveal > 0.01)

    mask: Region { item: sheet }

    readonly property real sheetW: 56
    readonly property real sheetH: 230

    function setLevel(v) {
        v = Math.max(0, Math.min(1, v))
        if (kind === "brightness") {
            if (BrightnessService.available) BrightnessService.set(Math.max(0.01, v))
        } else if (OsdService.sink?.audio) {
            OsdService.sink.audio.muted = false
            OsdService.sink.audio.volume = v
        }
    }

    readonly property var icons: ({
        volume: "M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6M19 6a8 8 0 0 1 0 12",
        low:    "M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6",
        muted:  "M4 9v6h4l5 4V5L8 9zM17 9l5 6M22 9l-5 6",
        sun:    "M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"
    })

    // Concave corners above and below the pill, against the bar
    component Fillet: Canvas {
        readonly property string paintKey: Tokens.themeName + Tokens.accent
        onPaintKeyChanged: requestPaint()
        property real cy: 0
        width: 14
        height: 14
        visible: sheet.width > 1
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(14, cy, 14, 0, Math.PI * 2)
            c.fill()
        }
        Component.onCompleted: requestPaint()
    }
    Fillet { x: SettingsService.sideWidth; y: sheet.y - 14; cy: 0 }
    Fillet { x: SettingsService.sideWidth; y: sheet.y + sheet.height; cy: 14 }

    Item {
        id: sheet
        x: SettingsService.sideWidth
        y: (win.height - height) / 2
        width: win.sheetW * Math.max(0, win.reveal)
        height: win.sheetH
        clip: true

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Tokens.shadowColor
            shadowBlur: Tokens.shadowBlur
            blurMax: 32
            shadowVerticalOffset: 2
        }

        // Square against the bar, round on the right
        Rectangle {
            anchors.fill: parent
            topRightRadius: Tokens.radiusXl
            bottomRightRadius: Tokens.radiusXl
            color: Tokens.barBg
        }

        HoverHandler { id: sheetHover }

        // Content slides in with the leading edge
        Item {
            x: sheet.width - win.sheetW
            width: win.sheetW
            height: parent.height

            LineIcon {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                y: 16
                size: 20
                d: win.kind === "brightness" ? win.icons.sun
                    : win.muted || win.level === 0 ? win.icons.muted
                    : win.level < 0.5 ? win.icons.low : win.icons.volume
                tint: win.muted ? Tokens.textSecondary : Tokens.textPrimary
            }

            // The bar you can drag
            Rectangle {
                id: track
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: icon.bottom
                anchors.topMargin: 14
                anchors.bottom: pct.top
                anchors.bottomMargin: 12
                width: 16
                radius: 8
                color: Tokens.ink(0.1)

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    property real shown: win.muted ? 0 : win.level
                    Behavior on shown { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                    height: Math.max(parent.width, parent.height * shown)
                    radius: 8
                    color: win.muted ? Tokens.fillStrong : Tokens.accent
                    Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                }

                MouseArea {
                    id: drag
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    function apply(y) { win.setLevel(1 - (y - 10) / track.height) }
                    onPressed: mouse => apply(mouse.y)
                    onPositionChanged: mouse => { if (pressed) apply(mouse.y) }
                    onWheel: wheel => win.setLevel(win.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }

            Text {
                id: pct
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                text: win.muted ? "Off" : Math.round(win.level * 100)
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }
}
