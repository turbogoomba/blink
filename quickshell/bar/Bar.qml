import Quickshell.Wayland
import QtQuick
import Quickshell
import "../theme"

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: Tokens.barHeight
    color: Tokens.barBg

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
	}

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: ToplevelManager.activeToplevel?.title ?? ""
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: 13
        font.weight: Font.Bold
        elide: Text.ElideRight
        width: parent.width / 3
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
