import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

Rectangle {
    id: tile
    property string icon: ""
    property string fallbackIcon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 56
    radius: 14
    color: Tokens.surface

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: 18
            color: tile.active ? Tokens.accent : Tokens.border

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                sourceSize: Qt.size(36, 36)
                source: Quickshell.iconPath(tile.icon, tile.fallbackIcon)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: tile.title
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: tile.subtitle
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: tile.clicked()
    }
}
