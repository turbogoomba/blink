import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

PanelWindow {
    id: dock
    anchors { bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: 360
    color: "transparent"

    // Venstre side: festede apper
    property list<string> apps: ["firefox"]
    // Høyre side: system-apper
    property list<string> systemApps: ["thunar", "kitty"]

    property int size: SettingsService.dockSize

    property bool revealed: false

    // Vinduslisten
    property string menuAppId: ""
    property real menuX: 0

    // Hvor musen er over ikonraden (-1 = ikke over), brukes til forstørrelse
    readonly property real hoverX: rowHover.hovered ? rowHover.point.position.x : -1

    // Apper som kjører, men ikke er festet
    readonly property var runningApps: {
        const pinned = [...apps, ...systemApps].map(a => a.toLowerCase())
        const ids = []
        for (const t of Hyprland.toplevels.values) {
            const id = t.wayland?.appId
            if (!id || id === "org.quickshell") continue
            if (pinned.includes(id.toLowerCase())) continue
            if (!ids.includes(id)) ids.push(id)
        }
        return ids
    }

    mask: Region {
        item: dock.revealed ? hoverZone : trigger
        Region { item: windowMenu }
    }

    // ---------- Hjelpefunksjoner ----------
    function windowsFor(appId) {
        const id = appId.toLowerCase()
        return Hyprland.toplevels.values.filter(t => t.wayland?.appId?.toLowerCase() === id)
    }
    function addr(t) {
        const a = t.address
        return a.startsWith("0x") ? a : "0x" + a
    }
    function isMinimized(t) {
        return t.workspace?.name === "special:minimized"
    }
    function findEntry(appId) {
        const id = appId.toLowerCase()
        const all = DesktopEntries.applications.values
        return all.find(e => e.id.toLowerCase() === id)
            ?? all.find(e => (e.startupClass ?? "").toLowerCase() === id)
            ?? null
    }

    function showWindow(w) {
        if (isMinimized(w)) {
            const ws = Hyprland.focusedWorkspace?.id ?? 1
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${ws}", window = "address:${addr(w)}" })`)
        } else {
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(w)}" })`)
        }
    }

    function appClicked(appId, entry, iconItem) {
        const wins = windowsFor(appId)

        // Kjører ikke: start appen, og la ikonet hoppe
        if (wins.length === 0) {
            entry?.execute()
            iconItem.bounce()
            return
        }

        // Flere vinduer: vis/skjul vinduslisten
        if (wins.length > 1) {
            if (menuAppId === appId) {
                menuAppId = ""
            } else {
                menuX = iconItem.mapToItem(null, iconItem.width / 2, 0).x
                menuAppId = appId
            }
            return
        }

        // Ett vindu: gi fokus
        showWindow(wins[0])
    }

    function updateHover() {
        if (dockHover.hovered || menuHover.hovered) hideTimer.stop()
        else hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 400
        onTriggered: {
            dock.menuAppId = ""
            dock.revealed = false
        }
    }

    // ---------- Ett ikon i docken ----------
    component DockIcon: Item {
        id: icon
        property string source: ""
        property string label: ""
        property bool running: false
        property bool dimmed: false
        signal clicked()

        // Forstørrelse: jo nærmere musen, jo større (maks 1.35)
        readonly property real mag: {
            if (dock.hoverX < 0) return 1
            const d = Math.abs(dock.hoverX - (icon.x + icon.width / 2))
            return 1 + 0.35 * Math.max(0, 1 - d / 110)
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

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: dock.size - 8
            height: dock.size - 8
            sourceSize: Qt.size(96, 96)
            source: icon.source
            transformOrigin: Item.Bottom
            scale: icon.mag
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            transform: Translate { id: lift; y: 0 }
        }

        // Hopp når appen starter. Repeats while launching, then one small last hop.
        SequentialAnimation {
            id: bounceAnim
            NumberAnimation { target: lift; property: "y"; to: -18; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: lift; property: "y"; to: 0;   duration: 220; easing.type: Easing.InQuad }
            onFinished: {
                if (icon.launching) bounceAnim.start()
                else settleAnim.start()
            }
        }
        SequentialAnimation {
            id: settleAnim
            NumberAnimation { target: lift; property: "y"; to: -6; duration: 120; easing.type: Easing.OutQuad }
            NumberAnimation { target: lift; property: "y"; to: 0;  duration: 120; easing.type: Easing.InQuad }
        }

        // New icons (apps that start running) pop in
        scale: 0.4
        opacity: 0
        Component.onCompleted: popIn.start()
        ParallelAnimation {
            id: popIn
            NumberAnimation { target: icon; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack }
            NumberAnimation { target: icon; property: "opacity"; to: 1; duration: 160 }
        }

        // Navnelapp over ikonet
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height - 18 - (icon.mag - 1) * 40
            width: labelText.implicitWidth + 16
            height: 24
            radius: 6
            color: Tokens.surface
            border.color: Tokens.border
            border.width: 1
            visible: iconMouse.containsMouse && icon.label !== ""

            Text {
                id: labelText
                anchors.centerIn: parent
                text: icon.label
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
            }
        }

        // Prikk: hvit = kjører, grå = bare minimert
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -4
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
            onClicked: icon.clicked()
        }
    }

    // ---------- En app ----------
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
    }

    // ---------- Vinduslisten ----------
    Rectangle {
        id: windowMenu
        readonly property bool open: dock.menuAppId !== ""
        readonly property var wins: open ? dock.windowsFor(dock.menuAppId) : []

        width: open ? 260 : 0
        height: open ? menuColumn.implicitHeight + 12 : 0
        x: Math.max(8, Math.min(parent.width - width - 8, dock.menuX - width / 2))
        y: hoverZone.y + dockRect.y - height - 8
        visible: open
        radius: 12
        color: Tokens.surface
        border.color: Tokens.border
        border.width: 1

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

                Rectangle {
                    id: menuRow
                    required property var modelData
                    readonly property bool minimized: dock.isMinimized(modelData)

                    width: menuColumn.width
                    height: 32
                    radius: 8
                    color: rowMouse.containsMouse ? Tokens.border : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: (menuRow.modelData.title || "Untitled")
                              + (menuRow.minimized ? "  (minimized)" : "")
                        color: menuRow.minimized ? Tokens.textSecondary : Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            dock.showWindow(menuRow.modelData)
                            dock.menuAppId = ""
                        }
                    }
                }
            }
        }
    }

    // ---------- Docken ----------
    Item {
        id: hoverZone
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: dockRect.width
        height: dock.size + 28

        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) dock.revealed = true
                dock.updateHover()
            }
        }

        Item {
            id: trigger
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
        }

        Rectangle {
            id: dockRect
            anchors.horizontalCenter: parent.horizontalCenter
            width: row.implicitWidth + 16
            height: dock.size + 16
            y: dock.revealed ? parent.height - height - 8 : parent.height + 4
            radius: 20
            color: Tokens.surface
            border.color: Tokens.border
            border.width: 1

            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8

                HoverHandler { id: rowHover }

                // Festede apper
                Repeater {
                    model: dock.apps
                    AppIcon {}
                }

                // Kjørende apper som ikke er festet
                Repeater {
                    model: dock.runningApps
                    AppIcon {}
                }

                // Skillelinje
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: dock.size * 0.7
                    color: Tokens.border
                }

                // System-apper
                Repeater {
                    model: dock.systemApps
                    AppIcon {}
                }

                // Innstillinger
                DockIcon {
                    source: Quickshell.iconPath("preferences-system", "application-x-executable")
                    label: "Settings"
                    running: ShellState.settingsOpen
                    onClicked: ShellState.settingsOpen = !ShellState.settingsOpen
                }
            }
        }
    }
}
