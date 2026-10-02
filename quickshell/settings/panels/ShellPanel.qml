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
        topPadding: 8
        color: Theme.Tokens.textSecondary
        font.family: Theme.Tokens.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    // Rounded card that stacks rows with dividers
    component Group: Rectangle {
        default property alias content: inner.data
        width: col.width
        height: inner.implicitHeight
        radius: 10
        color: Theme.Tokens.surface
        border.color: Theme.Tokens.border
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
            anchors.leftMargin: 16
            anchors.right: slot.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: row.title
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: row.subtitle !== ""
                text: row.subtitle
                color: Theme.Tokens.textSecondary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Item {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }

        Rectangle {
            visible: row.divider
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            height: 1
            color: Theme.Tokens.border
        }
    }

    // Mac-style switch
    component Toggle: Rectangle {
        id: sw
        property bool checked: false
        property var apply: function(v) {}

        width: 38
        height: 22
        radius: 11
        color: checked ? Theme.Tokens.accent : Theme.Tokens.border
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: 18
            height: 18
            radius: 9
            y: 2
            x: sw.checked ? sw.width - width - 2 : 2
            color: "white"
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
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
        radius: 7
        color: Theme.Tokens.surfaceAlt
        border.color: Theme.Tokens.border
        border.width: 1

        Row {
            id: segRow
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: seg.options

                delegate: Rectangle {
                    id: opt
                    required property var modelData
                    readonly property bool selected: modelData.value === seg.current

                    width: optText.implicitWidth + 20
                    height: 22
                    radius: 5
                    color: selected ? Theme.Tokens.accent
                         : optMouse.containsMouse ? Theme.Tokens.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: optText
                        anchors.centerIn: parent
                        text: opt.modelData.label
                        color: opt.selected ? "white" : Theme.Tokens.textPrimary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: 12
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
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Theme.Tokens.border

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
                Behavior on scale { NumberAnimation { duration: 120 } }
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
            font.pixelSize: 12
        }
    }

    // Small button
    component PushButton: Rectangle {
        id: btn
        property string text: ""
        property var apply: function() {}

        width: btnText.implicitWidth + 24
        height: 26
        radius: 7
        color: btnMouse.pressed ? Qt.darker(Theme.Tokens.accent, 1.2) : Theme.Tokens.accent
        scale: btnMouse.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.text
            color: "white"
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: btnMouse
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
        radius: 7
        color: Theme.Tokens.surfaceAlt
        border.color: input.activeFocus ? Theme.Tokens.accent : Theme.Tokens.border
        border.width: 1

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            text: fld.value
            clip: true
            color: Theme.Tokens.textPrimary
            selectionColor: Theme.Tokens.accent
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 12
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
        spacing: 10

        Text {
            text: panel.page === "desktop" ? "Desktop & Dock"
                : panel.page === "corners" ? "Hot Corners"
                : panel.page === "notch" ? "Notch"
                : "Notifications"
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 22
            font.weight: Font.DemiBold
            bottomPadding: 6
        }

        // ---------- Desktop & Dock ----------
        Column {
            visible: panel.page === "desktop"
            width: col.width
            spacing: 10

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

            SectionTitle { text: "Dock" }
            Group {
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
            spacing: 10

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
            spacing: 10

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
                        spacing: 8

                        Text {
                            text: "Calendar link (.ics from Mine studier). Press Enter to save."
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 11
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
            spacing: 10

            Group {
                SettingRow {
                    title: "Do Not Disturb"
                    subtitle: "Hide notification popups. They still go to the history."
                    divider: false
                    Toggle {
                        checked: ShellState.doNotDisturb
                        apply: function(v) { ShellState.doNotDisturb = v }
                    }
                }
            }
        }
    }
}
