import QtQuick

// The Liquid Glass rim: a thin light edge, brighter along the top where the light
// hits it. Put it last inside a glass surface, with the same radius as the surface.
// Shows only on glass themes.
Item {
    id: edge
    anchors.fill: parent
    visible: Tokens.glass
    property real radius: Tokens.radiusXl
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        topLeftRadius: edge.topLeftRadius
        topRightRadius: edge.topRightRadius
        bottomLeftRadius: edge.bottomLeftRadius
        bottomRightRadius: edge.bottomRightRadius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.13)
    }
    // Shine along the top edge, fading out toward the corners
    Rectangle {
        x: Math.max(edge.topLeftRadius, 8)
        width: parent.width - x - Math.max(edge.topRightRadius, 8)
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.32) }
            GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.32) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
