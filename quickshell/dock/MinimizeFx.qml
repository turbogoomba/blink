import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../services"

// The minimize effect on one screen (MinimizeService decides when):
//   shrink: a still picture of the window, laid exactly over it, takes its place and is
//           pulled into the dock, narrowing faster than it shortens, like a Mac's "scale" effect
//   grow:   the same picture comes back out of the dock to where the window was,
//           then the real window takes over
// It only draws; clicks go straight through.
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
    property rect winRect: Qt.rect(0, 0, 0, 0)
    property point dockPoint: Qt.point(0, 0)

    readonly property real originX: screen?.x ?? 0
    readonly property real originY: screen?.y ?? 0
    readonly property int endSize: 40
    readonly property int duration: 380

    function local(r) { return Qt.rect(r.x - originX, r.y - originY, r.width, r.height) }

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
        shrinkAnim.stop(); growAnim.stop()
        win = w
        winRect = local(from)
        dockPoint = Qt.point(to.x - originX, to.y - originY)
        still.source = ""
        place(live, winRect, 1)
        live.captureSource = w.wayland ?? null
        busy = true
        noPicture.restart()
    }

    // The picture is in: keep a copy for the way back, swap it in for the window, pull it in
    function pictureReady() {
        if (!busy || !win || shrinkAnim.running) return
        noPicture.stop()
        const w = win
        const r = winRect
        live.grabToImage(result => {
            MinimizeService.remember(w, Qt.rect(r.x + fx.originX, r.y + fx.originY, r.width, r.height), result)
            still.source = result.url
            place(still, r, 1)
            live.captureSource = null
            MinimizeService.hide(w)
            shrinkAnim.start()
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
    function startGrow(w, to, from, picture) {
        shrinkAnim.stop(); growAnim.stop()
        win = w
        winRect = local(to)
        dockPoint = Qt.point(from.x - originX, from.y - originY)
        live.captureSource = null
        place(live, winRect, 0)
        still.source = picture
        placeAtDock(still)
        busy = true
        growAnim.start()
    }

    // ---------- Pieces ----------
    function place(item, r, op) {
        item.x = r.x; item.y = r.y; item.width = r.width; item.height = r.height
        item.opacity = op
    }
    function placeAtDock(item) {
        item.x = dockPoint.x - endSize / 2
        item.y = dockPoint.y - endSize / 2
        item.width = endSize
        item.height = endSize
        item.opacity = 0.4
    }
    function finish() {
        busy = false
        live.captureSource = null
        still.source = ""
        win = null
    }

    // Live view, only to get the first picture of the window
    ScreencopyView {
        id: live
        live: false
        opacity: 1
        onHasContentChanged: if (hasContent) fx.pictureReady()
    }

    // The picture that moves, with the same round corners as the windows
    ClippingRectangle {
        id: still
        property alias source: stillImage.source
        color: "transparent"
        radius: 12 * Math.min(1, width / 240)

        Image {
            id: stillImage
            anchors.fill: parent
            smooth: true
            mipmap: true
            fillMode: Image.Stretch
        }
    }

    ParallelAnimation {
        id: shrinkAnim
        // Narrows quickly, drops a little slower: reads as being sucked in
        NumberAnimation { target: still; property: "width";  to: fx.endSize; duration: fx.duration; easing.type: Easing.InOutCubic }
        NumberAnimation { target: still; property: "x";      to: fx.dockPoint.x - fx.endSize / 2; duration: fx.duration; easing.type: Easing.InOutCubic }
        NumberAnimation { target: still; property: "height"; to: fx.endSize; duration: fx.duration; easing.type: Easing.InQuart }
        NumberAnimation { target: still; property: "y";      to: fx.dockPoint.y - fx.endSize / 2; duration: fx.duration; easing.type: Easing.InQuart }
        NumberAnimation { target: still; property: "opacity"; to: 0.4; duration: fx.duration; easing.type: Easing.InQuad }
        onFinished: fx.finish()
    }

    ParallelAnimation {
        id: growAnim
        NumberAnimation { target: still; property: "width";  to: fx.winRect.width;  duration: fx.duration; easing.type: Easing.OutQuart }
        NumberAnimation { target: still; property: "x";      to: fx.winRect.x;      duration: fx.duration; easing.type: Easing.OutQuart }
        NumberAnimation { target: still; property: "height"; to: fx.winRect.height; duration: fx.duration; easing.type: Easing.OutCubic }
        NumberAnimation { target: still; property: "y";      to: fx.winRect.y;      duration: fx.duration; easing.type: Easing.OutCubic }
        NumberAnimation { target: still; property: "opacity"; to: 1; duration: fx.duration * 0.6; easing.type: Easing.OutQuad }
        onFinished: {
            MinimizeService.bringBack(fx.win)
            handOver.restart()
        }
    }

    // Keep the picture up until the real window has drawn on top of it
    Timer {
        id: handOver
        interval: 140
        onTriggered: fx.finish()
    }
}
