import QtQuick
import QtQuick.Effects
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
        id: openBehavior   // targetValue = where it is going, read before the animation starts
        NumberAnimation {
            duration: openBehavior.targetValue > 0.5 ? Tokens.durOpen : Tokens.durClose
            easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: Tokens.bounce
        }
    }
    visible: ShellState.launcherOpen || reveal > 0.01

    property int selected: 0
    // With the side bar it grows up out of the bottom edge instead of down out of the notch
    readonly property bool fromBottom: SettingsService.sideBar

    // Søkeresultater: navn som starter med søket først
    readonly property var results: {
        const q = search.text.trim().toLowerCase()
        if (q === "") return []
        const scored = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            if ((SettingsService.launcherHidden ?? []).indexOf(e.name) >= 0) continue
            const name = (e.name ?? "").toLowerCase()
            const generic = (e.genericName ?? "").toLowerCase()
            const keywords = (e.keywords ?? []).join(" ").toLowerCase()
            let score = -1
            if (name.startsWith(q)) score = 3
            else if (name.includes(q)) score = 2
            else if (generic.includes(q) || keywords.includes(q)) score = 1
            if (score >= 0) scored.push({ entry: e, score: score })
        }

        // Blink's own things (Settings ...), ranked like apps
        for (const b of builtins) {
            const name = b.name.toLowerCase()
            let score = -1
            // A little above apps with the same match, so Blink's Settings comes first
            if (name.startsWith(q) || b.keys.some(k => k.startsWith(q))) score = 3.5
            else if (name.includes(q) || b.keys.some(k => k.includes(q))) score = 2
            if (score >= 0) scored.push({ entry: b, score: score })
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

    // Things that are part of Blink itself, shown like apps
    readonly property var builtins: [
        {
            name: "Settings",
            genericName: "Blink settings",
            icon: "preferences-system",
            id: "blink-settings",
            keys: ["blink", "settings", "preferences", "innstillinger", "wifi", "bluetooth", "sound", "bar", "dock"],
            execute: () => ShellState.settingsOpen = true
        }
    ]

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
        readonly property string paintKey: Tokens.themeName + Tokens.accent
        onPaintKeyChanged: requestPaint()
        property bool mirrored: false
        onMirroredChanged: requestPaint()
        onYChanged: requestPaint()
        y: launcher.fromBottom ? launcher.height - Tokens.frameT - 14 : SettingsService.topInset
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
            c.arc(mirrored ? 14 : 0, launcher.fromBottom ? 0 : 14, 14, 0, Math.PI * 2)
            c.fill()
        }
    }
    Fillet { x: box.x - 14; visible: Tokens.attached }
    Fillet { x: box.x + box.width; mirrored: true; visible: Tokens.attached }

    // The sheet: starts as the notch and grows down out of it
    Item {
        id: box
        // Soft shadow, so it floats over what is under it
        layer.enabled: Tokens.menuShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Tokens.shadowColor
            shadowBlur: Tokens.shadowBlur
            blurMax: 32
            shadowVerticalOffset: 2
        }
        // Glass: a floating box under the bar (like Spotlight) instead of growing out of the notch
        readonly property real topPad: launcher.fromBottom || Tokens.glass ? 12 : SettingsService.topInset + 6
        readonly property real fullW: 640
        readonly property real startW: 200
        readonly property real startH: launcher.fromBottom ? Tokens.frameT : Tokens.glass ? 12 : SettingsService.topInset + 8
        property real fullH: topPad + content.implicitHeight + (launcher.fromBottom ? Tokens.frameT + 8 : 8)
        Behavior on fullH { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        anchors.horizontalCenter: parent.horizontalCenter
        y: launcher.fromBottom ? launcher.height - height - (Tokens.glass ? Tokens.gap : 0)
         : Tokens.glass ? SettingsService.topInset + Tokens.gap : 0
        width: startW + (fullW - startW) * launcher.reveal
        height: startH + (fullH - startH) * Math.max(0, launcher.reveal)
        clip: true

        // Same black as the bar. The corners against the bar/frame hide, the free ones are round.
        Rectangle {
            anchors.fill: parent
            topLeftRadius: launcher.fromBottom || Tokens.glass ? Tokens.radiusXl : 0
            topRightRadius: launcher.fromBottom || Tokens.glass ? Tokens.radiusXl : 0
            bottomLeftRadius: launcher.fromBottom && !Tokens.glass ? 0 : Tokens.radiusXl
            bottomRightRadius: launcher.fromBottom && !Tokens.glass ? 0 : Tokens.radiusXl
            color: Tokens.barBg
        }
        GlassEdge { radius: Tokens.radiusXl; z: 10 }

        // Klikk inni boksen skal ikke lukke
        MouseArea {
            anchors.fill: parent
            onClicked: launcher.menuEntry = null
        }

        Column {
            id: content
            x: (box.width - box.fullW) / 2
            // From the bottom the content sits on the bottom edge. Measured from the
            // box's real (animated) height and the list's real height, so when the
            // list gets shorter as you type, the search field stays put and the box
            // shrinks down onto it, instead of the list sliding over the box.
            y: launcher.fromBottom ? box.height - content.implicitHeight - Tokens.frameT - 8 : box.topPad
            width: box.fullW
            opacity: Math.max(0, Math.min(1, (launcher.reveal - 0.35) / 0.5))
            // From the bottom the whole list is flipped: search field at the bottom,
            // best match right above it. Each row flips itself back so it reads normally.
            transform: Scale { origin.y: content.height / 2; yScale: launcher.fromBottom ? -1 : 1 }

            // ---------- Søkefelt ----------
            Item {
                id: searchRow
                width: parent.width
                height: 56
                transform: Scale { origin.y: searchRow.height / 2; yScale: launcher.fromBottom ? -1 : 1 }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spaceMd
                    anchors.rightMargin: Tokens.spaceMd
                    anchors.topMargin: Tokens.spaceXs
                    anchors.bottomMargin: Tokens.spaceXs
                    radius: Tokens.radiusLg
                    color: Tokens.fillIdle
                    border.color: Tokens.ink(0.06)
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
                    anchors.leftMargin: Tokens.spaceMd
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
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                            // From the bottom the list is upside down, so the arrows swap
                            const next = (event.key === Qt.Key_Down) !== launcher.fromBottom
                            launcher.selected = next
                                ? Math.min(launcher.selected + 1, launcher.results.length - 1)
                                : Math.max(launcher.selected - 1, 0)
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
                padding: Tokens.spaceSm
                spacing: 2
                visible: launcher.results.length > 0

                Repeater {
                    model: launcher.results

                    Rectangle {
                        id: resultRow
                        transform: Scale { origin.y: resultRow.height / 2; yScale: launcher.fromBottom ? -1 : 1 }
                        scale: resultRowMouse.pressed ? Tokens.pressScale : 1
                        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: index === launcher.selected

                        width: parent.width - 2 * Tokens.spaceSm
                        height: 44
                        radius: Tokens.radiusMd
                        color: isSelected ? Tokens.accent : (resultRowMouse.containsMouse ? Tokens.fillHover : "transparent")

                        Image {
                            id: appIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.spaceMd
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            sourceSize: Qt.size(56, 56)
                            source: Quickshell.iconPath(resultRow.modelData.icon ?? "", "application-x-executable")
                        }

                        Column {
                            anchors.left: appIcon.right
                            anchors.leftMargin: Tokens.spaceMd
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.spaceMd
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
            anchors.leftMargin: Tokens.spaceMd
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
