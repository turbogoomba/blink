pragma Singleton

import QtQuick
import Quickshell

// Design tokens for the whole shell. Use these instead of raw numbers,
// so radii, spacing, fonts and motion stay the same everywhere.
Singleton {
	// ---------- Colors ----------
	readonly property int barHeight: 28
	readonly property color barBg: "#000000"
	readonly property color bg: "#1c1c1e"
	readonly property color surface: "#2c2c2e"
	readonly property color surfaceAlt: "#242426"
	readonly property color border: "#3a3a3c"
	readonly property color textPrimary: "#e5e5e7"
	readonly property color textSecondary: "#98989d"
	// Accent: picked from the wallpaper by AccentService (falls back to the blue)
	readonly property color defaultAccent: "#5fa8d3"
	property color accent: defaultAccent

	// Status colors
	readonly property color red: "#ff453a"
	readonly property color green: "#30d158"
	readonly property color orange: "#ff9f0a"
	readonly property color yellow: "#ffd60a"

	// ---------- Interaction ----------
	// White fills on dark surfaces: resting, hovered, strong (pressed or highlighted)
	readonly property color fillIdle: Qt.rgba(1, 1, 1, 0.07)
	readonly property color fillHover: Qt.rgba(1, 1, 1, 0.12)
	readonly property color fillStrong: Qt.rgba(1, 1, 1, 0.20)
	// Scale while pressed: normal controls, small icon targets
	readonly property real pressScale: 0.96
	readonly property real pressScaleIcon: 0.88

	// ---------- Radius ----------
	readonly property int radiusSm: 6     // small buttons, chips
	readonly property int radiusMd: 10    // rows, cards inside panels
	readonly property int radiusLg: 14    // panels, big cards
	readonly property int radiusXl: 20    // large sheets
	readonly property int radius: radiusMd // old name, kept for compatibility

	// ---------- Spacing ----------
	readonly property int spaceXs: 4
	readonly property int spaceSm: 8
	readonly property int spaceMd: 12
	readonly property int spaceLg: 16
	readonly property int spaceXl: 20
	readonly property int spacing: spaceMd // old name, kept for compatibility

	// ---------- Font ----------
	readonly property string fontFamily: "IBM Plex Sans"
	readonly property int fontSmall: 11   // captions, secondary lines
	readonly property int fontBody: 13    // normal text
	readonly property int fontTitle: 15   // headings
	readonly property int fontLarge: 22   // big numbers, clocks

	// ---------- Motion ----------
	readonly property int durFast: 120    // hover, press
	readonly property int durNormal: 200  // most changes
	readonly property int durSlow: 320    // panels opening and closing
	readonly property int easeMove: Easing.OutCubic   // fades and movement
	readonly property int easeGrow: Easing.OutBack    // things growing out of the frame/notch, press bounce
	readonly property int easeShrink: Easing.InCubic  // things closing
}
