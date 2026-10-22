pragma Singleton

import QtQuick
import Quickshell

// Design tokens for the whole shell. Use these instead of raw numbers,
// so radii, spacing, fonts and motion stay the same everywhere.
Singleton {
	// ---------- Colors ----------
	readonly property int barHeight: 40
	// The black frame around the screen
	readonly property int frameT: 16
	// Shadow under the bar, frame and sheets, so they float over the wallpaper
	// Soft shadows on light themes (dark ones need a strong shadow to show at all)
	readonly property color shadowColor: light ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0, 0, 0, 0.75)
	readonly property real shadowBlur: 1.0
	// Text and icons in the top bar
	readonly property int barFont: 14
	readonly property int barIcon: 18

	// ---------- Themes ----------
	// Set from Settings > Appearance (SettingsService.theme writes it here).
	property string themeName: "blink"
	readonly property var themes: ({
		blink:  { name: "Blink",  sub: "Black, accent from the wallpaper", light: false,
		          frame: "#000000", window: "#1c1c1e", sidebar: "#111113", card: "#1e1e21", surface: "#2c2c2e", surfaceAlt: "#242426",
		          border: "#3a3a3c", text: "#e5e5e7", text2: "#98989d", accent: "#5fa8d3", onAccent: "#d9000000", wall: "#3b3858" },
		// macOS light: white windows, light grey sidebars and bar, Apple's greys and blue
		daylight: { name: "Daylight", sub: "Bright and crisp, like macOS in light mode", light: true,
		          frame: "#ececf0", window: "#ffffff", sidebar: "#f2f2f5", card: "#ffffff", surface: "#f5f5f7", surfaceAlt: "#f0f0f3",
		          border: "#d2d2d7", text: "#1d1d1f", text2: "#6e6e73", accent: "#007aff", onAccent: "#ffffff", wall: "#c9d6e8" },
		paper:  { name: "Paper",  sub: "Soft light grey, easy on the eyes", light: true,
		          frame: "#d3d3d9", window: "#e3e3e8", sidebar: "#d9d9df", card: "#ececf0", surface: "#f1f1f4", surfaceAlt: "#e7e7ec",
		          border: "#c2c2ca", text: "#1c1c1e", text2: "#5c5c64", accent: "#2f6fd6", onAccent: "#ffffff", wall: "#b4c1d4" },
		fjord:  { name: "Fjord",  sub: "Cold blue-grey", light: false,
		          frame: "#1f2430", window: "#262c39", sidebar: "#1f2430", card: "#2e3545", surface: "#343c4d", surfaceAlt: "#2a3140",
		          border: "#434c5e", text: "#e5e9f0", text2: "#9aa5b8", accent: "#88c0d0", onAccent: "#d9000000", wall: "#3b4a5e" },
		dusk:   { name: "Dusk",   sub: "Purple evening, rose accent", light: false,
		          frame: "#15121f", window: "#1c1729", sidebar: "#15121f", card: "#231d35", surface: "#2a2440", surfaceAlt: "#1f1a2e",
		          border: "#3e3756", text: "#e0def4", text2: "#a19cb8", accent: "#eb9fb8", onAccent: "#d9000000", wall: "#3a2f52" },
		forest: { name: "Forest", sub: "Deep green, sage accent", light: false,
		          frame: "#0f1612", window: "#151e18", sidebar: "#0f1612", card: "#1b261f", surface: "#223028", surfaceAlt: "#18221c",
		          border: "#33463a", text: "#dfe8e1", text2: "#94a89a", accent: "#8fc79a", onAccent: "#d9000000", wall: "#2c3f33" },
		ember:  { name: "Ember",  sub: "Warm dark, orange accent", light: false,
		          frame: "#120d0b", window: "#19120f", sidebar: "#120d0b", card: "#221a16", surface: "#2a201b", surfaceAlt: "#1d1613",
		          border: "#46352e", text: "#f0e6df", text2: "#a8968c", accent: "#ff8a3d", onAccent: "#d9000000", wall: "#4a2c20" }
	})
	readonly property var themeOrder: ["blink", "daylight", "paper", "fjord", "dusk", "forest", "ember"]
	readonly property var t: themes[themeName] ?? themes.blink
	readonly property bool light: t.light

	// The bar, the frame and every sheet that grows out of them
	readonly property color barBg: t.frame
	readonly property color bg: t.window
	readonly property color surface: t.surface
	readonly property color surfaceAlt: t.surfaceAlt
	readonly property color border: t.border
	readonly property color textPrimary: t.text
	readonly property color textSecondary: t.text2
	// App windows (Settings)
	readonly property color windowBg: t.window
	readonly property color sidebarBg: t.sidebar
	// Cards inside windows and sheets
	readonly property color cardBg: t.card
	// Accent: the theme's, or picked from the wallpaper by AccentService
	readonly property color defaultAccent: t.accent
	property color accent: defaultAccent

	// A see-through tint that works on the theme: white on dark, black on light
	function ink(a) { return light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a) }

	// Status colors
	readonly property color red: "#ff453a"
	readonly property color green: "#30d158"
	readonly property color orange: "#ff9f0a"
	readonly property color yellow: "#ffd60a"

	// ---------- Interaction ----------
	// White fills on dark surfaces: resting, hovered, strong (pressed or highlighted)
	readonly property color fillIdle: ink(0.07)
	readonly property color fillHover: ink(0.12)
	readonly property color fillStrong: ink(0.20)
	// Scale while pressed: normal controls, small icon targets
	// Thin lines between rows, and text that sits on the accent color
	readonly property color divider: ink(0.08)
	readonly property color onAccent: t.onAccent
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
	readonly property string fontFamily: "Inter"
	readonly property int fontSmall: 11   // captions, secondary lines
	readonly property int fontBody: 13    // normal text
	readonly property int fontTitle: 15   // headings
	readonly property int fontLarge: 22   // big numbers, clocks

	// ---------- Motion ----------
	readonly property int durFast: 120    // hover, press
	readonly property int durNormal: 200  // most changes
	readonly property int durSlow: 320    // morphs (the notch changing shape)
	readonly property int durOpen: 440    // sheets and menus growing out of the frame
	readonly property int durClose: 240   // ... and going back in (closing is quicker)
	readonly property bool menuShadow: false
	readonly property bool frameShadow: false
	readonly property int contentDelay: 180
	readonly property int contentIn: 260
	readonly property int contentOut: 90
	readonly property int easeMove: Easing.OutCubic   // fades and movement
	readonly property int easeGrow: Easing.OutBack    // things growing out of the frame/notch, press bounce
	readonly property int easeShrink: Easing.InCubic  // things closing
	// How far things overshoot when they open (with easeGrow). 0 = none, 1.7 = Qt's default
	readonly property real bounce: 1.3
}
