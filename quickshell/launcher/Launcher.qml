import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

PanelWindow {
    id: launcher
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Open on the monitor you are using (matters with two screens)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "launcher"

    // 0 = tucked into the notch, 1 = fully open. Grows with a little bounce.
    property real reveal: ShellState.launcherOpen ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: ShellState.launcherOpen ? 420 : 220
            easing.type: ShellState.launcherOpen ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: 0.8
        }
    }
    visible: ShellState.launcherOpen || reveal > 0.01

    property int selected: 0

    // Søkeresultater: navn som starter med søket først
    readonly property var results: {
        const q = search.text.trim().toLowerCase()
        if (q === "") return []
        const scored = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            const name = (e.name ?? "").toLowerCase()
            const generic = (e.genericName ?? "").toLowerCase()
            const keywords = (e.keywords ?? []).join(" ").toLowerCase()
            let score = -1
            if (name.startsWith(q)) score = 3
            else if (name.includes(q)) score = 2
            else if (generic.includes(q) || keywords.includes(q)) score = 1
            if (score >= 0) scored.push({ entry: e, score: score })
        }

        // Firefox bookmarks (just below apps with the same kind of match)
        for (const b of BookmarkService.items) {
            const title = b.title.toLowerCase()
            let score = -1
            if (title.startsWith(q)) score = 2.5
            else if (title.includes(q)) score = 1.5
            else if (b.url.toLowerCase().includes(q)) score = 0.5
            if (score >= 0) scored.push({ entry: webItem(b.title, b.host, b.url), score: score })
        }

        scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name))
        const list = scored.slice(0, 8).map(s => s.entry)

        // Typed an address? Offer to open it directly
        if (/^[^\s]+\.[a-z]{2,}(\/\S*)?$/i.test(q) && !list.some(e => e.url && e.host === q.replace(/^https?:\/\//, "").replace(/^www\./, "").split("/")[0])) {
            const raw = search.text.trim()
            const url = /^https?:\/\//i.test(raw) ? raw : "https://" + raw
            list.unshift(webItem("Open " + raw, "Website", url))
        }
        return list
    }

    // A website result that looks like an app entry to the rest of the launcher
    function webItem(title, subtitle, url) {
        return {
            name: title,
            genericName: subtitle,
            icon: "firefox",
            id: "",
            url: url,
            host: url.replace(/^https?:\/\//, "").replace(/^www\./, "").split("/")[0],
            execute: () => Qt.openUrlExternally(url)
        }
    }
    onResultsChanged: {
        selected = 0
        menuEntry = null
    }

    // Right-click menu on a result: Open / Pin to Dock / Add to Favorites
    property var menuEntry: null
    property real menuX: 0
    property real menuY: 0
    function openMenu(entry, x, y) {
        menuEntry = entry
        menuX = Math.min(x, width - menu.width - 8)
        menuY = y
    }

    function close() {
        menuEntry = null
        ShellState.launcherOpen = false
    }
    function launch(entry) {
        if (!entry) return
        entry.execute()
        close()
    }

    Connections {
        target: ShellState
        function onLauncherOpenChanged() {
            if (ShellState.launcherOpen) {
                BookmarkService.refresh()
                search.text = ""
                launcher.selected = 0
                search.forceActiveFocus()
            }
        }
    }

    // Klikk utenfor lukker
    MouseArea {
        anchors.fill: parent
        onClicked: launcher.menuEntry ? launcher.menuEntry = null : launcher.close()
    }

    // Concave corners where the sheet meets the bar
    component Fillet: Canvas {
        property bool mirrored: false
        y: Tokens.barHeight
        width: 14
        height: 14
        opacity: Math.min(1, launcher.reveal * 4)
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(mirrored ? 14 : 0, 14, 14, 0, Math.PI * 2)
            c.fill()
        }
    }
    Fillet { x: box.x - 14 }
    Fillet { x: box.x + box.width; mirrored: true }

    // The sheet: starts as the notch and grows down out of it
    Item {
        id: box
        readonly property real topPad: Tokens.barHeight + 6
        readonly property real fullW: 640
        readonly property real startW: 200
        readonly property real startH: Tokens.barHeight + 8
        property real fullH: topPad + content.implicitHeight + 8
        Behavior on fullH { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: startW + (fullW - startW) * launcher.reveal
        height: startH + (fullH - startH) * Math.max(0, launcher.reveal)
        clip: true

        // Same black as the bar. Top corners hide under the bar, bottom ones are round.
        Rectangle {
            y: -24
            width: parent.width
            height: parent.height + 24
            radius: Tokens.radiusXl
            color: Tokens.barBg
        }

        // Klikk inni boksen skal ikke lukke
        MouseArea {
            anchors.fill: parent
            onClicked: launcher.menuEntry = null
        }

        Column {
            id: content
            x: (box.width - box.fullW) / 2
            y: box.topPad
            width: box.fullW
            opacity: Math.max(0, Math.min(1, (launcher.reveal - 0.35) / 0.5))

            // ---------- Søkefelt ----------
            Item {
                width: parent.width
                height: 56

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    radius: Tokens.radiusLg
                    color: Tokens.fillIdle
                    border.color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                }

                Image {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    sourceSize: Qt.size(40, 40)
                    source: Quickshell.iconPath("system-search-symbolic", "system-search")
                    opacity: 0.7
                }

                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.textPrimary
                    selectionColor: Tokens.accent
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontLarge

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (launcher.menuEntry) launcher.menuEntry = null
                            else launcher.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            launcher.selected = Math.min(launcher.selected + 1, launcher.results.length - 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            launcher.selected = Math.max(launcher.selected - 1, 0)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            launcher.launch(launcher.results[launcher.selected])
                            event.accepted = true
                        }
                    }

                    // Plassholdertekst
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search apps"
                        color: Tokens.textSecondary
                        font: search.font
                        visible: search.text === ""
                    }
                }
            }

            // ---------- Skillelinje ----------
            Item {
                width: parent.width
                height: 4
                visible: launcher.results.length > 0
            }

            // ---------- Resultater ----------
            Column {
                width: parent.width
                padding: 6
                spacing: 2
                visible: launcher.results.length > 0

                Repeater {
                    model: launcher.results

                    Rectangle {
                        id: resultRow
                        scale: resultRowMouse.pressed ? Tokens.pressScale : 1
                        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: index === launcher.selected

                        width: parent.width - 12
                        height: 44
                        radius: Tokens.radiusMd
                        color: isSelected ? Tokens.accent : (resultRowMouse.containsMouse ? Tokens.fillHover : "transparent")

                        Image {
                            id: appIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            sourceSize: Qt.size(56, 56)
                            source: Quickshell.iconPath(resultRow.modelData.icon ?? "", "application-x-executable")
                        }

                        Column {
                            anchors.left: appIcon.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                width: parent.width
                                text: resultRow.modelData.name ?? ""
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: resultRow.modelData.genericName ?? ""
                                visible: text !== ""
                                color: resultRow.isSelected ? Tokens.textPrimary : Tokens.textSecondary
                                opacity: resultRow.isSelected ? 0.8 : 1
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: resultRowMouse
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: if (!launcher.menuEntry) launcher.selected = resultRow.index
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    launcher.selected = resultRow.index
                                    const p = mapToItem(null, mouse.x, mouse.y)
                                    launcher.openMenu(resultRow.modelData, p.x, p.y)
                                } else {
                                    launcher.launch(resultRow.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- Right-click menu ----------
    component MenuRow: Rectangle {
        id: row
        scale: rowMouse.pressed ? Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
        property string label: ""
        signal triggered()
        width: parent.width
        height: 32
        radius: Tokens.radiusSm
        color: rowMouse.containsMouse ? Tokens.accent : "transparent"
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontBody
        }
        MouseArea {
            id: rowMouse
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                row.triggered()
                launcher.menuEntry = null
            }
        }
    }

    Rectangle {
        id: menu
        readonly property string entryId: launcher.menuEntry?.id ?? ""
        x: launcher.menuX
        y: launcher.menuY
        width: 210
        height: menuCol.implicitHeight + 10
        radius: Tokens.radiusMd
        color: Tokens.bg
        border.color: Tokens.border
        border.width: 1
        visible: launcher.menuEntry !== null && launcher.reveal > 0.9
        scale: visible ? 1 : 0.94
        transformOrigin: Item.TopLeft
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeGrow } }

        // Clicks on the menu itself stay here
        MouseArea { anchors.fill: parent }

        Column {
            id: menuCol
            x: 5
            y: 5
            width: parent.width - 10
            spacing: 2

            MenuRow {
                label: "Open"
                onTriggered: launcher.launch(launcher.menuEntry)
            }
            MenuRow {
                visible: menu.entryId !== ""
                label: SettingsService.isPinned(menu.entryId) ? "Unpin from Dock" : "Pin to Dock"
                onTriggered: SettingsService.togglePin(menu.entryId)
            }
            MenuRow {
                visible: menu.entryId !== ""
                label: SettingsService.isFavorite(menu.entryId) ? "Remove from Favorites" : "Add to Favorites"
                onTriggered: SettingsService.isFavorite(menu.entryId)
                    ? SettingsService.removeFavorite(menu.entryId)
                    : SettingsService.addFavorite(menu.entryId)
            }
        }
    }
}
