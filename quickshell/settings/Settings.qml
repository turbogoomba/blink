import QtQuick
import Quickshell
import "../theme" as Theme

PanelWindow {
	id: settingsWindow
	visible: false

	implicitWidth: 1320
	implicitHeight: 860

	color: Theme.Tokens.bg

	property string activePanel: "wifi"

	Row {
		anchors.fill: parent

		//Sidebar
		Rectangle {
			width: 120
			height: parent.height
			color: Theme.Tokens.surface

			Column {
				anchors.top: parent.top
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.margins: 8
				spacing: 4

				Repeater {
					model: [
						{ id: "wifi", label: "Wifi" },
						{ id: "bluetooth", label: "Bluetooth" },
						{ id: "sound", label: "Sound" }
					]
					delegate: Rectangle {
						width: parent.width
						height: 32
						radius: Theme.Tokens.radius
						color: modelData.id === settingsWindow.activePanel
							? Theme.Tokens.surfaceAlt
							: "transparent"

						Text {
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 8
							text: modelData.label
							color: modelData.id === settingsWindow.activePanel
								? Theme.Tokens.accent
								: Theme.Tokens.textSecondary
							font.family: Theme.Tokens.fontFamily
							font.pixelSize: 13
						}

						MouseArea {
							anchors.fill: parent
							onClicked: settingsWindow.activePanel = modelData.id
						}
					}
				}
			}
		}
		Rectangle {
			width: parent.width - 120
			height: parent.height
			color: Theme.Tokens.bg

			Loader {
				anchors.fill: parent
				source: settingsWindow.activePanel === "wifi"
					? "panels/WifiPanel.qml"
					: ""
				}
			}
		}
	}

