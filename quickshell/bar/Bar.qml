import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }

    // Vinduet er høyt nok til at notchen kan vokse ned.
    // exclusiveZone holder bare av plass til selve baren.
    readonly property int notchDrop: 8
    implicitHeight: 260
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

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: ShellState.controlCenterOpen = !ShellState.controlCenterOpen
            }
        }
    }

    // Notch (ligger i Notch.qml)
    Notch {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        baseHeight: Tokens.barHeight + bar.notchDrop
    }
}
