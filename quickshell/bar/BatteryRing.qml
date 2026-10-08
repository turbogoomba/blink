import QtQuick
import "../theme"

// Round battery gauge with the percentage in the middle.
Item {
    id: root
    property real level: 0          // 0.0 - 1.0
    property int size: 34
    property real lineWidth: 3
    property bool showText: true

    width: size
    height: size

    readonly property color tint: level < 0.15 ? Tokens.red
                                : level < 0.3 ? Tokens.orange
                                : Tokens.green

    Canvas {
        id: ring
        anchors.fill: parent
        property real level: root.level
        property color tint: root.tint
        onLevelChanged: requestPaint()
        onTintChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            const r = width / 2 - root.lineWidth / 2 - 1
            c.lineWidth = root.lineWidth
            c.lineCap = "round"
            c.strokeStyle = "rgba(255,255,255,0.15)"
            c.beginPath()
            c.arc(width / 2, height / 2, r, 0, 2 * Math.PI)
            c.stroke()
            c.strokeStyle = tint
            c.beginPath()
            c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * level)
            c.stroke()
        }
        Component.onCompleted: requestPaint()
    }

    Text {
        visible: root.showText
        anchors.centerIn: parent
        text: Math.round(root.level * 100)
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: root.size < 30 ? 9 : Tokens.fontSmall
        font.weight: Font.DemiBold
    }
}
