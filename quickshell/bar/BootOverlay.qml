import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

// The startup sequence's own layer: black over the wallpaper, and the accent line
// that traces the inside of the frame from the top middle down both sides.
// Click-through, and only exists while the sequence plays.
Variants {
    model: BootService.cover > 0 || BootService.traceAlpha > 0 ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "boot"

        readonly property int frameT: 6
        readonly property int radius: 14

        // Black over everything inside the frame, fades away to reveal the wallpaper
        Rectangle {
            x: win.frameT
            y: Tokens.barHeight
            width: win.width - 2 * win.frameT
            height: win.height - Tokens.barHeight - win.frameT
            radius: win.radius
            color: "#000000"
            opacity: BootService.cover
        }

        Canvas {
            id: line
            anchors.fill: parent
            opacity: BootService.traceAlpha

            property real progress: BootService.trace
            property var pts: []   // points along one half: [x, y, distance]
            property real half: 0

            onProgressChanged: requestPaint()
            onWidthChanged: build()
            onHeightChanged: build()
            Component.onCompleted: build()

            // Walk the right half of the frame's inner edge, from top middle to bottom middle
            function build() {
                if (width <= 0 || height <= 0) return
                const r = win.radius
                const x0 = win.frameT + 0.75
                const y0 = Tokens.barHeight + 0.75
                const x1 = width - win.frameT - 0.75
                const y1 = height - win.frameT - 0.75
                const cx = width / 2
                const out = []
                const add = (x, y) => {
                    const last = out[out.length - 1]
                    const d = last ? last[2] + Math.hypot(x - last[0], y - last[1]) : 0
                    out.push([x, y, d])
                }
                const arc = (acx, acy, a0, a1) => {
                    for (let i = 1; i <= 12; i++) {
                        const a = a0 + (a1 - a0) * i / 12
                        add(acx + r * Math.cos(a), acy + r * Math.sin(a))
                    }
                }
                add(cx, y0)
                add(x1 - r, y0)
                arc(x1 - r, y0 + r, -Math.PI / 2, 0)
                add(x1, y1 - r)
                arc(x1 - r, y1 - r, 0, Math.PI / 2)
                add(cx, y1)
                pts = out
                half = out[out.length - 1][2]
                requestPaint()
            }

            onPaint: {
                const c = getContext("2d")
                c.reset()
                if (pts.length < 2 || progress <= 0) return
                const L = progress * half
                const cx = width / 2
                c.strokeStyle = Tokens.accent.toString()
                c.lineWidth = 1.5
                c.lineCap = "round"
                c.lineJoin = "round"
                // Right half, then the mirrored left half
                for (const mirror of [false, true]) {
                    c.beginPath()
                    const X = x => mirror ? 2 * cx - x : x
                    c.moveTo(X(pts[0][0]), pts[0][1])
                    for (let i = 1; i < pts.length; i++) {
                        const p = pts[i]
                        if (p[2] <= L) {
                            c.lineTo(X(p[0]), p[1])
                        } else {
                            const q = pts[i - 1]
                            const t = (L - q[2]) / (p[2] - q[2])
                            c.lineTo(X(q[0] + (p[0] - q[0]) * t), q[1] + (p[1] - q[1]) * t)
                            break
                        }
                    }
                    c.stroke()
                }
            }
        }
    }
}
