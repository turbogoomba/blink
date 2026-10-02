import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

Scope {
    id: frame

    // Juster disse for tykkere/tynnere ramme og rundere hjørner
    property int thickness: 6
    property int radius: 14
    property color color: Tokens.barBg

    Variants {
        model: Quickshell.screens

        Scope {
            id: s
            required property var modelData

            // ---------- Kantene ----------
            // mask: Region {} gjør dem gjennomklikkbare

            PanelWindow {
                screen: s.modelData
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
                WlrLayershell.namespace: "frame-corners"

                // Et svart kvadrat med en kvartsirkel skåret ut
                component Corner: Canvas {
                    property real cx: 0
                    property real cy: 0

                    width: frame.radius
                    height: frame.radius

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

                // Øverst til venstre
                Corner {
                    x: frame.thickness
                    y: Tokens.barHeight
                    cx: width
                    cy: height
                }
                // Øverst til høyre
                Corner {
                    x: corners.width - frame.thickness - width
                    y: Tokens.barHeight
                    cx: 0
                    cy: height
                }
                // Nederst til venstre
                Corner {
                    x: frame.thickness
                    y: corners.height - frame.thickness - height
                    cx: width
                    cy: 0
                }
                // Nederst til høyre
                Corner {
                    x: corners.width - frame.thickness - width
                    y: corners.height - frame.thickness - height
                    cx: 0
                    cy: 0
                }
            }
        }
    }
}
