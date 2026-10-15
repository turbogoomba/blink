import QtQuick
import QtQuick.Shapes
import "../theme"

// A line icon drawn from an SVG path (24x24 viewBox), in any color.
//   LineIcon { d: "M5 7l5 5-5 5"; tint: Tokens.accent; size: 16 }
Item {
    id: g
    property string d: ""
    property color tint: Tokens.textPrimary
    property real size: 16
    property real stroke: 2.2

    width: size
    height: size

    Shape {
        width: 24
        height: 24
        scale: g.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: g.tint
            strokeWidth: g.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: g.d }
        }
    }
}
