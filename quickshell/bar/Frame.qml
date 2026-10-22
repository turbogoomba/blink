import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

Scope {
    id: frame

    // Juster disse for tykkere/tynnere ramme og rundere hjørner
    property int thickness: Tokens.frameT
    property int radius: 20
    property color color: Tokens.barBg

    // Game Mode hides the frame so games get the whole screen.
    // Glass themes have no frame either, like macOS: just the bar and the floating dock.
    Variants {
        model: ShellState.gameMode || Tokens.glass ? [] : Quickshell.screens

        Scope {
            id: s
            required property var modelData

            // ---------- Kantene ----------
            // mask: Region {} gjør dem gjennomklikkbare

            PanelWindow {
                screen: s.modelData
                // The side bar takes this edge when it is on
                visible: !SettingsService.sideBar
                anchors { top: true; bottom: true; left: true }
                implicitWidth: frame.thickness
                exclusiveZone: frame.thickness
                color: frame.color
                mask: Region {}
                WlrLayershell.namespace: "frame"
            }

            PanelWindow {
                screen: s.modelData
                anchors { top: true; bottom: true; right: true }
                implicitWidth: frame.thickness
                exclusiveZone: frame.thickness
                color: frame.color
                mask: Region {}
                WlrLayershell.namespace: "frame"
            }

            // Top edge, only with the side bar (the top bar covers it otherwise)
            PanelWindow {
                screen: s.modelData
                visible: SettingsService.sideBar
                anchors { top: true; left: true; right: true }
                implicitHeight: frame.thickness
                exclusiveZone: frame.thickness
                color: frame.color
                mask: Region {}
                WlrLayershell.namespace: "frame"
            }

            PanelWindow {
                screen: s.modelData
                anchors { bottom: true; left: true; right: true }
                implicitHeight: frame.thickness
                exclusiveZone: frame.thickness
                color: frame.color
                mask: Region {}
                WlrLayershell.namespace: "frame"
            }

            // ---------- Rounded inner corners, above the windows ----------
            PanelWindow {
                id: cornersTop
                screen: s.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                mask: Region {}
                WlrLayershell.namespace: "frame-corners"

                // A black square with a quarter circle cut out
                component Corner: Canvas {
                    readonly property string paintKey: Tokens.themeName + Tokens.accent
                    onPaintKeyChanged: requestPaint()
                    property real cx: 0
                    property real cy: 0
                    width: frame.radius
                    height: frame.radius
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d")
                        c.reset()
                        c.fillStyle = frame.color.toString()
                        c.fillRect(0, 0, width, height)
                        c.globalCompositeOperation = "destination-out"
                        c.beginPath()
                        c.arc(cx, cy, width, 0, 2 * Math.PI)
                        c.fill()
                    }
                    Component.onCompleted: requestPaint()
                }

                Corner { x: SettingsService.leftInset; y: SettingsService.topInset; cx: width; cy: height }
                Corner { x: cornersTop.width - frame.thickness - width; y: SettingsService.topInset; cx: 0; cy: height }
                Corner { x: SettingsService.leftInset; y: cornersTop.height - frame.thickness - height; cx: width; cy: 0 }
                Corner { x: cornersTop.width - frame.thickness - width; y: cornersTop.height - frame.thickness - height; cx: 0; cy: 0 }
            }

            // ---------- Shadow along the inner edge (under the windows) ----------
            PanelWindow {
                id: corners
                screen: s.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                mask: Region {}
                // Under the windows, so the shadow only falls on the wallpaper
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "frame-shadow"

                // The frame's inner edge: a black ring with rounded inner corners,
                // with a soft shadow falling onto the wallpaper
                readonly property real ringB: 60
                Item {
                    id: ringSource
                    anchors.fill: parent
                    visible: false

                    Rectangle {
                        x: SettingsService.leftInset - corners.ringB
                        y: SettingsService.topInset - corners.ringB
                        width: corners.width - SettingsService.leftInset - frame.thickness + 2 * corners.ringB
                        height: corners.height - SettingsService.topInset - frame.thickness + 2 * corners.ringB
                        radius: frame.radius + corners.ringB
                        color: "transparent"
                        border.color: frame.color
                        border.width: corners.ringB
                    }
                }

                MultiEffect {
                    visible: Tokens.frameShadow
                    source: ringSource
                    anchors.fill: ringSource
                    shadowEnabled: true
                    shadowColor: Tokens.shadowColor
                    shadowBlur: Tokens.shadowBlur
                    blurMax: 32
                    shadowVerticalOffset: 2
                }
            }
        }
    }
}
