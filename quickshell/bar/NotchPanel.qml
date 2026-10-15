import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// The notch panel for the side bar. Same Notch.qml as the top bar, but it only
// shows its open panel (Nook, Tray, Notifications): click the Blink face in the
// side bar and it slides out of the bar in the top-left corner. Closes like the
// notch does, when the mouse leaves it.
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notchpanel"

    readonly property int leftEdge: SettingsService.sideWidth
    readonly property int topEdge: Tokens.frameT

    // Only the open panel; no idle tab, toasts or live activities in the corner
    readonly property bool active: notch.open

    property real reveal: active ? 1 : 0
    Behavior on reveal {
        id: openBehavior
        NumberAnimation {
            duration: openBehavior.targetValue > 0.5 ? Tokens.durOpen : Tokens.durClose
            easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: Tokens.bounce
        }
    }
    // The content waits until the sheet is mostly out, then fades and rises in.
    // Closing: it goes first, quickly, before the sheet slides back.
    property real contentIn: win.active ? 1 : 0
    Behavior on contentIn {
        id: contentBehavior
        SequentialAnimation {
            PauseAnimation { duration: contentBehavior.targetValue > 0.5 ? Tokens.contentDelay : 0 }
            NumberAnimation {
                duration: contentBehavior.targetValue > 0.5 ? Tokens.contentIn : Tokens.contentOut
                easing.type: Tokens.easeMove
            }
        }
    }


    // The size the panel grows to. Kept when it closes, so it shrinks from the
    // size it had instead of jumping to the small idle notch first.
    property real panelW: 660
    property real panelH: 200
    Binding { target: win; property: "panelW"; value: notch.width; when: win.active; restoreMode: Binding.RestoreNone }
    Binding { target: win; property: "panelH"; value: notch.height; when: win.active; restoreMode: Binding.RestoreNone }

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
        readonly property string paintKey: Tokens.themeName + Tokens.accent
        onPaintKeyChanged: requestPaint()
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
    Fillet { x: holder.x + holder.width; y: win.topEdge; opacity: Math.min(1, win.reveal * 4) }
    // Under the notch, next to the side bar
    Fillet { x: win.leftEdge; y: win.topEdge + holder.height; opacity: Math.min(1, win.reveal * 4) }

    // Slides out of the side bar, like the other sheets
    Item {
        id: holder
        x: win.leftEdge
        y: win.topEdge
        width: win.panelW * win.reveal
        height: win.panelH
        visible: win.reveal > 0.005
        clip: true
        // Soft shadow, so it floats over what is under it
        layer.enabled: Tokens.menuShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Tokens.shadowColor
            shadowBlur: Tokens.shadowBlur
            blurMax: 32
            shadowVerticalOffset: 2
        }

        // The shape: square where it joins the bar and the top edge, round at the bottom right
        Rectangle {
            anchors.fill: parent
            color: Tokens.barBg
            bottomRightRadius: Math.min(24, height / 2, width / 2)
        }

        Item {
            id: box
            // Stays in place (it does not ride on the edge out of the bar);
            // it only drifts the last bit as it fades in
            x: 0
            width: win.panelW
            height: win.panelH
            opacity: win.contentIn
            transform: Translate { x: -(1 - win.contentIn) * 14 }

            Notch {
                id: notch
                baseHeight: Tokens.barHeight
                lookTarget: NaN
                // No morph of its own while the panel slides; tab changes inside still morph
                animateSize: win.reveal > 0.98
                fadeContent: false
                color: "transparent"
            }

            // What you see is a live picture of the notch (it still takes the mouse
            // and keys). When it closes, the notch has already gone back to idle,
            // so the picture stops updating and keeps showing the open panel while
            // it slides back in.
            ShaderEffectSource {
                id: snapshot
                width: win.panelW
                height: win.panelH
                sourceItem: notch
                hideSource: true
                live: win.active
            }
        }
    }
}
