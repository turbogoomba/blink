import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }

    // Plass til at notchen stikker ned under baren
    readonly property int notchDrop: 8
    implicitHeight: Tokens.barHeight + notchDrop
    exclusiveZone: Tokens.barHeight
    color: "transparent"

    // Bare baren og notchen fanger musen
    mask: Region {
        item: barRect
        Region { item: notch }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Selve baren
    Rectangle {
        id: barRect
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Tokens.barHeight
        color: Tokens.barBg

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 3
            text: ToplevelManager.activeToplevel?.title ?? ""
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd d. MMM  HH:mm")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    // Notch
    Rectangle {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: 200
        height: Tokens.barHeight + bar.notchDrop
        radius: 10
        color: Tokens.barBg
    }
}
