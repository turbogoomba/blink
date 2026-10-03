import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

// Audio visualizer on the frame, while music plays.
// Settings > Display & Dock > Frame visualizer: "off", "glow", "bars" or "both".
//   glow: the inside edge of the frame glows in the accent color with the bass
//   bars: a spectrum grows out of the left and right frame, bass in the middle
Variants {
    model: SettingsService.frameViz !== "off" && !ShellState.gameMode ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "frameviz"
        visible: CavaService.active

        readonly property int frameT: 6
        readonly property int radius: 14
        readonly property bool glow: SettingsService.frameViz === "glow" || SettingsService.frameViz === "both"
        readonly property bool bars: SettingsService.frameViz === "bars" || SettingsService.frameViz === "both"

        // Smoothed bass level
        property real lvl: CavaService.level
        Behavior on lvl { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        // ---------- Glow: three rings along the inside edge, fading inward ----------
        // Drawn in three clipped pieces so the top edge leaves a gap for the notch
        // (this layer sits above the bar).
        readonly property real gap: ShellState.notchWidth + 40
        readonly property real gapL: (width - gap) / 2
        readonly property real gapR: (width + gap) / 2

        component GlowRing: Item {
            Repeater {
                model: [
                    { inset: 0, width: 2, alpha: 0.9 },
                    { inset: 2, width: 3, alpha: 0.35 },
                    { inset: 5, width: 4, alpha: 0.14 }
                ]

                Rectangle {
                    required property var modelData
                    x: win.frameT + modelData.inset
                    y: Tokens.barHeight + modelData.inset
                    width: win.width - 2 * win.frameT - 2 * modelData.inset
                    height: win.height - Tokens.barHeight - win.frameT - 2 * modelData.inset
                    radius: Math.max(0, win.radius - modelData.inset)
                    color: "transparent"
                    border.color: Tokens.accent
                    border.width: modelData.width
                    opacity: win.lvl * modelData.alpha
                }
            }
        }

        // Left of the notch, full height
        Item {
            visible: win.glow
            width: win.gapL
            height: win.height
            clip: true
            GlowRing {}
        }
        // Right of the notch, full height
        Item {
            visible: win.glow
            x: win.gapR
            width: win.width - win.gapR
            height: win.height
            clip: true
            GlowRing { x: -win.gapR }
        }
        // Under the notch: only the bottom half
        Item {
            visible: win.glow
            x: win.gapL
            y: win.height / 2
            width: win.gap
            height: win.height / 2
            clip: true
            GlowRing { x: -win.gapL; y: -win.height / 2 }
        }

        // ---------- Bars: 24 per side, mirrored around the middle ----------
        readonly property real barsTop: Tokens.barHeight + 24
        readonly property real span: height - Tokens.barHeight - frameT - 48
        readonly property int count: CavaService.bars * 2
        readonly property real slot: span / count

        component Bar: Rectangle {
            required property int index
            property bool onRight: false
            // Middle bars are the bass, outer ones the treble
            readonly property int band: Math.floor(Math.abs(index - (win.count - 1) / 2))
            readonly property real v: (CavaService.values[band] ?? 0) / CavaService.maxValue

            y: win.barsTop + index * win.slot + 1.5
            height: Math.max(1, win.slot - 3)
            width: 2 + v * 14
            x: onRight ? win.width - win.frameT - width : win.frameT
            radius: height / 2
            color: Tokens.accent
            opacity: 0.35 + v * 0.55
            Behavior on width { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
        }

        Repeater {
            model: win.bars ? win.count : 0
            Bar {}
        }
        Repeater {
            model: win.bars ? win.count : 0
            Bar { onRight: true }
        }
    }
}
