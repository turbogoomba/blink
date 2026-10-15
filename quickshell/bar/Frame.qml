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

    // Game Mode hides the frame so games get the whole screen
    Variants {
        model: ShellState.gameMode ? [] : Quickshell.screens

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

            // ---------- Avrundede innerhjørner ----------
            PanelWindow {
                id: corners
                screen: s.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                mask: Region {}
                // Under the windows, so the shadow only falls on the wallpaper
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "frame-corners"

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
