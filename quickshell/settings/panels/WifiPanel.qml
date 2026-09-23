import QtQuick
import "../../services" as Services
import "../../theme" as Theme

Item {
    anchors.fill: parent
	anchors.margins: 20
	Component.onCompleted: Services.NetworkService.scan()

    Column {
        anchors.fill: parent
        spacing: 16

        Text {
            text: "Wifi"
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 20
            font.weight: Font.Medium
        }

        // Wifi toggle row
        Rectangle {
            width: parent.width
            height: 44
            radius: Theme.Tokens.radius
            color: Theme.Tokens.surface

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 14
                text: "Wifi"
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 14
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 14
                width: 36
                height: 20
                radius: 10
                color: Services.NetworkService.wifiEnabled ? Theme.Tokens.accent : Theme.Tokens.border

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: "white"
                    y: 2
                    x: Services.NetworkService.wifiEnabled ? parent.width - width - 2 : 2
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Services.NetworkService.toggleWifi()
                }
            }
        }

        // Current connection
        Text {
            visible: Services.NetworkService.connected
            text: "Connected to " + Services.NetworkService.ssid
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 12
        }

        // Networks list
        Text {
            text: "Nearby networks"
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 11
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: Services.NetworkService.networks
                delegate: Rectangle {
                    width: parent.width
                    height: 36
                    color: "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        text: modelData.ssid
                        color: Theme.Tokens.textPrimary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        text: modelData.signal + "%"
                        color: Theme.Tokens.textSecondary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
