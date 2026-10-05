import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Drawer on the side of the screen (opposite the dock).
// Move the mouse to the middle of that edge: the frame bulges out a little handle.
// Stay there a moment (or click) and the drawer slides out: system graphs, favorite apps, folders.
PanelWindow {
    id: drawer

    readonly property string side: SettingsService.drawerSide
    readonly property bool onLeft: side === "left"
    readonly property int frameT: 6
    readonly property int sheetW: 310

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: drawer.onLeft; right: !drawer.onLeft }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: sheetW + 40
    color: "transparent"
    visible: SettingsService.drawerEnabled && !ShellState.gameMode

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "drawer"

    property bool handleShown: false
    property bool open: false

    // Handle and drawer movement
    property real handleReveal: handleShown || open ? 1 : 0
    Behavior on handleReveal { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        id: openBehavior   // targetValue = where it is going, read before the animation starts
        NumberAnimation {
            duration: openBehavior.targetValue > 0.5 ? 420 : 240
            easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: Tokens.bounce
        }
    }

    // Measure GPU, temperatures and network only while the drawer is out
    onOpenChanged: SystemService.detailed = open

    // Explicit numbers instead of `item:` so the mask follows the window's real size
    readonly property Item maskItem: open ? sheetHover : triggerZone
    mask: Region {
        x: drawer.maskItem.x
        y: drawer.maskItem.y
        width: drawer.maskItem.width
        height: drawer.maskItem.height
        // While closed, the whole edge also accepts a dragged folder
        Region {
            x: dragEdge.x
            y: dragEdge.y
            width: drawer.open ? 0 : dragEdge.width
            height: dragEdge.height
        }
    }

    // True while a file or folder is dragged over the drawer
    readonly property bool dragging: dropZone.containsDrag || edgeDrop.containsDrag
    onDraggingChanged: updateClose()

    // Stay on the handle for a moment to open
    Timer {
        id: openTimer
        interval: 320
        onTriggered: drawer.open = true
    }

    function updateClose() {
        if (zoneHover.hovered || sheetOwnHover.hovered || dragging) closeTimer.stop()
        else if (drawer.open) closeTimer.restart()
    }

    // Leave the drawer and it slides back in
    Timer {
        id: closeTimer
        // Never closes while something is dragged over it
        interval: 450
        onTriggered: if (!drawer.dragging) drawer.open = false
    }

    // Concave corner pieces (where the drawer or handle meets the frame)
    component Fillet: Canvas {
        property bool below: false
        property real r: 14
        width: r
        height: r
        onRChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, r, r)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            const cx = drawer.onLeft ? r : 0
            const cy = below ? r : 0
            c.arc(cx, cy, r, 0, Math.PI * 2)
            c.fill()
        }
    }

    // The little handle that bulges out of the frame
    Item {
        id: handle
        readonly property real w: 12 * drawer.handleReveal * (1 - drawer.reveal)
        width: w
        height: 84
        x: drawer.onLeft ? drawer.frameT : drawer.width - drawer.frameT - w
        y: (drawer.height - height) / 2
        visible: w > 0.5

        Rectangle {
            x: drawer.onLeft ? -10 : 0
            width: parent.width + 10
            height: parent.height
            radius: Tokens.radiusMd
            color: Tokens.barBg
        }
        Rectangle {
            anchors.centerIn: parent
            width: 3
            height: 30
            radius: 1.5
            color: Tokens.accent
            opacity: drawer.handleReveal
        }
    }
    Fillet {
        r: 8
        visible: handle.visible
        x: drawer.onLeft ? drawer.frameT : drawer.width - drawer.frameT - 8
        y: handle.y - 8
        opacity: drawer.handleReveal * (1 - drawer.reveal)
    }
    Fillet {
        r: 8
        below: true
        visible: handle.visible
        x: drawer.onLeft ? drawer.frameT : drawer.width - drawer.frameT - 8
        y: handle.y + handle.height
        opacity: drawer.handleReveal * (1 - drawer.reveal)
    }

    // ---------- The drawer ----------
    Fillet {
        x: drawer.onLeft ? drawer.frameT : drawer.width - drawer.frameT - 14
        y: sheet.y - 14
        opacity: Math.min(1, drawer.reveal * 4)
        visible: drawer.reveal > 0.01
    }
    Fillet {
        below: true
        x: drawer.onLeft ? drawer.frameT : drawer.width - drawer.frameT - 14
        y: sheet.y + sheet.height
        opacity: Math.min(1, drawer.reveal * 4)
        visible: drawer.reveal > 0.01
    }

    // Keeps the drawer open while the mouse is on it (a bit wider than the sheet)
    Item {
        id: sheetHover
        x: drawer.onLeft ? 0 : drawer.width - drawer.sheetW - drawer.frameT - 20
        y: sheet.y - 20
        width: drawer.sheetW + drawer.frameT + 20
        height: sheet.height + 40

        HoverHandler {
            id: zoneHover
            onHoveredChanged: drawer.updateClose()
        }

        // Accept dropped folders anywhere on the drawer
        DropArea {
            id: dropZone
            anchors.fill: parent
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => {
                for (const u of drop.urls) SettingsService.addFolder(u)
                drop.accept(Qt.CopyAction)
            }
        }
    }

    Item {
        id: sheet
        readonly property real shownW: drawer.sheetW * Math.max(0, drawer.reveal)
        width: shownW
        height: Math.min(drawer.height - 120, body.implicitHeight + 36)
        x: drawer.onLeft ? drawer.frameT : drawer.width - drawer.frameT - shownW
        y: (drawer.height - height) / 2
        clip: true
        visible: drawer.reveal > 0.01

        // The contents sit on top of sheetHover, so the sheet tracks hover itself too
        HoverHandler {
            id: sheetOwnHover
            onHoveredChanged: drawer.updateClose()
        }

        // Round only on the screen side
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusXl
            color: Tokens.barBg
        }
        Rectangle {
            x: drawer.onLeft ? 0 : parent.width / 2
            width: parent.width / 2
            height: parent.height
            color: Tokens.barBg
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: Tokens.spaceLg
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            DrawerContent {
                id: body
                dropActive: drawer.dragging
                // Fixed width so it does not reflow while sliding out
                width: drawer.sheetW - 32
                x: drawer.onLeft ? (sheet.width - drawer.sheetW) : 0
                opacity: Math.max(0, Math.min(1, (drawer.reveal - 0.3) / 0.5))
            }
        }
    }


    // Drag a folder to the edge (anywhere along it) and the drawer opens
    Item {
        id: dragEdge
        x: drawer.onLeft ? 0 : drawer.width - width
        width: 6
        height: drawer.height
        enabled: !drawer.open
        DropArea {
            id: edgeDrop
            anchors.fill: parent
            onEntered: drag => {
                drag.accepted = drag.hasUrls
                if (drag.hasUrls) drawer.open = true
            }
        }
    }

    // ---------- Edge trigger + handle ----------
    Item {
        id: triggerZone
        x: drawer.onLeft ? 0 : drawer.width - 14
        y: (drawer.height - height) / 2
        width: 14
        height: 140
        // Off while open, so it does not steal hover from the drawer
        enabled: !drawer.open

        HoverHandler {
            id: triggerHover
            onHoveredChanged: {
                drawer.handleShown = hovered
                if (hovered) openTimer.restart()
                else openTimer.stop()
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: drawer.open = true
        }
    }
}
