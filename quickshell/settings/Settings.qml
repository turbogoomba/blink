import QtQuick
import Quickshell
import Quickshell.Io
import "../bar"
import "../services"
import "../theme" as Theme

FloatingWindow {
    id: settingsWindow
    title: "Settings"
    implicitWidth: 1040
    implicitHeight: 700
    color: Theme.Tokens.windowBg

    property string activePanel: "wifi"
    property string query: ""
    property string pendingSection: ""

    // Line icons for the sidebar (24x24 SVG paths, drawn in the accent color)
    readonly property var glyphs: ({
        wifi:    "M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19h.01",
        bt:      "M7 7l10 10-5 4V3l5 4L7 17",
        sound:   "M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6M19 6a8 8 0 0 1 0 12",
        look:    "M12 3a9 9 0 1 0 0 18c1.5 0 2-1 2-2s-1-1.5-1-2.5 1-1.5 2-1.5h2a4 4 0 0 0 4-4c0-4.4-4-8-9-8zM7.5 11h.01M10 7.5h.01M15 7.5h.01",
        bell:    "M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 21h4",
        corner:  "M5 3l14 7-6 2-2 6z",
        notch:   "M3 6h18v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4zM9 11v1M15 11v1",
        windows: "M3 5h8v14H3zM13 5h8v6h-8zM13 13h8v6h-8z",
        cc:      "M4 7h10M18 7h2M4 17h2M10 17h10M16 5v4M8 15v4",
        search:  "M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14M20 20l-4-4",
        info:    "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18M12 11v5M12 8h.01"
    })

    // All pages, in sidebar order. `group` starts a new heading. ready = false shows "Coming soon".
    readonly property var panels: [
        { id: "wifi",          group: "Network",     label: "Wi-Fi",         glyph: "wifi",    sub: "Networks, school and work Wi-Fi",              source: "panels/WifiPanel.qml",      ready: true },
        { id: "bluetooth",     group: "",            label: "Bluetooth",     glyph: "bt",      sub: "Pair and connect your devices",                source: "panels/BluetoothPanel.qml", ready: true },
        { id: "sound",         group: "Devices",     label: "Sound",         glyph: "sound",   sub: "Speakers, headphones and microphones",         source: "panels/SoundPanel.qml",     ready: true },
        { id: "desktop",       group: "Personalize", label: "Appearance",    glyph: "look",    sub: "Bar, wallpaper, colors and the dock",          source: "panels/ShellPanel.qml",     ready: true, page: "desktop" },
        { id: "notifications", group: "",            label: "Notifications", glyph: "bell",    sub: "How and where notifications show up",          source: "panels/ShellPanel.qml",     ready: true, page: "notifications" },
        { id: "corners",       group: "Desktop",     label: "Hot Corners",   glyph: "corner",  sub: "Actions in the corners of the screen",         source: "panels/ShellPanel.qml",     ready: true, page: "corners" },
        { id: "controlcenter", group: "",            label: "Control Center", glyph: "cc",     sub: "Pick and order what the Control Center shows", source: "panels/ShellPanel.qml",     ready: true, page: "controlcenter" },
        { id: "notch",         group: "",            label: "Notch",         glyph: "notch",   sub: "What the notch shows",                         source: "panels/ShellPanel.qml",     ready: true, page: "notch" },
        { id: "hyprland",      group: "System",      label: "Windows",       glyph: "windows", sub: "How Hyprland places, spaces and animates windows", source: "panels/HyprlandPanel.qml",  ready: true },
        { id: "about",         group: "",            label: "About",         glyph: "info",    sub: "This computer, and how hard it is working",   source: "panels/AboutPanel.qml",     ready: true }
    ]
    readonly property var current: panels.find(p => p.id === activePanel)
    function panelLabel(id) { return (panels.find(p => p.id === id) ?? { label: "" }).label }

    // Search entries for the pages that are not built from HyprSettingsService.
    // Keep these in step with the titles on those pages.
    readonly property var shellIndex: [
        { panel: "desktop", label: "Theme", desc: "Blink, Paper, Fjord, Dusk, Forest or Ember for the whole shell", keys: "theme colors colours dark light mode paper fjord dusk forest ember" },
        { panel: "about", label: "About this computer", desc: "Processor, graphics, memory, storage and live usage", keys: "system info specs cpu gpu ram memory disk kernel version uptime hardware" },
        { panel: "wifi", label: "Wi-Fi", desc: "Turn Wi-Fi on or off and join a network", keys: "wireless internet network password eduroam username login school work" },
        { panel: "bluetooth", label: "Bluetooth", desc: "Turn Bluetooth on or off and pair devices", keys: "headphones devices pair" },
        { panel: "sound", label: "Output", desc: "Choose speakers or headphones and set the volume", keys: "volume audio speakers headphones" },
        { panel: "sound", label: "Input", desc: "Choose the microphone and its volume", keys: "microphone mic audio" },
        { panel: "notifications", label: "Do Not Disturb", desc: "Hide notification popups. They still go to the history.", keys: "dnd quiet" },
        { panel: "notifications", label: "Show notifications in", desc: "The notch, or cards that grow out of a corner of the frame", keys: "notification style corner cards popup position" },
        { panel: "notifications", label: "Show for", desc: "How long a notification stays before it goes to the history", keys: "notification timeout duration seconds" },
        { panel: "notifications", label: "Show message text", desc: "Off shows only the app and title, handy when sharing your screen", keys: "notification privacy body preview" },
        { panel: "notifications", label: "Notification history", desc: "Clear the notifications kept in the notch", keys: "notification history clear" },
        { panel: "desktop", label: "Wallpaper & slideshow", desc: "Pick a wallpaper or set the slideshow (Super+W)", keys: "background" },
        { panel: "desktop", label: "Match the wallpaper", desc: "Pick the accent color from the current wallpaper", keys: "accent color colour theme" },
        { panel: "desktop", label: "Startup animation", desc: "Plays once after you log in", keys: "boot login" },
        { panel: "desktop", label: "Night Shift", desc: "Warmer colors, easier on the eyes at night", keys: "night light blue light" },
        { panel: "desktop", label: "Warmth", desc: "How warm Night Shift makes the screen", keys: "night light temperature" },
        { panel: "desktop", label: "Side drawer", desc: "Graphs, favorite apps and folders on the edge opposite the dock", keys: "drawer" },
        { panel: "desktop", label: "Dock position", desc: "Bottom, left or right. The side drawer moves to the opposite edge", keys: "dock side" },
        { panel: "desktop", label: "Dock size", desc: "How big the dock icons are", keys: "dock icons" },
        { panel: "desktop", label: "Dock hiding", desc: "Out until a window covers it, or only when the mouse touches the edge", keys: "dock intellihide autohide hide" },
        { panel: "corners", label: "Hot corners", desc: "Move the mouse into a top corner to trigger an action", keys: "corner mouse" },
        { panel: "corners", label: "Delay", desc: "How long the mouse must stay in the corner", keys: "corner mouse" },
        { panel: "controlcenter", label: "Sections", desc: "Show, hide and reorder the parts of the Control Center", keys: "control center order layout customize hide sliders battery recording" },
        { panel: "controlcenter", label: "Toggles", desc: "Pick which quick toggles the Control Center shows", keys: "control center wifi bluetooth airplane modes windows night shift tiles" },
        { panel: "controlcenter", label: "Width", desc: "How wide the Control Center is", keys: "control center size compact wide" },
        { panel: "notch", label: "Show in the notch", desc: "Auto shows the timetable when a link is set, otherwise buses", keys: "timetable bus class" },
        { panel: "notch", label: "Timetable", desc: "Link to your class calendar for the next class countdown", keys: "calendar class link schedule" }
    ]

    function matches(text, words) {
        const t = text.toLowerCase()
        return words.every(w => t.indexOf(w) >= 0)
    }

    readonly property var queryWords: query.trim().toLowerCase().split(/\s+/).filter(w => w !== "")

    readonly property var hyprResults: queryWords.length === 0 ? [] : HyprSettingsService.options.filter(o =>
        matches(o.label + " " + o.desc + " hyprland " + HyprSettingsService.sectionLabel(o.section) + " " + o.key, queryWords))

    readonly property var shellResults: queryWords.length === 0 ? [] : shellIndex.filter(e =>
        matches(e.label + " " + e.desc + " " + e.keys + " " + panelLabel(e.panel), queryWords))

    function open(panelId, section) {
        query = ""
        searchInput.text = ""
        if (activePanel === panelId && section && panelLoader.item && panelLoader.item.scrollTo) {
            panelLoader.item.scrollTo(section)
            return
        }
        pendingSection = section ?? ""
        activePanel = panelId
    }

    // ---------- Who is using it (shown at the top of the sidebar) ----------
    property string fullName: ""
    property string hostName: ""
    readonly property string userName: Quickshell.env("USER") ?? ""
    readonly property string displayName: fullName !== "" ? fullName
        : userName.charAt(0).toUpperCase() + userName.slice(1)

    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; cat /etc/hostname']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim())
                settingsWindow.fullName = (lines[0] ?? "").split(" ")[0]
                settingsWindow.hostName = lines[1] ?? ""
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: searchInput.forceActiveFocus()
    }

    function soft(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ---------- Sidebar ----------
    Rectangle {
        id: sidebar
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: 260
        color: Theme.Tokens.sidebarBg

        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: 1
            color: Theme.Tokens.ink(0.06)
        }

        Flickable {
            anchors.fill: parent
            contentHeight: sideCol.implicitHeight + 32
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: sideCol
                x: 12
                y: 16
                width: parent.width - 24
                spacing: 2

                // Who
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: 14
                    color: Theme.Tokens.ink(0.04)

                    Rectangle {
                        id: avatar
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 20
                        color: Theme.Tokens.accent
                        Text {
                            anchors.centerIn: parent
                            text: settingsWindow.displayName.charAt(0)
                            color: Theme.Tokens.onAccent
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.Bold
                        }
                    }
                    Column {
                        anchors.left: avatar.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: settingsWindow.displayName
                            color: Theme.Tokens.textPrimary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: (settingsWindow.hostName || "Linux") + " · Blink"
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                Item { width: 1; height: 12 }

                // Search
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 10
                    color: Theme.Tokens.ink(0.06)
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Theme.Tokens.accent

                    LineIcon {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        d: settingsWindow.glyphs.search
                        tint: Theme.Tokens.textSecondary
                        size: 15
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: hint.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.Tokens.textPrimary
                        selectionColor: Theme.Tokens.accent
                        selectedTextColor: Theme.Tokens.onAccent
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: settingsWindow.query = text
                        Keys.onEscapePressed: text = ""

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: "Search settings"
                            color: Theme.Tokens.textSecondary
                            font: searchInput.font
                        }
                    }

                    // Ctrl F hint, or clear
                    Rectangle {
                        id: hint
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: hintText.implicitWidth + 12
                        height: 18
                        radius: 5
                        color: hintMouse.containsMouse && searchInput.text !== "" ? Theme.Tokens.fillHover : Theme.Tokens.ink(0.08)
                        Text {
                            id: hintText
                            anchors.centerIn: parent
                            text: searchInput.text === "" ? "Ctrl F" : "Clear"
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: hintMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: searchInput.text !== ""
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchInput.text = ""
                        }
                    }
                }

                Item { width: 1; height: 4 }

                Repeater {
                    model: settingsWindow.panels

                    delegate: Column {
                        id: navEntry
                        required property var modelData
                        readonly property bool selected: settingsWindow.query === "" && modelData.id === settingsWindow.activePanel
                        readonly property bool showSections: selected && modelData.id === "hyprland"
                        width: parent.width
                        spacing: 2
                        opacity: settingsWindow.query === "" ? 1 : 0.45
                        Behavior on opacity { NumberAnimation { duration: Theme.Tokens.durFast } }

                        // Group heading
                        Text {
                            visible: navEntry.modelData.group !== ""
                            leftPadding: 10
                            topPadding: 14
                            bottomPadding: 4
                            text: navEntry.modelData.group.toUpperCase()
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.9
                        }

                        Rectangle {
                            id: item
                            width: parent.width
                            height: 36
                            radius: 10
                            color: navEntry.selected ? settingsWindow.soft(Theme.Tokens.accent, 0.16)
                                 : itemMouse.containsMouse ? Theme.Tokens.fillIdle
                                 : "transparent"
                            scale: itemMouse.pressed ? Theme.Tokens.pressScale : 1
                            Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }

                            Rectangle {
                                id: iconBox
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                radius: 7
                                color: navEntry.selected ? Theme.Tokens.accent : Theme.Tokens.ink(0.07)
                                Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
                                LineIcon {
                                    anchors.centerIn: parent
                                    d: settingsWindow.glyphs[navEntry.modelData.glyph] ?? ""
                                    tint: navEntry.selected ? Theme.Tokens.onAccent : Theme.Tokens.accent
                                    size: 14
                                }
                            }

                            Text {
                                anchors.left: iconBox.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: navEntry.modelData.label
                                color: Theme.Tokens.textPrimary
                                font.family: Theme.Tokens.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: itemMouse
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: settingsWindow.open(navEntry.modelData.id)
                            }
                        }

                        // Hyprland sections, under the Windows entry while it is open
                        Repeater {
                            model: navEntry.showSections ? HyprSettingsService.sections : []
                            delegate: Rectangle {
                                id: subItem
                                required property var modelData
                                readonly property bool current: (panelLoader.item?.currentSection ?? "") === modelData.id
                                width: navEntry.width
                                height: 28
                                radius: 8
                                color: current ? Theme.Tokens.fillIdle : subMouse.containsMouse ? Theme.Tokens.fillHover : "transparent"
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 42
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: subItem.modelData.label
                                    color: subItem.current ? Theme.Tokens.textPrimary : Theme.Tokens.textSecondary
                                    font.family: Theme.Tokens.fontFamily
                                    font.pixelSize: 13
                                    font.weight: subItem.current ? Font.Medium : Font.Normal
                                }
                                MouseArea {
                                    id: subMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWindow.open("hyprland", subItem.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- Content ----------
    Item {
        anchors { top: parent.top; bottom: parent.bottom; left: sidebar.right; right: parent.right }

        // Page title and a line about what is on it
        Column {
            id: header
            visible: settingsWindow.query === ""
            x: 32
            y: 28
            width: parent.width - 64
            spacing: 4
            Text {
                text: settingsWindow.current?.label ?? ""
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }
            Text {
                text: settingsWindow.current?.sub ?? ""
                color: Theme.Tokens.textSecondary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 13
            }
        }

        Loader {
            id: panelLoader
            anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
            anchors.topMargin: -8
            visible: settingsWindow.query === ""
            source: settingsWindow.current?.ready ? settingsWindow.current.source : ""
            onLoaded: {
                if (settingsWindow.pendingSection !== "" && item.scrollTo) {
                    const s = settingsWindow.pendingSection
                    Qt.callLater(() => item.scrollTo(s))
                }
                settingsWindow.pendingSection = ""
            }
        }

        // Tells ShellPanel which page to show
        Binding {
            target: panelLoader.item
            property: "page"
            value: settingsWindow.current?.page ?? ""
            when: panelLoader.item !== null && (settingsWindow.current?.page ?? "") !== ""
        }

        Text {
            anchors.centerIn: parent
            visible: settingsWindow.query === "" && !(settingsWindow.current?.ready ?? false)
            text: (settingsWindow.current?.label ?? "") + "\nComing soon"
            horizontalAlignment: Text.AlignHCenter
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontTitle
        }

        // ---------- Search results ----------
        Flickable {
            id: results
            anchors.fill: parent
            visible: settingsWindow.query !== ""
            contentHeight: resCol.implicitHeight + 2 * resCol.y
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            readonly property int total: settingsWindow.hyprResults.length + settingsWindow.shellResults.length

            Column {
                id: resCol
                x: Theme.Tokens.spaceXl + 8
                y: Theme.Tokens.spaceXl + 8
                width: results.width - 2 * x
                spacing: Theme.Tokens.spaceMd

                Column {
                    width: parent.width
                    spacing: Theme.Tokens.spaceXs
                    Text {
                        text: "Search"
                        color: Theme.Tokens.textPrimary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: Theme.Tokens.fontLarge
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: results.total === 0 ? "Nothing matches “" + settingsWindow.query.trim() + "”."
                            : results.total + (results.total === 1 ? " setting matches" : " settings match")
                              + " “" + settingsWindow.query.trim() + "”. Change Hyprland settings right here, or open the page."
                        color: Theme.Tokens.textSecondary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: Theme.Tokens.fontBody
                    }
                }

                // Hyprland matches: the real controls
                Column {
                    visible: settingsWindow.hyprResults.length > 0
                    width: parent.width
                    spacing: Theme.Tokens.spaceSm
                    topPadding: Theme.Tokens.spaceSm

                    Text {
                        leftPadding: Theme.Tokens.spaceXs
                        text: "Hyprland"
                        color: Theme.Tokens.textSecondary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: Theme.Tokens.fontSmall
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                    }
                    Rectangle {
                        width: parent.width
                        height: hyprCol.implicitHeight
                        radius: Theme.Tokens.radiusLg
                        color: Theme.Tokens.fillIdle
                        clip: true
                        Column {
                            id: hyprCol
                            width: parent.width
                            Repeater {
                                model: settingsWindow.hyprResults
                                delegate: HyprRow {
                                    required property var modelData
                                    required property int index
                                    opt: modelData
                                    crumb: "Hyprland › " + HyprSettingsService.sectionLabel(modelData.section)
                                    divider: index < settingsWindow.hyprResults.length - 1
                                    onJump: settingsWindow.open("hyprland", modelData.section)
                                }
                            }
                        }
                    }
                }

                // Other pages: name, description and a way there
                Column {
                    visible: settingsWindow.shellResults.length > 0
                    width: parent.width
                    spacing: Theme.Tokens.spaceSm
                    topPadding: Theme.Tokens.spaceSm

                    Text {
                        leftPadding: Theme.Tokens.spaceXs
                        text: "Other pages"
                        color: Theme.Tokens.textSecondary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: Theme.Tokens.fontSmall
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                    }
                    Rectangle {
                        width: parent.width
                        height: shellCol.implicitHeight
                        radius: Theme.Tokens.radiusLg
                        color: Theme.Tokens.fillIdle
                        clip: true
                        Column {
                            id: shellCol
                            width: parent.width
                            Repeater {
                                model: settingsWindow.shellResults
                                delegate: Rectangle {
                                    id: shellRow
                                    required property var modelData
                                    required property int index
                                    width: shellCol.width
                                    height: Math.max(56, shellText.implicitHeight + 2 * Theme.Tokens.spaceMd)
                                    color: shellMouse.containsMouse ? Theme.Tokens.fillIdle : "transparent"

                                    Column {
                                        id: shellText
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.Tokens.spaceLg
                                        anchors.right: shellArrow.left
                                        anchors.rightMargin: Theme.Tokens.spaceLg
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: shellRow.modelData.label
                                            color: Theme.Tokens.textPrimary
                                            font.family: Theme.Tokens.fontFamily
                                            font.pixelSize: Theme.Tokens.fontBody
                                            font.weight: Font.Medium
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            text: shellRow.modelData.desc
                                            color: Theme.Tokens.textSecondary
                                            font.family: Theme.Tokens.fontFamily
                                            font.pixelSize: Theme.Tokens.fontSmall
                                        }
                                        Text {
                                            text: settingsWindow.panelLabel(shellRow.modelData.panel)
                                            color: Theme.Tokens.textSecondary
                                            opacity: 0.7
                                            font.family: Theme.Tokens.fontFamily
                                            font.pixelSize: Theme.Tokens.fontSmall
                                        }
                                    }
                                    Text {
                                        id: shellArrow
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.Tokens.spaceLg + 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "›"
                                        color: Theme.Tokens.textSecondary
                                        font.pixelSize: Theme.Tokens.fontTitle
                                    }
                                    Rectangle {
                                        visible: shellRow.index < settingsWindow.shellResults.length - 1
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.Tokens.spaceLg
                                        anchors.right: parent.right
                                        height: 1
                                        color: Theme.Tokens.divider
                                    }
                                    MouseArea {
                                        id: shellMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsWindow.open(shellRow.modelData.panel)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
