import QtQuick
import QtQuick.Effects

// A one-color (symbolic) icon in the theme's text color.
// The icon files are white, which disappears on light themes, so there it is
// recolored to `tint`. On dark themes the white file is used as it is.
//   TintIcon { source: Quickshell.iconPath("bluetooth"); width: 18; height: 18 }
//   TintIcon { ...; tint: selected ? "white" : Tokens.textPrimary }
// Set `tinted: false` for colored pictures (app icons, album art).
Image {
    id: ti
    property color tint: Tokens.textPrimary
    property bool tinted: true

    sourceSize: Qt.size(width * 2, height * 2)
    layer.enabled: tinted && Tokens.light
    layer.effect: MultiEffect {
        colorization: 1.0
        colorizationColor: ti.tint
    }
}
