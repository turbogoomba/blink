import QtQuick
import Quickshell
import "../services"
import "../theme" as Theme

FloatingWindow {
    id: settingsWindow
    title: "Settings"
    implicitWidth: 960
    implicitHeight: 640
    color: Theme.Tokens.barBg

    property string activePanel: "wifi"
    property string query: ""
    property string pendingSection: ""

    // All pages. ready = false shows "Coming soon".
    readonly property var panels: [
        { id: "wifi",          label: "Wi-Fi",          icon: "network-wireless-symbolic",        source: "panels/WifiPanel.qml",      ready: true },
        { id: "bluetooth",     label: "Bluetooth",      icon: "bluetooth-active-symbolic",        source: "panels/BluetoothPanel.qml", ready: true },
        { id: "sound",         label: "Sound",          icon: "audio-volume-high-symbolic",       source: "panels/SoundPanel.qml",     ready: true },
        { id: "notifications", label: "Notifications",  icon: "preferences-system-notifications", source: "panels/ShellPanel.qml",     ready: true, page: "notifications" },
        { id: "desktop",       label: "Display & Dock", icon: "preferences-desktop-wallpaper",    source: "panels/ShellPanel.qml",     ready: true, page: "desktop" },
        { id: "corners",       label: "Hot Corners",    icon: "input-mouse",                      source: "panels/ShellPanel.qml",     ready: true, page: "corners" },
        { id: "notch",         label: "Notch",          icon: "x-office-calendar",                source: "panels/ShellPanel.qml",     ready: true, page: "notch" },
        { id: "hyprland",      label: "Hyprland",       icon: "preferences-system-windows",       source: "panels/HyprlandPanel.qml",  ready: true }
    ]
    readonly property var current: panels.find(p => p.id === activePanel)
    function panelLabel(id) { return (panels.find(p => p.id === id) ?? { label: "" }).label }

    // Search entries for the pages that are not built from HyprSettingsService.
    // Keep these in step with the titles on those pages.
    readonly property var shellIndex: [
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
        { panel: "corners", label: "Hot corners", desc: "Move the mouse into a top corner to trigger an action", keys: "corner mouse" },
        { panel: "corners", label: "Delay", desc: "How long the mouse must stay in the corner", keys: "corner mouse" },
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

    // ---------- Sidebar ----------
    Rectangle {
        id: sidebar
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: 220
        color: Theme.Tokens.barBg

        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: 1
            color: Theme.Tokens.divider
        }

        Column {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: Theme.Tokens.spaceXl
            anchors.leftMargin: Theme.Tokens.spaceMd
            anchors.rightMargin: Theme.Tokens.spaceMd
            spacing: 2

            // Search
            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.Tokens.radiusMd
                color: Theme.Tokens.fillIdle
                border.width: searchInput.activeFocus ? 1 : 0
                border.color: Theme.Tokens.accent

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.Tokens.spaceSm + 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌕"
                    color: Theme.Tokens.textSecondary
                    font.pixelSize: Theme.Tokens.fontTitle
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: Theme.Tokens.spaceSm
                    anchors.right: clearBtn.left
                    anchors.rightMargin: Theme.Tokens.spaceXs
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.Tokens.textPrimary
                    selectionColor: Theme.Tokens.accent
                    selectedTextColor: Theme.Tokens.onAccent
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: Theme.Tokens.fontBody
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

                Text {
                    id: clearBtn
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.Tokens.spaceSm
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text !== ""
                    width: visible ? implicitWidth : 0
                    text: "✕"
                    color: clearMouse.containsMouse ? Theme.Tokens.textPrimary : Theme.Tokens.textSecondary
                    font.pixelSize: Theme.Tokens.fontSmall
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }
                }
            }

            Item { width: 1; height: Theme.Tokens.spaceMd - 2 }

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

                    Rectangle {
                        id: item
                        width: parent.width
                        height: 32
                        radius: Theme.Tokens.radiusSm
                        color: navEntry.selected ? Theme.Tokens.accent
                             : itemMouse.containsMouse ? Theme.Tokens.fillHover
                             : "transparent"
                        scale: itemMouse.pressed ? Theme.Tokens.pressScale : 1
                        Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }

                        Image {
                            id: itemIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.Tokens.spaceMd
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            sourceSize: Qt.size(32, 32)
                            source: Quickshell.iconPath(navEntry.modelData.icon, "application-x-executable")
                        }

                        Text {
                            anchors.left: itemIcon.right
                            anchors.leftMargin: Theme.Tokens.spaceMd
                            anchors.verticalCenter: parent.verticalCenter
                            text: navEntry.modelData.label
                            color: navEntry.selected ? Theme.Tokens.onAccent : Theme.Tokens.textPrimary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: Theme.Tokens.fontBody
                            font.weight: navEntry.selected ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: itemMouse
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: settingsWindow.open(navEntry.modelData.id)
                        }
                    }

                    // Hyprland sections, under the Hyprland entry while it is open
                    Repeater {
                        model: navEntry.showSections ? HyprSettingsService.sections : []
                        delegate: Rectangle {
                            id: subItem
                            required property var modelData
                            readonly property bool current: (panelLoader.item?.currentSection ?? "") === modelData.id
                            width: navEntry.width
                            height: 28
                            radius: Theme.Tokens.radiusSm
                            color: current ? Theme.Tokens.fillIdle : subMouse.containsMouse ? Theme.Tokens.fillHover : "transparent"
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 40
                                anchors.verticalCenter: parent.verticalCenter
                                text: subItem.modelData.label
                                color: subItem.current ? Theme.Tokens.textPrimary : Theme.Tokens.textSecondary
                                font.family: Theme.Tokens.fontFamily
                                font.pixelSize: Theme.Tokens.fontBody
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

    // ---------- Content ----------
    Item {
        anchors { top: parent.top; bottom: parent.bottom; left: sidebar.right; right: parent.right }

        Loader {
            id: panelLoader
            anchors.fill: parent
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
