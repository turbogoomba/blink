import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "../../theme" as Theme

// One file for the shell's own settings pages.
// Settings.qml sets `page` to: "desktop", "corners", "notch" or "notifications".
Flickable {
    id: panel
    property string page: "desktop"

    contentHeight: col.implicitHeight + 56
    clip: true

    readonly property var cornerActions: [
        { value: "mission",       label: "Mission Control" },
        { value: "controlcenter", label: "Control Center" },
        { value: "launcher",      label: "Launcher" },
        { value: "wallpaper",     label: "Wallpaper" },
        { value: "none",          label: "Nothing" }
    ]

    Process { id: ipc }

    // ================= Components =================

    component SectionTitle: Text {
        width: col.width
        topPadding: Theme.Tokens.spaceSm
        color: Theme.Tokens.textSecondary
        font.family: Theme.Tokens.fontFamily
        font.pixelSize: Theme.Tokens.fontBody
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    // Rounded card that stacks rows with dividers
    component Group: Rectangle {
        default property alias content: inner.data
        width: col.width
        height: inner.implicitHeight
        radius: Theme.Tokens.radiusMd
        color: Theme.Tokens.fillIdle
        border.color: "transparent"
        border.width: 1
        clip: true

        Column {
            id: inner
            width: parent.width
        }
    }

    // Base row: title + optional subtitle on the left, control on the right
    component SettingRow: Item {
        id: row
        property string title: ""
        property string subtitle: ""
        property bool divider: true
        default property alias control: slot.data

        width: col.width
        height: subtitle !== "" ? 56 : 46

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.Tokens.spaceLg
            anchors.right: slot.left
            anchors.rightMargin: Theme.Tokens.spaceMd
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: row.title
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: row.subtitle !== ""
                text: row.subtitle
                color: Theme.Tokens.textSecondary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontSmall
                elide: Text.ElideRight
            }
        }

        Item {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: Theme.Tokens.spaceLg
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }

        Rectangle {
            visible: row.divider
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: Theme.Tokens.spaceLg
            anchors.right: parent.right
            height: 1
            color: Theme.Tokens.divider
        }
    }

    // Mac-style switch
    component Toggle: Rectangle {
        id: sw
        scale: swMouse.pressed ? Theme.Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
        property bool checked: false
        property var apply: function(v) {}

        width: 38
        height: 22
        radius: 11
        color: checked ? Theme.Tokens.accent : Theme.Tokens.fillStrong
        Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }

        Rectangle {
            width: 18
            height: 18
            radius: 9
            y: 2
            x: sw.checked ? sw.width - width - 2 : 2
            color: "white"
            Behavior on x { NumberAnimation { duration: Theme.Tokens.durNormal; easing.type: Theme.Tokens.easeMove } }
        }

        MouseArea {
            id: swMouse
            hoverEnabled: true
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.apply(!sw.checked)
        }
    }

    // Segmented picker
    component Segments: Rectangle {
        id: seg
        property var options: []          // [{ value, label }]
        property string current: ""
        property var apply: function(v) {}

        width: segRow.implicitWidth + 4
        height: 26
        radius: Theme.Tokens.radiusSm
        color: Theme.Tokens.fillIdle
        border.color: "transparent"
        border.width: 1

        Row {
            id: segRow
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: seg.options

                delegate: Rectangle {
                    id: opt
                    scale: optMouse.pressed ? Theme.Tokens.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                    required property var modelData
                    readonly property bool selected: modelData.value === seg.current

                    width: optText.implicitWidth + 20
                    height: 22
                    radius: Theme.Tokens.radiusSm
                    color: selected ? Theme.Tokens.accent
                         : optMouse.containsMouse ? Theme.Tokens.fillHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }

                    Text {
                        id: optText
                        anchors.centerIn: parent
                        text: opt.modelData.label
                        color: opt.selected ? Theme.Tokens.onAccent : Theme.Tokens.textPrimary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: Theme.Tokens.fontBody
                    }

                    MouseArea {
                        id: optMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.apply(opt.modelData.value)
                    }
                }
            }
        }
    }

    // Slider with value text
    component ValueSlider: Item {
        id: sl
        property real from: 0
        property real to: 100
        property real step: 1
        property real value: 0
        property string suffix: ""
        property var apply: function(v) {}

        width: 240
        height: 22

        readonly property real frac: (value - from) / (to - from)

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: valText.left
            anchors.rightMargin: Theme.Tokens.spaceMd
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Theme.Tokens.fillStrong

            Rectangle {
                width: parent.width * sl.frac
                height: parent.height
                radius: 2
                color: Theme.Tokens.accent
            }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                x: parent.width * sl.frac - width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                scale: drag.pressed ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                function set(mx) {
                    const f = Math.max(0, Math.min(1, (mx - 8) / track.width))
                    const v = sl.from + Math.round(f * (sl.to - sl.from) / sl.step) * sl.step
                    if (v !== sl.value) sl.apply(v)
                }
                onPressed: mouse => set(mouse.x)
                onPositionChanged: mouse => { if (pressed) set(mouse.x) }
            }
        }

        Text {
            id: valText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            horizontalAlignment: Text.AlignRight
            text: sl.value + sl.suffix
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontBody
        }
    }

    // Small button
    component PushButton: Rectangle {
        id: btn
        property string text: ""
        property var apply: function() {}

        width: btnText.implicitWidth + 24
        height: 26
        radius: Theme.Tokens.radiusSm
        color: btnMouse.pressed ? Qt.darker(Theme.Tokens.accent, 1.2) : Theme.Tokens.accent
        scale: btnMouse.pressed ? Theme.Tokens.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.text
            color: Theme.Tokens.onAccent
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontBody
            font.weight: Font.Medium
        }

        MouseArea {
            id: btnMouse
            hoverEnabled: true
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.apply()
        }
    }

    // Single-line text field, saves on Enter or when focus leaves
    component Field: Rectangle {
        id: fld
        property string value: ""
        property string placeholder: ""
        property var apply: function(v) {}

        width: col.width - 32
        height: 30
        radius: Theme.Tokens.radiusSm
        color: Theme.Tokens.fillIdle
        border.color: input.activeFocus ? Theme.Tokens.accent : "transparent"
        border.width: 1

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: Theme.Tokens.spaceMd
            anchors.rightMargin: Theme.Tokens.spaceMd
            verticalAlignment: TextInput.AlignVCenter
            text: fld.value
            clip: true
            color: Theme.Tokens.textPrimary
            selectionColor: Theme.Tokens.accent
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontBody
            onAccepted: fld.apply(text)
            onActiveFocusChanged: if (!activeFocus) fld.apply(text)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: fld.placeholder
                color: Theme.Tokens.textSecondary
                font: input.font
            }
        }
    }

    // ================= Pages =================

    Column {
        id: col
        x: 28
        y: 28
        width: panel.width - 56
        spacing: Theme.Tokens.spaceMd

        Text {
            text: panel.page === "desktop" ? "Display & Dock"
                : panel.page === "corners" ? "Hot Corners"
                : panel.page === "notch" ? "Notch"
                : "Notifications"
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontLarge
            font.weight: Font.DemiBold
            bottomPadding: Theme.Tokens.spaceSm
        }

        // ---------- Desktop & Dock ----------
        Column {
            visible: panel.page === "desktop"
            width: col.width
            spacing: Theme.Tokens.spaceMd

            SectionTitle { text: "Wallpaper" }
            Group {
                SettingRow {
                    title: "Wallpaper & slideshow"
                    subtitle: "Pick a wallpaper or set the slideshow (Super+W)"
                    divider: false
                    PushButton {
                        text: "Open Picker"
                        apply: function() {
                            ipc.command = ["qs", "-p", Quickshell.shellDir, "ipc", "call", "wallpaper", "toggle"]
                            ipc.running = true
                        }
                    }
                }
            }

            SectionTitle { text: "Accent color" }
            Group {
                SettingRow {
                    title: "Match the wallpaper"
                    subtitle: "Pick the accent color from the current wallpaper"
                    divider: false
                    Toggle {
                        checked: SettingsService.accentFromWallpaper
                        apply: function(v) { SettingsService.accentFromWallpaper = v }
                    }
                }
            }

            SectionTitle { text: "Startup" }
            Group {
                SettingRow {
                    title: "Startup animation"
                    subtitle: "Plays once after you log in"
                    divider: false
                    Row {
                        spacing: Theme.Tokens.spaceMd
                        PushButton {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Play"
                            apply: function() { BootService.play() }
                        }
                        Toggle {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsService.bootAnimation
                            apply: function(v) { SettingsService.bootAnimation = v }
                        }
                    }
                }
            }

            SectionTitle { text: "Frame visualizer" }
            Group {
                Item {
                    width: col.width
                    height: 46
                    Segments {
                        anchors.centerIn: parent
                        options: [
                            { value: "off", label: "Off" },
                            { value: "glow", label: "Glow" },
                            { value: "bars", label: "Bars" },
                            { value: "both", label: "Both" }
                        ]
                        current: SettingsService.frameViz
                        apply: function(v) { SettingsService.frameViz = v }
                    }
                }
            }

            SectionTitle { text: "Night Shift" }
            Group {
                SettingRow {
                    title: "Night Shift"
                    subtitle: NightLightService.available ? "Warmer colors, easier on the eyes at night"
                        : "Install hyprsunset to use this"
                    Toggle {
                        checked: SettingsService.nightLight
                        apply: function(v) { SettingsService.nightLight = v }
                    }
                }
                SettingRow {
                    title: "Warmth"
                    subtitle: "Lower is warmer"
                    divider: false
                    ValueSlider {
                        from: 2500; to: 6000; step: 100
                        value: SettingsService.nightTemp
                        suffix: " K"
                        apply: function(v) { SettingsService.nightTemp = v }
                    }
                }
            }

            SectionTitle { text: "Dock" }
            Group {
                SettingRow {
                    title: "Side drawer"
                    subtitle: "Graphs, favorite apps and folders on the edge opposite the dock"
                    Toggle {
                        checked: SettingsService.drawerEnabled
                        apply: function(v) { SettingsService.drawerEnabled = v }
                    }
                }
                SettingRow {
                    title: "Position"
                    subtitle: "The side drawer moves to the opposite edge"
                    Segments {
                        options: [
                            { value: "left", label: "Left" },
                            { value: "bottom", label: "Bottom" },
                            { value: "right", label: "Right" }
                        ]
                        current: SettingsService.dockPosition
                        apply: function(v) { SettingsService.dockPosition = v }
                    }
                }
                SettingRow {
                    title: "Size"
                    divider: false
                    ValueSlider {
                        from: 40; to: 80; step: 2
                        value: SettingsService.dockSize
                        suffix: " px"
                        apply: function(v) { SettingsService.dockSize = v }
                    }
                }
            }
        }

        // ---------- Hot Corners ----------
        Column {
            visible: panel.page === "corners"
            width: col.width
            spacing: Theme.Tokens.spaceMd

            Group {
                SettingRow {
                    title: "Hot corners"
                    subtitle: "Move the mouse into a top corner to trigger an action"
                    divider: false
                    Toggle {
                        checked: SettingsService.hotCornersEnabled
                        apply: function(v) { SettingsService.hotCornersEnabled = v }
                    }
                }
            }

            SectionTitle { text: "Top left" }
            Group {
                opacity: SettingsService.hotCornersEnabled ? 1 : 0.4
                Item {
                    width: col.width
                    height: 46
                    Segments {
                        anchors.centerIn: parent
                        options: panel.cornerActions
                        current: SettingsService.cornerTopLeft
                        apply: function(v) { SettingsService.cornerTopLeft = v }
                    }
                }
            }

            SectionTitle { text: "Top right" }
            Group {
                opacity: SettingsService.hotCornersEnabled ? 1 : 0.4
                Item {
                    width: col.width
                    height: 46
                    Segments {
                        anchors.centerIn: parent
                        options: panel.cornerActions
                        current: SettingsService.cornerTopRight
                        apply: function(v) { SettingsService.cornerTopRight = v }
                    }
                }
            }

            SectionTitle { text: "Timing" }
            Group {
                opacity: SettingsService.hotCornersEnabled ? 1 : 0.4
                SettingRow {
                    title: "Delay"
                    subtitle: "How long the mouse must stay in the corner"
                    divider: false
                    ValueSlider {
                        from: 0; to: 1000; step: 50
                        value: SettingsService.cornerDelay
                        suffix: " ms"
                        apply: function(v) { SettingsService.cornerDelay = v }
                    }
                }
            }
        }

        // ---------- Notch ----------
        Column {
            visible: panel.page === "notch"
            width: col.width
            spacing: Theme.Tokens.spaceMd

            SectionTitle { text: "Right side of the open notch" }
            Group {
                SettingRow {
                    title: "Show"
                    subtitle: "Auto shows the timetable when a link is set, otherwise buses"
                    divider: false
                    Segments {
                        options: [
                            { value: "auto",      label: "Auto" },
                            { value: "timetable", label: "Timetable" },
                            { value: "buses",     label: "Buses" }
                        ]
                        current: SettingsService.notchRight
                        apply: function(v) { SettingsService.notchRight = v }
                    }
                }
            }

            SectionTitle { text: "Timetable" }
            Group {
                Item {
                    width: col.width
                    height: 92

                    Column {
                        x: 16
                        y: 12
                        spacing: Theme.Tokens.spaceSm

                        Text {
                            text: "Calendar link (.ics from Mine studier). Press Enter to save."
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: Theme.Tokens.fontSmall
                        }
                        Field {
                            value: SettingsService.timetableUrl
                            placeholder: TimetableService.fileUrl !== "" ? "Using link from timetable-url file" : "https://..."
                            apply: function(v) {
                                if (v.trim() !== SettingsService.timetableUrl) SettingsService.timetableUrl = v.trim()
                            }
                        }
                    }
                }
                SettingRow {
                    title: "Status"
                    subtitle: !TimetableService.enabled ? "Not shown (buses are active)"
                        : TimetableService.error !== "" ? TimetableService.error
                        : TimetableService.upcoming.length + " upcoming classes loaded"
                    divider: false
                    PushButton {
                        text: "Refresh"
                        apply: function() { TimetableService.refresh() }
                    }
                }
            }
        }

        // ---------- Notifications ----------
        Column {
            visible: panel.page === "notifications"
            width: col.width
            spacing: Theme.Tokens.spaceMd

            SectionTitle { text: "Style" }
            Group {
                SettingRow {
                    title: "Show in"
                    subtitle: "The notch shows one at a time. Corner cards grow out of the frame and stack"
                    Segments {
                        options: [{ value: "notch", label: "Notch" }, { value: "corner", label: "Corner cards" }]
                        current: SettingsService.notifStyle
                        apply: function(v) { SettingsService.notifStyle = v }
                    }
                }
                SettingRow {
                    opacity: SettingsService.notifStyle === "corner" ? 1 : 0.4
                    title: "Corner"
                    subtitle: "Which top corner the cards grow out of"
                    Segments {
                        options: [{ value: "left", label: "Left" }, { value: "right", label: "Right" }]
                        current: SettingsService.notifCorner
                        apply: function(v) { SettingsService.notifCorner = v }
                    }
                }
                SettingRow {
                    opacity: SettingsService.notifStyle === "corner" ? 1 : 0.4
                    title: "Cards on screen"
                    subtitle: "Older ones stack behind the newest"
                    ValueSlider {
                        from: 1; to: 5; step: 1
                        value: SettingsService.notifMax
                        apply: function(v) { SettingsService.notifMax = v }
                    }
                }
                SettingRow {
                    title: "Show for"
                    subtitle: "How long a notification stays before it goes to the history"
                    divider: false
                    ValueSlider {
                        from: 3; to: 15; step: 1
                        value: SettingsService.notifTimeout
                        suffix: " s"
                        apply: function(v) { SettingsService.notifTimeout = v }
                    }
                }
            }

            SectionTitle { text: "Behavior" }
            Group {
                SettingRow {
                    title: "Do Not Disturb"
                    subtitle: "Hide notification popups. They still go to the history."
                    Toggle {
                        checked: ShellState.doNotDisturb
                        apply: function(v) { ShellState.mode = v ? "dnd" : "" }
                    }
                }
                SettingRow {
                    title: "Show message text"
                    subtitle: "Off shows only the app and title, handy when sharing your screen"
                    Toggle {
                        checked: SettingsService.notifShowBody
                        apply: function(v) { SettingsService.notifShowBody = v }
                    }
                }
                SettingRow {
                    title: "History"
                    subtitle: NotificationService.history.length === 0 ? "Empty"
                        : NotificationService.history.length + " notifications, shown in the notch"
                    divider: false
                    PushButton {
                        text: "Clear"
                        apply: function() { NotificationService.clearAll() }
                    }
                }
            }
        }
    }
}
