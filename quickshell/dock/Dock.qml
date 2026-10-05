import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// The dock: black, part of the frame, at the bottom, left or right (Settings > Display & Dock).
// Hidden inside the frame until the mouse touches the edge. Right-click an icon for options.
PanelWindow {
    id: dock

    readonly property string side: SettingsService.dockPosition
    readonly property bool horizontal: side === "bottom"
    readonly property int frameT: 6

    anchors {
        bottom: true
        top: !dock.horizontal
        left: dock.side !== "right"
        right: dock.side !== "left"
    }
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: horizontal ? 360 : 0
    implicitWidth: horizontal ? 0 : 360
    color: "transparent"
    visible: !ShellState.focusMode

    property int size: SettingsService.dockSize
    property bool revealed: false

    // Grows out of the frame with a small bounce, tucks back quickly
    property real reveal: revealed ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: dock.revealed ? 380 : 220
            easing.type: dock.revealed ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: 0.8
        }
    }

    // Window list (several windows) and right-click menu
    property string menuAppId: ""
    property var contextItem: null      // { id, entry, pinned }
    property point popupAt: Qt.point(0, 0)

    // Where the mouse is along the icon row (-1 = not over it), for magnification
    readonly property real hoverPos: rowHover.hovered
        ? (horizontal ? rowHover.point.position.x : rowHover.point.position.y) : -1

    // Input mask. Explicit numbers instead of `item:` so it follows the window
    // when the compositor gives it its real size after startup.
    readonly property Item maskItem: revealed ? hoverZone : trigger
    mask: Region {
        x: dock.maskItem.x
        y: dock.maskItem.y
        width: dock.maskItem.width
        height: dock.maskItem.height
        Region { x: windowMenu.x; y: windowMenu.y; width: windowMenu.width; height: windowMenu.height }
        Region { x: contextMenu.x; y: contextMenu.y; width: contextMenu.width; height: contextMenu.height }
    }

    // ---------- Apps ----------
    function findEntry(id) {
        if (!id) return null
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)
    }

    // Does this window belong to this dock id?
    function matches(id, appId) {
        if (!id || !appId) return false
        const a = appId.toLowerCase()
        if (id.toLowerCase() === a) return true
        const e = findEntry(id)
        return (e?.startupClass ?? "").toLowerCase() === a || (e?.id ?? "").toLowerCase() === a
    }

    function windowsFor(id) {
        return Hyprland.toplevels.values.filter(t => matches(id, t.wayland?.appId))
    }

    // Running apps that are not pinned
    readonly property var runningApps: {
        const pinned = SettingsService.dockApps
        const ids = []
        for (const t of Hyprland.toplevels.values) {
            const appId = t.wayland?.appId
            if (!appId || appId === "org.quickshell") continue
            if (pinned.some(p => matches(p, appId))) continue
            const key = findEntry(appId)?.id ?? appId
            if (!ids.includes(key)) ids.push(key)
        }
        return ids
    }

    function addr(t) {
        const a = t.address
        return a.startsWith("0x") ? a : "0x" + a
    }
    function isMinimized(t) {
        return t.workspace?.name === "special:minimized"
    }

    function showWindow(w) {
        if (isMinimized(w)) {
            const ws = Hyprland.focusedWorkspace?.id ?? 1
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${ws}", window = "address:${addr(w)}" })`)
        } else {
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(w)}" })`)
        }
    }

    // Point next to an icon where popups open (above it, or beside it on the sides)
    function popupPoint(iconItem) {
        if (horizontal) return iconItem.mapToItem(null, iconItem.width / 2, 0)
        if (side === "left") return iconItem.mapToItem(null, iconItem.width, iconItem.height / 2)
        return iconItem.mapToItem(null, 0, iconItem.height / 2)
    }

    function appClicked(id, entry, iconItem) {
        contextItem = null
        const wins = windowsFor(id)

        // Not running: start it and bounce
        if (wins.length === 0) {
            entry?.execute()
            iconItem.bounce()
            return
        }
        // Several windows: show the list
        if (wins.length > 1) {
            if (menuAppId === id) {
                menuAppId = ""
            } else {
                popupAt = popupPoint(iconItem)
                menuAppId = id
            }
            return
        }
        showWindow(wins[0])
    }

    function openContext(id, entry, iconItem) {
        menuAppId = ""
        popupAt = popupPoint(iconItem)
        contextItem = { id: entry?.id ?? id, entry: entry, pinned: SettingsService.isPinned(id), rawId: id }
    }

    function updateHover() {
        if (dockHover.hovered || bodyHover.hovered || menuHover.hovered || contextHover.hovered) hideTimer.stop()
        else hideTimer.restart()
    }

    // Startup: the dock pops up for a moment
    Connections {
        target: BootService
        function onDockPeekChanged() {
            if (BootService.dockPeek) dock.revealed = true
            else dock.updateHover()
        }
    }

    Timer {
        id: hideTimer
        interval: 450
        onTriggered: {
            dock.menuAppId = ""
            dock.contextItem = null
            dock.revealed = false
        }
    }

    // ---------- One icon ----------
    component DockIcon: Item {
        id: icon
        property string source: ""
        property string label: ""
        property bool running: false
        property bool dimmed: false
        signal clicked()
        signal rightClicked()

        // Magnification: the closer the mouse, the bigger (max 1.35)
        readonly property real mag: {
            if (dock.hoverPos < 0) return 1
            const c = dock.horizontal ? icon.x + icon.width / 2 : icon.y + icon.height / 2
            return 1 + 0.35 * Math.max(0, 1 - Math.abs(dock.hoverPos - c) / 110)
        }

        // Bounce like on a Mac: keeps hopping until the app's window shows up (max 8 s)
        property bool launching: false
        function bounce() {
            launching = true
            launchTimeout.restart()
            if (!bounceAnim.running) bounceAnim.start()
        }
        function stopBounce() { launching = false }

        Timer {
            id: launchTimeout
            interval: 8000
            onTriggered: icon.launching = false
        }

        width: dock.size
        height: dock.size

        // Which way is "away from the edge"
        readonly property real outX: dock.side === "left" ? 1 : dock.side === "right" ? -1 : 0
        readonly property real outY: dock.horizontal ? -1 : 0
        property real hop: 0

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: dock.size - 8
            height: dock.size - 8
            sourceSize: Qt.size(96, 96)
            source: icon.source
            transformOrigin: dock.side === "left" ? Item.Left : dock.side === "right" ? Item.Right : Item.Bottom
            scale: icon.mag
            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
            transform: Translate { x: icon.hop * icon.outX; y: icon.hop * icon.outY }
        }

        SequentialAnimation {
            id: bounceAnim
            NumberAnimation { target: icon; property: "hop"; to: 18; duration: Tokens.durNormal; easing.type: Tokens.easeMove }
            NumberAnimation { target: icon; property: "hop"; to: 0; duration: Tokens.durNormal; easing.type: Tokens.easeShrink }
            onFinished: {
                if (icon.launching) bounceAnim.start()
                else settleAnim.start()
            }
        }
        SequentialAnimation {
            id: settleAnim
            NumberAnimation { target: icon; property: "hop"; to: 6; duration: Tokens.durFast; easing.type: Tokens.easeMove }
            NumberAnimation { target: icon; property: "hop"; to: 0; duration: Tokens.durFast; easing.type: Tokens.easeShrink }
        }

        // New icons pop in
        scale: 0.4
        opacity: 0
        Component.onCompleted: popIn.start()
        ParallelAnimation {
            id: popIn
            NumberAnimation { target: icon; property: "scale"; to: 1; duration: Tokens.durSlow; easing.type: Tokens.easeGrow }
            NumberAnimation { target: icon; property: "opacity"; to: 1; duration: Tokens.durNormal }
        }

        // Name label, away from the edge
        Rectangle {
            readonly property real gap: 18 + (icon.mag - 1) * 40
            x: dock.horizontal ? (parent.width - width) / 2
             : dock.side === "left" ? parent.width + gap : -width - gap
            y: dock.horizontal ? -height - gap : (parent.height - height) / 2
            width: labelText.implicitWidth + 16
            height: 24
            radius: Tokens.radiusSm
            color: Tokens.surface
            border.color: Tokens.border
            border.width: 1
            visible: iconMouse.containsMouse && icon.label !== "" && !dock.contextItem

            Text {
                id: labelText
                anchors.centerIn: parent
                text: icon.label
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
            }
        }

        // Dot: white = running, grey = only minimized. Sits on the edge side.
        Rectangle {
            x: dock.horizontal ? (parent.width - width) / 2
             : dock.side === "left" ? -6 : parent.width + 2
            y: dock.horizontal ? parent.height + 2 : (parent.height - height) / 2
            width: 4
            height: 4
            radius: 2
            color: icon.dimmed ? Tokens.textSecondary : Tokens.textPrimary
            visible: icon.running
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) icon.rightClicked()
                else icon.clicked()
            }
        }
    }

    component AppIcon: DockIcon {
        id: appIcon
        required property string modelData
        readonly property var entry: dock.findEntry(modelData)
        readonly property var wins: dock.windowsFor(modelData)

        source: Quickshell.iconPath(entry?.icon ?? modelData.toLowerCase(), "application-x-executable")
        label: entry?.name ?? modelData
        running: wins.length > 0
        onRunningChanged: if (running) appIcon.stopBounce()
        dimmed: running && wins.every(w => dock.isMinimized(w))
        onClicked: dock.appClicked(modelData, entry, appIcon)
        onRightClicked: dock.openContext(modelData, entry, appIcon)
    }

    // ---------- Popups (window list, right-click menu) ----------
    component PopupBox: Rectangle {
        radius: Tokens.radiusMd
        color: Tokens.bg
        border.color: Tokens.border
        border.width: 1
        // Away from the edge, next to the icon
        x: dock.horizontal ? Math.max(8, Math.min(dock.width - width - 8, dock.popupAt.x - width / 2))
         : dock.side === "left" ? dock.popupAt.x + 14 : dock.popupAt.x - width - 14
        y: dock.horizontal ? dock.popupAt.y - height - 14
         : Math.max(8, Math.min(dock.height - height - 8, dock.popupAt.y - height / 2))
    }

    component MenuRow: Rectangle {
        id: mr
        scale: mrMouse.pressed ? Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
        property string text: ""
        property bool danger: false
        signal activated()
        width: parent ? parent.width : 0
        height: 30
        radius: Tokens.radiusSm
        color: mrMouse.containsMouse ? Tokens.accent : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: mr.text
            color: mrMouse.containsMouse ? "white" : mr.danger ? "#ff8a83" : Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontBody
        }

        MouseArea {
            id: mrMouse
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            hoverEnabled: true
            onClicked: mr.activated()
        }
    }

    PopupBox {
        id: windowMenu
        readonly property bool open: dock.menuAppId !== ""
        readonly property var wins: open ? dock.windowsFor(dock.menuAppId) : []
        width: open ? 260 : 0
        height: open ? menuColumn.implicitHeight + 12 : 0
        visible: open

        HoverHandler {
            id: menuHover
            onHoveredChanged: dock.updateHover()
        }

        Column {
            id: menuColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 2

            Repeater {
                model: windowMenu.wins

                MenuRow {
                    required property var modelData
                    text: (modelData.title || "Untitled") + (dock.isMinimized(modelData) ? "  (minimized)" : "")
                    onActivated: {
                        dock.showWindow(modelData)
                        dock.menuAppId = ""
                    }
                }
            }
        }
    }

    PopupBox {
        id: contextMenu
        readonly property bool open: dock.contextItem !== null
        readonly property var item: dock.contextItem
        width: open ? 220 : 0
        height: open ? ctxColumn.implicitHeight + 12 : 0
        visible: open

        HoverHandler {
            id: contextHover
            onHoveredChanged: dock.updateHover()
        }

        Column {
            id: ctxColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 2

            Text {
                leftPadding: 10
                topPadding: 4
                bottomPadding: 4
                text: contextMenu.item?.entry?.name ?? contextMenu.item?.id ?? ""
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
            }

            MenuRow {
                text: contextMenu.item?.pinned ? "Keep in Dock  ✓" : "Keep in Dock"
                onActivated: {
                    const it = contextMenu.item
                    if (it.pinned) SettingsService.unpin(it.rawId)
                    else SettingsService.pin(it.id)
                    dock.contextItem = null
                }
            }
            MenuRow {
                text: SettingsService.isFavorite(contextMenu.item?.id ?? "") ? "Remove from Favorites" : "Add to Favorites"
                onActivated: {
                    const id = contextMenu.item.id
                    if (SettingsService.isFavorite(id)) SettingsService.removeFavorite(id)
                    else SettingsService.addFavorite(id)
                    dock.contextItem = null
                }
            }
            MenuRow {
                visible: contextMenu.item?.pinned ?? false
                text: dock.horizontal ? "Move left" : "Move up"
                onActivated: SettingsService.movePinned(contextMenu.item.rawId, -1)
            }
            MenuRow {
                visible: contextMenu.item?.pinned ?? false
                text: dock.horizontal ? "Move right" : "Move down"
                onActivated: SettingsService.movePinned(contextMenu.item.rawId, 1)
            }
            MenuRow {
                visible: !!contextMenu.item?.entry
                text: "New Window"
                onActivated: {
                    contextMenu.item.entry.execute()
                    dock.contextItem = null
                }
            }
        }
    }

    // ---------- The dock body ----------
    readonly property real along: (horizontal ? iconGrid.implicitWidth : iconGrid.implicitHeight) + 24
    readonly property real across: size + 22

    // Thin strip at the edge that wakes the dock
    Item {
        id: trigger
        x: dock.horizontal ? (dock.width - dock.along) / 2 : dock.side === "left" ? 0 : dock.width - 3
        y: dock.horizontal ? dock.height - 3 : (dock.height - dock.along) / 2
        width: dock.horizontal ? dock.along : 3
        height: dock.horizontal ? 3 : dock.along
        // Only sets the input mask while hidden. Revealing is done by hoverZone below,
        // which lies on top of this strip (Qt gives hover to the topmost item only).
    }

    // Area that keeps the dock open while the mouse is on it
    Item {
        id: hoverZone
        x: dock.horizontal ? body.x - 10 : dock.side === "left" ? 0 : body.x - 10
        y: dock.horizontal ? body.y - 10 : body.y - 10
        width: dock.horizontal ? dock.along + 20 : dock.across + dock.frameT + 10
        height: dock.horizontal ? dock.across + dock.frameT + 10 : dock.along + 20

        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) dock.revealed = true
                dock.updateHover()
            }
        }
    }

    // Concave corners where the dock meets the frame (they move with the dock)
    component Fillet: Canvas {
        property real cx: 0
        property real cy: 0
        width: 14
        height: 14
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(cx, cy, 14, 0, Math.PI * 2)
            c.fill()
        }
    }

    // Before the dock (left of it, or above it)
    Fillet {
        cx: dock.horizontal ? 0 : dock.side === "left" ? 14 : 0
        cy: dock.horizontal ? 0 : 0
        x: dock.horizontal ? body.x - 14 : dock.side === "left" ? body.x : body.x + dock.across - 14
        y: dock.horizontal ? body.y + dock.across - 14 : body.y - 14
        opacity: Math.min(1, dock.reveal * 3)
    }
    // After the dock (right of it, or below it)
    Fillet {
        cx: dock.horizontal ? 14 : dock.side === "left" ? 14 : 0
        cy: dock.horizontal ? 0 : 14
        x: dock.horizontal ? body.x + dock.along : dock.side === "left" ? body.x : body.x + dock.across - 14
        y: dock.horizontal ? body.y + dock.across - 14 : body.y + dock.along
        opacity: Math.min(1, dock.reveal * 3)
    }

    Item {
        id: body
        // Hidden = pushed out past the frame; revealed = resting on the frame's inner edge
        readonly property real hiddenShift: (1 - dock.reveal) * (dock.across + dock.frameT + 4)
        width: dock.horizontal ? dock.along : dock.across
        height: dock.horizontal ? dock.across : dock.along
        x: dock.horizontal ? (dock.width - dock.along) / 2
         : dock.side === "left" ? dock.frameT - hiddenShift
         : dock.width - dock.frameT - dock.across + hiddenShift
        y: dock.horizontal ? dock.height - dock.frameT - dock.across + hiddenShift
         : (dock.height - dock.along) / 2

        // Icons sit on top of hoverZone, so the body tracks hover itself too
        HoverHandler {
            id: bodyHover
            onHoveredChanged: dock.updateHover()
        }

        // Only the corners facing the screen are round: a rounded box,
        // with the half against the frame filled in square
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusXl
            color: Tokens.barBg
        }
        Rectangle {
            color: Tokens.barBg
            x: dock.side === "right" ? parent.width / 2 : 0
            y: dock.horizontal ? parent.height / 2 : 0
            width: dock.horizontal ? parent.width : parent.width / 2
            height: dock.horizontal ? parent.height / 2 : parent.height
        }

        Grid {
            id: iconGrid
            anchors.centerIn: parent
            // The dot sits on the edge side, so nudge the icons a little away from it
            anchors.horizontalCenterOffset: dock.side === "left" ? 2 : dock.side === "right" ? -2 : 0
            anchors.verticalCenterOffset: dock.horizontal ? -2 : 0
            columns: dock.horizontal ? 100 : 1
            spacing: 8

            HoverHandler { id: rowHover }

            Repeater {
                model: SettingsService.dockApps
                AppIcon {}
            }

            Repeater {
                model: dock.runningApps
                AppIcon {}
            }

            // Divider
            Rectangle {
                width: dock.horizontal ? 1 : dock.size * 0.7
                height: dock.horizontal ? dock.size * 0.7 : 1
                color: Tokens.border
            }

            DockIcon {
                source: Quickshell.iconPath("preferences-system", "application-x-executable")
                label: "Settings"
                running: ShellState.settingsOpen
                onClicked: ShellState.settingsOpen = !ShellState.settingsOpen
            }
        }
    }
}
