pragma Singleton

import QtQuick
import Quickshell

Singleton {
	//Colors
	readonly property int barHeight: 28
	readonly property color barBg: Qt.rgba(0.11, 0.11, 0.12, 0.75)
	readonly property color bg: "#1c1c1e"
	readonly property color surface: "#2c2c2e"
	readonly property color surfaceAlt: "#242426"
	readonly property color border: "#3a3a3c"
	readonly property color textPrimary: "#e5e5e7"
	readonly property color textSecondary: "#98989d"
	readonly property color accent: "#5fa8d3"

	//Spacing
	readonly property int radius: 8
	readonly property int spacing: 12

	//Font
	readonly property string fontFamily: "IBM Plex Sans"
}
