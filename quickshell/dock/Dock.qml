import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "../theme"
import "../services"

// The dock: black, part of the frame, at the bottom, left or right (Settings > Display & Dock).
// Autohide: hidden inside the frame until the mouse touches the edge.
// Intellihide (default on laptops): also out whenever no window covers its spot.
// Right-click an icon for options. Click the app you are using to minimize it; click again
// to bring it back where you are. Drag pinned icons to reorder them.
// Middle-click an app for a new window. Right-click an app that plays music for its controls.
// Order: pinned apps and Settings | other running apps | minimized windows, Downloads, Trash.
// Downloads opens the newest files as a grid: click to open one, or drag it into an app.
// A dot under a running app (two for several windows), in the accent for the one in focus,
// and a red badge with unread notifications.
PanelWindow {
    id: dock

    readonly property string side: SettingsService.dockPosition
    readonly property bool horizontal: side === "bottom"
    readonly property int frameT: Tokens.frameT

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
    visible: SettingsService.dockEnabled && !ShellState.focusMode

    property int size: SettingsService.dockSize
    property bool revealed: false

    // Out: the mouse is on it, or (intellihide) nothing covers it
    readonly property bool shown: revealed || intelliOpen

    // Grows out of the frame with a small bounce, tucks back quickly
    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        id: openBehavior   // targetValue = where it is going, read before the animation starts
        NumberAnimation {
            duration: openBehavior.targetValue > 0.5 ? 380 : 220
            easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: Tokens.bounce
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
    readonly property Item maskItem: shown ? hoverZone : trigger
    mask: Region {
        x: dock.maskItem.x
        y: dock.maskItem.y
        width: dock.maskItem.width
        height: dock.maskItem.height
        Region { x: windowMenu.x; y: windowMenu.y; width: windowMenu.width; height: windowMenu.height }
        Region { x: contextMenu.x; y: contextMenu.y; width: contextMenu.width; height: contextMenu.height }
        Region { x: trashMenu.x; y: trashMenu.y; width: trashMenu.width; height: trashMenu.height }
        Region { x: downloadsMenu.x; y: downloadsMenu.y; width: downloadsMenu.width; height: downloadsMenu.height }
    }

    // Close every popup (window list, right-click menus, Downloads)
    function closeMenus() {
        menuAppId = ""
        contextItem = null
        trashMenuOpen = false
        downloadsOpen = false
    }

    // ---------- Music ----------
    // The player that belongs to an app (Spotify, Firefox playing a video ...)
    function playerFor(id, entry) {
        if (!id) return null
        const names = [id, entry?.id, entry?.name, entry?.startupClass].filter(x => !!x)
        return Mpris.players.values.find(p => names.some(n =>
            NotificationService.sameApp(n, p.desktopEntry ?? "") || NotificationService.sameApp(n, p.identity ?? ""))) ?? null
    }

    // ---------- Downloads ----------
    readonly property string downloadsDir: Quickshell.env("HOME") + "/Downloads"
    property bool downloadsOpen: false
    readonly property int downloadsShown: Math.min(downloadsModel.count, 12)
    FolderListModel {
        id: downloadsModel
        folder: "file://" + dock.downloadsDir
        sortField: FolderListModel.Time   // newest first
        showDirs: true
        showDirsFirst: false
        showHidden: false
    }
    readonly property var imageTypes: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"]
    function fileIcon(suffix, isDir) {
        if (isDir) return "folder"
        const s = (suffix ?? "").toLowerCase()
        if (s === "pdf") return "application-pdf"
        if (["zip", "7z", "rar", "tar", "gz", "xz", "zst"].includes(s)) return "package-x-generic"
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(s)) return "video-x-generic"
        if (["mp3", "flac", "ogg", "wav", "m4a"].includes(s)) return "audio-x-generic"
        if (["doc", "docx", "odt"].includes(s)) return "x-office-document"
        if (["xls", "xlsx", "ods", "csv"].includes(s)) return "x-office-spreadsheet"
        if (["py", "js", "qml", "c", "cpp", "h", "sh", "lua", "json"].includes(s)) return "text-x-script"
        return "text-x-generic"
    }

    // ---------- Intellihide ----------
    readonly property bool laptop: UPower.displayDevice?.isLaptopBattery ?? false
    readonly property bool intellihide: SettingsService.dockHide === "intellihide"
        || (SettingsService.dockHide === "" && laptop)
    // Does a window on this screen's workspace lie over the dock's spot?
    property bool covered: true
    readonly property bool intelliOpen: intellihide && !covered

    function updateCovered() {
        const mon = Hyprland.monitorFor(dock.screen)
        const scr = dock.screen
        if (!mon || !scr) { covered = true; return }
        const wsId = mon.activeWorkspace?.id ?? -1
        const specialId = mon.lastIpcObject?.specialWorkspace?.id ?? 0

        // Where the dock rests when it is out, in layout coordinates
        const deep = dock.across + dock.frameT
        let rx, ry, rw, rh
        if (horizontal) {
            rw = dock.along; rh = deep
            rx = scr.x + (scr.width - rw) / 2
            ry = scr.y + scr.height - rh
        } else {
            rw = deep; rh = dock.along
            rx = side === "left" ? scr.x : scr.x + scr.width - rw
            ry = scr.y + (scr.height - rh) / 2
        }

        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject
            if (!o || !o.at || !o.size || o.hidden) continue
            if (o.mapped === false) continue
            const ws = o.workspace?.id ?? t.workspace?.id
            if (ws !== wsId && !(specialId !== 0 && ws === specialId)) continue
            const x = o.at[0], y = o.at[1], w = o.size[0], h = o.size[1]
            if (x < rx + rw && x + w > rx && y < ry + rh && y + h > ry) { covered = true; return }
        }
        covered = false
    }

    // Window positions only arrive when asked for, so ask on Hyprland events and now and then
    // (dragging a floating window sends no event until it lands)
    function refreshCovered() {
        Hyprland.refreshToplevels()
        Hyprland.refreshMonitors()
        coverCheck.restart()
    }
    Timer { id: coverCheck; interval: 120; onTriggered: dock.updateCovered() }
    Timer { id: coverSoon; interval: 60; onTriggered: dock.refreshCovered() }
    Timer {
        interval: 800
        repeat: true
        running: dock.intellihide && dock.visible
        onTriggered: dock.refreshCovered()
    }
    Connections {
        target: Hyprland
        enabled: dock.intellihide
        function onRawEvent(event) { coverSoon.restart() }
    }
    onIntellihideChanged: if (intellihide) refreshCovered()
    onAlongChanged: if (intellihide) updateCovered()

    // ---------- Trash ----------
    readonly property string trashDir: Quickshell.env("HOME") + "/.local/share/Trash/files"
    property bool trashMenuOpen: false
    FolderListModel {
        id: trashModel
        showHidden: true
        showDotAndDotDot: false
        showDirs: true
    }
    readonly property bool trashFull: trashModel.count > 0
    // Make sure the folder exists, then watch it (the model does not notice a folder made later)
    Process {
        running: true
        command: ["mkdir", "-p", dock.trashDir]
        onExited: trashModel.folder = "file://" + dock.trashDir
    }

    // Every name an app goes by, for the notification badge
    function badgeFor(id, entry, wins) {
        const names = [id, entry?.id, entry?.name, entry?.startupClass]
        for (const w of wins) names.push(w.wayland?.appId)
        return NotificationService.badgeFor(names)
    }

    // Close every window of an app
    function quitApp(id) {
        for (const w of windowsFor(id))
            Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${addr(w)}" })`)
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
    function isActive(t) {
        return !!Hyprland.activeToplevel && Hyprland.activeToplevel.address === t.address
    }
    function minimize(w) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:${addr(w)}" })`)
    }

    readonly property var minimizedWins: Hyprland.toplevels.values.filter(t => isMinimized(t))

    // Minimized: back to the workspace you are on now, focused. Otherwise just focus it.
    function showWindow(w) {
        if (isMinimized(w)) {
            const ws = Hyprland.focusedWorkspace?.id ?? 1
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${ws}", window = "address:${addr(w)}" })`)
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(w)}" })`)
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
        trashMenuOpen = false
        downloadsOpen = false
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
        // The window you are using: tuck it away. Otherwise bring it here.
        const w = wins[0]
        if (!isMinimized(w) && isActive(w)) minimize(w)
        else showWindow(w)
    }

    // ---------- Drag to reorder ----------
    // While the list changes after a drop, icons skip their pop-in animation
    property bool reordering: false
    function dropPinned(id, iconItem, delta) {
        const list = SettingsService.dockApps
        const from = list.indexOf(id)
        if (from < 0) return
        const center = (horizontal ? iconItem.x + iconItem.width / 2 : iconItem.y + iconItem.height / 2) + delta
        let to = 0
        for (let i = 0; i < pinnedRepeater.count; i++) {
            if (i === from) continue
            const it = pinnedRepeater.itemAt(i)
            if (!it) continue
            const c = horizontal ? it.x + it.width / 2 : it.y + it.height / 2
            if (center > c) to++
        }
        if (to === from) return
        reordering = true
        SettingsService.moveTo(id, to)
        Qt.callLater(() => dock.reordering = false)
    }

    function openContext(id, entry, iconItem) {
        menuAppId = ""
        trashMenuOpen = false
        downloadsOpen = false
        popupAt = popupPoint(iconItem)
        contextItem = { id: entry?.id ?? id, entry: entry, pinned: SettingsService.isPinned(id), rawId: id }
    }

    function updateHover() {
        if (dockHover.hovered || bodyHover.hovered || menuHover.hovered || contextHover.hovered
            || trashHover.hovered || downloadsHover.hovered) hideTimer.stop()
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
            dock.closeMenus()
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
        property bool focused: false       // its window is the one in focus: accent dot
        property bool multi: false         // several windows: two dots
        property int badge: 0              // unread notifications
        property real imageSize: dock.size - 8
        property bool tile: false          // minimized window: icon on a small tile
        property bool draggable: false
        property real dragDelta: 0
        readonly property bool dragging: iconMouse.dragging
        signal clicked()
        signal rightClicked()
        signal middleClicked()
        signal dropped(real delta)
        z: dragging ? 10 : 0

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
        // One small hop (a new window of an app that is already open)
        function hopOnce() { if (!bounceAnim.running && !settleAnim.running) settleAnim.start() }

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

        Rectangle {
            visible: icon.tile
            anchors.centerIn: parent
            width: icon.imageSize + 10
            height: icon.imageSize + 10
            radius: Tokens.radiusMd
            color: iconMouse.containsMouse ? Tokens.fillStrong : Tokens.fillHover
            scale: iconImage.scale
            transform: Translate { x: icon.hop * icon.outX; y: icon.hop * icon.outY }
        }

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: icon.imageSize
            height: icon.imageSize
            sourceSize: Qt.size(96, 96)
            source: icon.source
            transformOrigin: dock.side === "left" ? Item.Left : dock.side === "right" ? Item.Right : Item.Bottom
            scale: icon.mag
            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
            transform: Translate {
                x: icon.hop * icon.outX + (dock.horizontal ? icon.dragDelta : 0)
                y: icon.hop * icon.outY + (dock.horizontal ? 0 : icon.dragDelta)
            }

            // Unread notifications, on the icon's top right corner (grows and hops with it)
            Rectangle {
                visible: icon.badge > 0
                height: 18
                width: Math.max(height, badgeText.implicitWidth + 10)
                radius: height / 2
                x: parent.width - width * 0.7
                y: -height * 0.3
                color: "#e5484d"
                border.color: Tokens.barBg
                border.width: 2

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: icon.badge > 99 ? "99+" : icon.badge
                    color: "white"
                    font.family: Tokens.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
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

        // New icons pop in (not when the list was just reordered)
        scale: 0.4
        opacity: 0
        Component.onCompleted: {
            if (dock.reordering) { scale = 1; opacity = 1 }
            else popIn.start()
        }
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
                && !dock.trashMenuOpen && !dock.downloadsOpen && !icon.dragging

            Text {
                id: labelText
                anchors.centerIn: parent
                text: icon.label
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
            }
        }

        // Dots: white = running, accent = in focus, grey = only minimized,
        // two = several windows. They sit on the edge side.
        Grid {
            visible: icon.running
            columns: dock.horizontal ? 2 : 1
            spacing: 3
            x: dock.horizontal ? (parent.width - width) / 2
             : dock.side === "left" ? -6 : parent.width + 2
            y: dock.horizontal ? parent.height + 2 : (parent.height - height) / 2

            Repeater {
                model: icon.multi ? 2 : 1
                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: icon.focused ? Tokens.accent : icon.dimmed ? Tokens.textSecondary : Tokens.textPrimary
                }
            }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            property real pressPos: 0
            property bool dragging: false
            property bool wasDrag: false
            onPressed: mouse => {
                pressPos = dock.horizontal ? mouse.x : mouse.y
                wasDrag = false
            }
            onPositionChanged: mouse => {
                if (!pressed || !icon.draggable || !(pressedButtons & Qt.LeftButton)) return
                const d = (dock.horizontal ? mouse.x : mouse.y) - pressPos
                if (!dragging && Math.abs(d) > 8) dragging = true
                if (dragging) icon.dragDelta = d
            }
            onReleased: {
                if (dragging) {
                    wasDrag = true
                    const d = icon.dragDelta
                    dragging = false
                    icon.dragDelta = 0
                    icon.dropped(d)
                }
            }
            onClicked: mouse => {
                if (wasDrag) return
                if (mouse.button === Qt.RightButton) icon.rightClicked()
                else if (mouse.button === Qt.MiddleButton) icon.middleClicked()
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
        focused: wins.some(w => !dock.isMinimized(w) && dock.isActive(w))
        multi: wins.filter(w => !dock.isMinimized(w)).length > 1
        badge: dock.badgeFor(modelData, entry, wins)
        onClicked: dock.appClicked(modelData, entry, appIcon)
        onRightClicked: dock.openContext(modelData, entry, appIcon)
        // New window: starts the app again (most apps open another window)
        onMiddleClicked: {
            if (!entry) return
            dock.closeMenus()
            entry.execute()
            if (running) appIcon.hopOnce()
            else appIcon.bounce()
        }
    }

    // A pinned app: can be dragged to a new place
    component PinnedIcon: AppIcon {
        id: pinnedIcon
        draggable: true
        onDropped: delta => dock.dropPinned(modelData, pinnedIcon, delta)
    }

    // A minimized window: a small tile; click brings it to the workspace you are on
    component MinimizedIcon: DockIcon {
        id: minIcon
        required property var modelData
        readonly property var entry: dock.findEntry(modelData.wayland?.appId ?? "")
        tile: true
        imageSize: Math.round(dock.size * 0.55)
        source: Quickshell.iconPath(entry?.icon ?? (modelData.wayland?.appId ?? "").toLowerCase(), "application-x-executable")
        label: modelData.title || entry?.name || "Window"
        onClicked: dock.showWindow(modelData)
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

    // Round icon button (music controls)
    component CtrlButton: Item {
        id: btn
        scale: btnMouse.pressed ? Tokens.pressScaleIcon : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
        property string icon: ""
        property int size: 18
        signal clicked()
        width: size + 14
        height: size + 14

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: btnMouse.containsMouse ? Tokens.fillHover : "transparent"
        }
        TintIcon {
            anchors.centerIn: parent
            width: btn.size
            height: btn.size
            source: Quickshell.iconPath(btn.icon)
            opacity: btnMouse.pressed ? 0.6 : 1
        }
        MouseArea {
            id: btnMouse
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            onClicked: btn.clicked()
        }
    }

    PopupBox {
        id: contextMenu
        readonly property bool open: dock.contextItem !== null
        readonly property var item: dock.contextItem
        // Music from this app, shown at the top of the menu
        readonly property var player: open ? dock.playerFor(item?.rawId, item?.entry) : null
        readonly property bool hasMusic: player !== null && (player.trackTitle ?? "") !== ""
        width: open ? (hasMusic ? 270 : 220) : 0
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
                topPadding: Tokens.spaceXs
                bottomPadding: Tokens.spaceXs
                text: contextMenu.item?.entry?.name ?? contextMenu.item?.id ?? ""
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
            }

            // Now playing: cover, title, artist and the controls
            Item {
                visible: contextMenu.hasMusic
                width: parent.width
                height: visible ? 104 : 0

                Rectangle {
                    id: artBox
                    x: 6
                    y: 4
                    width: 48
                    height: 48
                    radius: Tokens.radiusSm
                    color: Tokens.fillHover
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: contextMenu.player?.trackArtUrl ?? ""
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    anchors.left: artBox.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: artBox.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: contextMenu.player?.trackTitle ?? ""
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontBody
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: contextMenu.player?.trackArtist ?? ""
                        color: Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSmall
                        elide: Text.ElideRight
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: artBox.y + artBox.height + 6
                    spacing: Tokens.spaceSm

                    CtrlButton {
                        icon: "media-skip-backward-symbolic"
                        onClicked: contextMenu.player?.previous()
                    }
                    CtrlButton {
                        icon: contextMenu.player?.isPlaying ? "media-playback-pause-symbolic"
                                                            : "media-playback-start-symbolic"
                        onClicked: contextMenu.player?.togglePlaying()
                    }
                    CtrlButton {
                        icon: "media-skip-forward-symbolic"
                        onClicked: contextMenu.player?.next()
                    }
                }
            }
            Rectangle {
                visible: contextMenu.hasMusic
                width: parent.width
                height: 1
                color: Tokens.border
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
            MenuRow {
                visible: contextMenu.open && dock.windowsFor(contextMenu.item?.rawId ?? "").length > 0
                text: "Quit"
                danger: true
                onActivated: {
                    dock.quitApp(contextMenu.item.rawId)
                    dock.contextItem = null
                }
            }
        }
    }

    // Downloads: the newest files as a grid. Click opens, drag takes the file into an app.
    PopupBox {
        id: downloadsMenu
        readonly property bool open: dock.downloadsOpen
        readonly property int tile: 78
        width: open ? tile * 4 + Tokens.spaceXs * 3 + 16 : 0
        height: open ? dlColumn.implicitHeight + 16 : 0
        visible: open

        HoverHandler {
            id: downloadsHover
            onHoveredChanged: dock.updateHover()
        }

        Column {
            id: dlColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: Tokens.spaceSm

            Text {
                leftPadding: 4
                text: "Downloads"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
            }

            Text {
                visible: dock.downloadsShown === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: Tokens.spaceMd
                bottomPadding: Tokens.spaceMd
                text: "Nothing downloaded yet"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
            }

            Grid {
                columns: 4
                spacing: Tokens.spaceXs

                Repeater {
                    model: dock.downloadsShown

                    Item {
                        id: dlTile
                        required property int index
                        readonly property string path: downloadsModel.get(index, "filePath") ?? ""
                        readonly property string name: downloadsModel.get(index, "fileName") ?? ""
                        readonly property string suffix: downloadsModel.get(index, "fileSuffix") ?? ""
                        readonly property bool isDir: downloadsModel.get(index, "fileIsDir") ?? false
                        readonly property bool isImage: !isDir && dock.imageTypes.includes(suffix.toLowerCase())
                        width: downloadsMenu.tile
                        height: downloadsMenu.tile + 6

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radiusSm
                            color: dlMouse.containsMouse ? Tokens.fillHover : "transparent"
                        }

                        Image {
                            id: dlThumb
                            visible: dlTile.isImage
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            width: 46
                            height: 46
                            source: dlTile.isImage ? "file://" + dlTile.path : ""
                            sourceSize: Qt.size(92, 92)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Image {
                            visible: !dlTile.isImage
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            width: 46
                            height: 46
                            sourceSize: Qt.size(92, 92)
                            source: Quickshell.iconPath(dock.fileIcon(dlTile.suffix, dlTile.isDir), "text-x-generic")
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 4
                            y: 56
                            horizontalAlignment: Text.AlignHCenter
                            text: dlTile.name
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSmall
                            elide: Text.ElideMiddle
                        }

                        // Drag the file out into another app
                        Item {
                            id: dlDrag
                            Drag.active: dlMouse.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.mimeData: { "text/uri-list": "file://" + dlTile.path }
                        }

                        MouseArea {
                            id: dlMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            drag.target: dlDrag
                            onClicked: {
                                Quickshell.execDetached(["xdg-open", dlTile.path])
                                dock.downloadsOpen = false
                            }
                        }
                    }
                }
            }

            MenuRow {
                text: "Open in Files"
                onActivated: {
                    Quickshell.execDetached(["xdg-open", dock.downloadsDir])
                    dock.downloadsOpen = false
                }
            }
        }
    }

    // Right-click on the Trash
    PopupBox {
        id: trashMenu
        readonly property bool open: dock.trashMenuOpen
        width: open ? 200 : 0
        height: open ? trashColumn.implicitHeight + 12 : 0
        visible: open

        HoverHandler {
            id: trashHover
            onHoveredChanged: dock.updateHover()
        }

        Column {
            id: trashColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 2

            Text {
                leftPadding: 10
                topPadding: Tokens.spaceXs
                bottomPadding: Tokens.spaceXs
                text: dock.trashFull ? "Trash · " + trashModel.count + (trashModel.count === 1 ? " item" : " items") : "Trash · empty"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
            }
            MenuRow {
                text: "Open"
                onActivated: {
                    Quickshell.execDetached(["gio", "open", "trash:///"])
                    dock.trashMenuOpen = false
                }
            }
            MenuRow {
                visible: dock.trashFull
                text: "Empty Trash"
                danger: true
                onActivated: {
                    Quickshell.execDetached(["gio", "trash", "--empty"])
                    dock.trashMenuOpen = false
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
        readonly property string paintKey: Tokens.themeName + Tokens.accent
        onPaintKeyChanged: requestPaint()
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
        x: dock.horizontal ? body.x - 14 : dock.side === "left" ? body.x : body.x + body.width - 14
        y: dock.horizontal ? body.y + body.height - 14 : body.y - 14
        opacity: Math.min(1, dock.reveal * 3)
    }
    // After the dock (right of it, or below it)
    Fillet {
        cx: dock.horizontal ? 14 : dock.side === "left" ? 14 : 0
        cy: dock.horizontal ? 0 : 14
        x: dock.horizontal ? body.x + dock.along : dock.side === "left" ? body.x : body.x + body.width - 14
        y: dock.horizontal ? body.y + body.height - 14 : body.y + dock.along
        opacity: Math.min(1, dock.reveal * 3)
    }

    Item {
        id: body
        // Soft shadow, so it floats over what is under it
        layer.enabled: Tokens.menuShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Tokens.shadowColor
            shadowBlur: Tokens.shadowBlur
            blurMax: 32
            shadowVerticalOffset: 2
        }
        // Hidden = pushed out past the frame; revealed = resting on the frame's inner edge.
        // The bounce past "revealed" stretches the dock instead of lifting it,
        // so its edge never leaves the frame.
        readonly property real rawShift: (1 - dock.reveal) * (dock.across + dock.frameT + 4)
        readonly property real hiddenShift: Math.max(0, rawShift)
        readonly property real stretch: Math.max(0, -rawShift)
        readonly property real thick: dock.across + stretch
        width: dock.horizontal ? dock.along : thick
        height: dock.horizontal ? thick : dock.along
        x: dock.horizontal ? (dock.width - dock.along) / 2
         : dock.side === "left" ? dock.frameT - hiddenShift
         : dock.width - dock.frameT - thick + hiddenShift
        y: dock.horizontal ? dock.height - dock.frameT - thick + hiddenShift
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
            spacing: Tokens.spaceSm

            HoverHandler { id: rowHover }

            // Pinned apps, then Settings
            Repeater {
                id: pinnedRepeater
                model: SettingsService.dockApps
                PinnedIcon {}
            }

            DockIcon {
                source: Quickshell.iconPath("preferences-system", "application-x-executable")
                label: "Settings"
                running: ShellState.settingsOpen
                onClicked: ShellState.settingsOpen = !ShellState.settingsOpen
            }

            // Running apps that are not pinned, after a divider
            Rectangle {
                visible: dock.runningApps.length > 0
                width: dock.horizontal ? 1 : dock.size * 0.7
                height: dock.horizontal ? dock.size * 0.7 : 1
                color: Tokens.border
            }

            Repeater {
                model: dock.runningApps
                AppIcon {}
            }

            // Minimized windows and the Trash, after the last divider
            Rectangle {
                width: dock.horizontal ? 1 : dock.size * 0.7
                height: dock.horizontal ? dock.size * 0.7 : 1
                color: Tokens.border
            }

            Repeater {
                model: dock.minimizedWins
                MinimizedIcon {}
            }

            DockIcon {
                id: downloadsIcon
                source: Quickshell.iconPath("folder-download", "folder")
                label: "Downloads"
                running: dock.downloadsOpen
                function toggle() {
                    const open = !dock.downloadsOpen
                    dock.closeMenus()
                    if (open) {
                        dock.popupAt = dock.popupPoint(downloadsIcon)
                        dock.downloadsOpen = true
                    }
                }
                onClicked: toggle()
                onRightClicked: toggle()
                onMiddleClicked: Quickshell.execDetached(["xdg-open", dock.downloadsDir])
            }

            DockIcon {
                id: trashIcon
                source: Quickshell.iconPath(dock.trashFull ? "user-trash-full" : "user-trash", "user-trash")
                label: "Trash"
                onClicked: {
                    dock.trashMenuOpen = false
                    Quickshell.execDetached(["gio", "open", "trash:///"])
                }
                onRightClicked: {
                    dock.closeMenus()
                    dock.popupAt = dock.popupPoint(trashIcon)
                    dock.trashMenuOpen = true
                }
            }
        }
    }
}
