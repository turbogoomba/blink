pragma Singleton

import QtQuick
import Quickshell
import "../theme"

// Picks the accent color from the wallpaper and writes it to Tokens.accent.
// Turned off in Settings > Display & Dock > Accent color.
Singleton {
    id: root

    readonly property bool enabled: SettingsService.accentFromWallpaper
    readonly property string wallpaper: WallpaperService.current

    ColorQuantizer {
        id: quant
        source: root.enabled && root.wallpaper !== "" ? "file://" + root.wallpaper : ""
        depth: 3            // 2^3 = 8 colors
        rescaleSize: 64     // shrink first, much faster
        onColorsChanged: root.update()
    }

    onEnabledChanged: update()

    // Choose the most colorful, not too dark or bright color, then tune it
    // so white text stays readable on it.
    function update() {
        if (!enabled) {
            Tokens.accent = Tokens.defaultAccent
            return
        }
        const colors = quant.colors ?? []
        let best = null
        let bestScore = 0
        for (const c of colors) {
            const s = c.hslSaturation
            const l = c.hslLightness
            if (l < 0.12 || l > 0.92) continue
            const score = s * (1 - Math.abs(l - 0.5) * 1.4)
            if (score > bestScore) { bestScore = score; best = c }
        }
        if (!best || best.hslSaturation < 0.15) {
            Tokens.accent = Tokens.defaultAccent
            return
        }
        const h = Math.max(0, best.hslHue)
        const s = Math.max(0.45, Math.min(0.7, best.hslSaturation))
        Tokens.accent = Qt.hsla(h, s, 0.6, 1)
    }
}
