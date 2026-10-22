import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../services"

// The minimize effect on one screen (MinimizeService decides when):
//   shrink: a still picture of the window, laid exactly over it, takes its place and is pulled
//           into the dock. It keeps the window's shape, narrows a little ahead of shortening and
//           drops on a curve, so it reads as being sucked in rather than squashed.
//   grow:   the same picture comes back out of the dock to where the window was, then the real
//           window takes over.
// Hyprland's own open/close animation is off for that window meanwhile (no_anim), so only
// this one plays. It only draws; clicks go straight through.
PanelWindow {
    id: fx

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blink-minimize"
    color: "transparent"
    mask: Region {}
    visible: busy

    property bool busy: false
    property var win: null

    // Where the window is (t = 0) and where it ends in the dock (t = 1), in this window's coordinates
    property rect winRect: Qt.rect(0, 0, 0, 0)
    property point dockPoint: Qt.point(0, 0)
    property real t: 0

    readonly property real originX: screen?.x ?? 0
    readonly property real originY: screen?.y ?? 0
    readonly property int endSize: 52          // the longer side, in the dock
    readonly property int shrinkTime: 420
    readonly property int growTime: 380

    function local(r) { return Qt.rect(r.x - originX, r.y - originY, r.width, r.height) }

    // ---------- The shape at t ----------
    readonly property real aspect: winRect.height > 0 ? winRect.width / winRect.height : 1
    readonly property real endW: aspect >= 1 ? endSize : endSize * aspect
    readonly property real endH: aspect >= 1 ? endSize / aspect : endSize
    // Width goes a little ahead of height, the drop comes late: a soft curve into the dock
    readonly property real tw: Math.pow(t, 0.8)
    readonly property real th: Math.pow(t, 1.25)
    readonly property real tx: t
    readonly property real ty: Math.pow(t, 1.6)
    readonly property real curW: winRect.width + (endW - winRect.width) * tw
    readonly property real curH: winRect.height + (endH - winRect.height) * th
    readonly property real curCX: (winRect.x + winRect.width / 2) + (dockPoint.x - winRect.x - winRect.width / 2) * tx
    readonly property real curCY: (winRect.y + winRect.height / 2) + (dockPoint.y - winRect.y - winRect.height / 2) * ty

    Connections {
        target: MinimizeService
        function onShrink(win, screenName, from, to) {
            if (screenName !== (fx.screen?.name ?? "")) return
            fx.startShrink(win, from, to)
        }
        function onGrow(win, screenName, to, from, picture) {
            if (screenName !== (fx.screen?.name ?? "")) return
            fx.startGrow(win, to, from, picture)
        }
    }

    // ---------- Shrink ----------
    function startShrink(w, from, to) {
        anim.stop()
        win = w
        winRect = local(from)
        dockPoint = Qt.point(to.x - originX, to.y - originY)
        t = 0
        still.visible = false
        still.source = ""
        live.captureSource = w.wayland ?? null
        busy = true
        noPicture.restart()
    }

    // The picture is in: keep a copy for the way back, swap it in for the window, pull it in
    function pictureReady() {
        if (!busy || !win || anim.running || still.visible) return
        noPicture.stop()
        const w = win
        const r = winRect
        live.grabToImage(result => {
            MinimizeService.remember(w, Qt.rect(r.x + fx.originX, r.y + fx.originY, r.width, r.height), result)
            still.source = result.url
            still.visible = true
            live.captureSource = null
            MinimizeService.hide(w)
            anim.from = 0
            anim.to = 1
            anim.duration = fx.shrinkTime
            anim.easing.type = Easing.InOutCubic
            anim.start()
        })
    }

    // No picture after a moment (the app did not draw): just hide it
    Timer {
        id: noPicture
        interval: 300
        onTriggered: {
            MinimizeService.hide(fx.win)
            fx.finish()
        }
    }

    // ---------- Grow ----------
    property bool growing: false
    function startGrow(w, to, from, picture) {
        anim.stop()
        win = w
        winRect = local(to)
        dockPoint = Qt.point(from.x - originX, from.y - originY)
        live.captureSource = null
        still.source = picture
        still.visible = true
        t = 1
        busy = true
        growing = true
        anim.from = 1
        anim.to = 0
        anim.duration = fx.growTime
        anim.easing.type = Easing.OutCubic
        anim.start()
    }

    function finish() {
        busy = false
        growing = false
        live.captureSource = null
        still.visible = false
        still.source = ""
        win = null
        t = 0
    }

    // Live view, only to get the first picture of the window. Sits exactly over the window.
    ScreencopyView {
        id: live
        x: fx.winRect.x
        y: fx.winRect.y
        width: fx.winRect.width
        height: fx.winRect.height
        live: false
        visible: fx.busy && !still.visible
        onHasContentChanged: if (hasContent) fx.pictureReady()
    }

    // The picture that moves, with the same round corners as the windows
    ClippingRectangle {
        id: still
        property alias source: stillImage.source
        visible: false
        color: "transparent"
        x: fx.curCX - width / 2
        y: fx.curCY - height / 2
        width: Math.max(1, fx.curW)
        height: Math.max(1, fx.curH)
        radius: Math.min(12, Math.min(width, height) * 0.2)
        // Fades only at the very end, as it reaches the dock
        opacity: fx.t < 0.75 ? 1 : 1 - (fx.t - 0.75) / 0.25 * 0.7

        Image {
            id: stillImage
            anchors.fill: parent
            smooth: true
            mipmap: true
            fillMode: Image.Stretch
        }
    }

    NumberAnimation {
        id: anim
        target: fx
        property: "t"
        onFinished: {
            if (fx.growing) {
                MinimizeService.bringBack(fx.win)
                handOver.restart()
            } else {
                fx.finish()
            }
        }
    }

    // Keep the picture up until the real window has drawn on top of it
    Timer {
        id: handOver
        interval: 160
        onTriggered: fx.finish()
    }
}
