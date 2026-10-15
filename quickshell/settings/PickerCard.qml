import QtQuick
import "../theme" as Theme

// A big choice with a picture: preview on top, title and a line under it,
// check mark when it is the one in use. Put the preview inside it as children.
//   PickerCard { title: "Side bar"; subtitle: "..."; selected: true; onClicked: ...; Rectangle { ... } }
Rectangle {
    id: pc
    property string title: ""
    property string subtitle: ""
    property bool selected: false
    property real previewHeight: 120
    signal clicked()
    default property alias preview: previewBox.data

    readonly property color accent: Theme.Tokens.accent
    height: previewHeight + 82
    radius: 18
    color: selected ? Qt.rgba(accent.r, accent.g, accent.b, 0.12) : "#1e1e21"
    border.width: 2
    border.color: selected ? accent : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
    scale: mouse.pressed ? Theme.Tokens.pressScale : 1
    Behavior on color { ColorAnimation { duration: Theme.Tokens.durNormal } }
    Behavior on border.color { ColorAnimation { duration: Theme.Tokens.durFast } }
    Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }

    Rectangle {
        id: previewBox
        x: 14
        y: 14
        width: parent.width - 28
        height: pc.previewHeight
        radius: 12
        color: "#000000"
        clip: true
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: check.left
        anchors.rightMargin: 12
        anchors.top: previewBox.bottom
        anchors.topMargin: 12
        spacing: 2
        Text {
            text: pc.title
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: pc.subtitle
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 12
        }
    }

    // Check mark
    Rectangle {
        id: check
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: previewBox.bottom
        anchors.topMargin: 16
        width: 22
        height: 22
        radius: 11
        color: pc.selected ? pc.accent : "transparent"
        border.width: pc.selected ? 0 : 1.5
        border.color: Qt.rgba(1, 1, 1, 0.25)
        Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
        Canvas {
            anchors.centerIn: parent
            width: 12
            height: 12
            visible: pc.selected
            onPaint: {
                const c = getContext("2d")
                c.reset()
                c.strokeStyle = Theme.Tokens.onAccent.toString()
                c.lineWidth = 2.2
                c.lineCap = "round"
                c.lineJoin = "round"
                c.beginPath()
                c.moveTo(1.5, 6.5)
                c.lineTo(4.8, 9.5)
                c.lineTo(10.5, 2.8)
                c.stroke()
            }
            Component.onCompleted: requestPaint()
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pc.clicked()
    }
}
