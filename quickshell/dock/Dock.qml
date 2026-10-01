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
    // Høyt nok til at vinduslisten får plass over docken
    implicitHeight: 360
    color: "transparent"

    // Venstre side: festede apper
    property list<string> apps: ["firefox"]
    // Høyre side: system-apper
    property list<string> systemApps: ["thunar", "kitty"]

    property bool revealed: false

    // Vinduslisten: hvilken app den vises for, og hvor
    property string menuAppId: ""
    property real menuX: 0

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

    // Skjult: bare en tynn stripe nederst fanger musen.
    // Synlig: docken (og vinduslisten) fanger musen.
    mask: Region {
        item: dock.revealed ? hoverZone : trigger
        Region { item: windowMenu }
    }

    // ---------- Hjelpefunksjoner for vinduer ----------
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

    // Hent frem ett bestemt vindu
    function showWindow(w) {
        if (isMinimized(w)) {
            const ws = Hyprland.focusedWorkspace?.id ?? 1
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${ws}", window = "address:${addr(w)}" })`)
        } else {
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(w)}" })`)
        }
    }

    function minimizeWindow(w) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:${addr(w)}" })`)
    }

    function appClicked(appId, entry, iconItem) {
        const wins = windowsFor(appId)

        // Kjører ikke: start appen
        if (wins.length === 0) {
            entry?.execute()
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

    // Skjul docken og lukk lista når musen er borte fra begge
    function updateHover() {
        if (dockHover.hovered || menuHover.hovered) {
            hideTimer.stop()
        } else {
            hideTimer.restart()
        }
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
        property bool running: false
        property bool dimmed: false
        signal clicked()

        width: 48
        height: 48

        Image {
            anchors.centerIn: parent
            width: 40
            height: 40
            sourceSize: Qt.size(80, 80)
            source: icon.source
            scale: iconMouse.containsMouse ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
        running: wins.length > 0
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
    // Området som merker musen: fra docken og helt ned til skjermkanten
    Item {
        id: hoverZone
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: dockRect.width
        height: 64 + 8 + 4

        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) dock.revealed = true
                dock.updateHover()
            }
        }

        // Tynn stripe nederst som viser docken
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
            height: 64
            y: dock.revealed ? parent.height - height - 8 : parent.height + 4
            radius: 18
            color: Tokens.surface
            border.color: Tokens.border
            border.width: 1

            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8

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
                    height: 36
                    color: Tokens.border
                }

                // System-apper
                Repeater {
                    model: dock.systemApps
                    AppIcon {}
                }

                // Innstillinger (din egen Settings-app)
                DockIcon {
                    source: Quickshell.iconPath("preferences-system", "application-x-executable")
                    running: ShellState.settingsOpen
                    onClicked: ShellState.settingsOpen = !ShellState.settingsOpen
                }
            }
        }
    }
}
