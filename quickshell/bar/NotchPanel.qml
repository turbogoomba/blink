import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// The notch for the side bar. Same Notch.qml as the top bar, but it lives in the
// top-left corner and slides out of the side bar when it has something to show:
// the open panel (click the Blink face in the side bar), music, notifications,
// volume/brightness, Bluetooth and the next class.
// When there is nothing to show it slides back into the bar.
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notchpanel"

    readonly property int leftEdge: SettingsService.sideWidth
    readonly property int topEdge: 6

    // Anything worth showing?
    readonly property bool active: notch.open || notch.showOsd || notch.showNotif || notch.showBt
        || notch.showClass || notch.compact || notch.showRec || notch.peek

    property real reveal: active ? 1 : 0
    Behavior on reveal {
        id: openBehavior
        NumberAnimation {
            duration: openBehavior.targetValue > 0.5 ? 440 : 240
            easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: Tokens.bounce
        }
    }

    visible: !ShellState.gameMode

    // Only the notch takes the mouse
    mask: Region { item: holder }

    // The face in the side bar toggles the open panel
    Connections {
        target: ShellState
        function onNotchToggleTickChanged() {
            if (!notch.open) notch.tab = "nook"
            notch.open = !notch.open
        }
    }

    // ---------- Concave corners where it meets the bar and the top edge ----------
    component Fillet: Canvas {
        width: 14
        height: 14
        visible: win.reveal > 0.01
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(14, 14, 14, 0, Math.PI * 2)
            c.fill()
        }
        Component.onCompleted: requestPaint()
    }
    // Right of the notch, under the top edge
    Fillet { x: holder.x + holder.width; y: win.topEdge }
    // Under the notch, next to the side bar
    Fillet { x: win.leftEdge; y: win.topEdge + notch.height }

    // Clip, so it slides out from behind the side bar
    Item {
        id: holder
        x: win.leftEdge
        y: win.topEdge
        width: notch.width * win.reveal
        height: notch.height
        clip: true

        Item {
            // Stays against the bar even when the bounce overshoots
            x: Math.min(0, holder.width - notch.width)
            width: notch.width
            height: notch.height

            // Square corners where it joins the bar and the top edge; only the
            // bottom-right corner stays round
            Rectangle {
                width: notch.width
                height: notch.height / 2
                color: Tokens.barBg
            }
            Rectangle {
                width: notch.width / 2
                height: notch.height
                color: Tokens.barBg
            }

            Notch {
                id: notch
                baseHeight: Tokens.barHeight
                lookTarget: NaN
            }
        }
    }
}
