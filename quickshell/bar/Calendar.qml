import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Month calendar that grows out of the bar (click the clock).
// Same sheet shape as the Control Center. Shows classes from the timetable.
PanelWindow {
    id: cal
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Open on the monitor you are using (matters with two screens)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "calendar"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool open: ShellState.calendarOpen
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: cal.open ? 440 : 240
            easing.type: cal.open ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: 0.9
        }
    }
    visible: open || reveal > 0.01

    function close() { ShellState.calendarOpen = false }

    // Only one of calendar / control center at a time
    Connections {
        target: ShellState
        function onCalendarOpenChanged() {
            if (ShellState.calendarOpen) {
                ShellState.controlCenterOpen = false
                cal.today = new Date()
                cal.viewYear = cal.today.getFullYear()
                cal.viewMonth = cal.today.getMonth()
                cal.selected = cal.today
                sheet.forceActiveFocus()
            }
        }
        function onControlCenterOpenChanged() {
            if (ShellState.controlCenterOpen) ShellState.calendarOpen = false
        }
    }

    // ---------- Dates ----------
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property date selected: today

    Timer {
        interval: 60000
        running: cal.open
        repeat: true
        onTriggered: cal.today = new Date()
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }

    function shiftMonth(n) {
        let m = viewMonth + n
        let y = viewYear
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        viewMonth = m
        viewYear = y
    }

    // 6 weeks x 7 days, Monday first
    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1)
        const offset = (first.getDay() + 6) % 7
        const start = new Date(viewYear, viewMonth, 1 - offset)
        const events = TimetableService.events
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            out.push({
                date: d,
                day: d.getDate(),
                inMonth: d.getMonth() === viewMonth,
                isToday: sameDay(d, today),
                isSelected: sameDay(d, selected),
                hasEvent: events.some(e => sameDay(e.start, d)),
                pick: () => { cal.selected = d }
            })
        }
        return out
    }

    readonly property var weekNumbers: {
        const out = []
        for (let r = 0; r < 6; r++) out.push(isoWeek(cells[r * 7].date))
        return out
    }

    readonly property var dayEvents:
        TimetableService.events.filter(e => sameDay(e.start, selected)).slice(0, 4)

    // ---------- Window ----------
    MouseArea {
        anchors.fill: parent
        onClicked: cal.close()
    }

    component Fillet: Canvas {
        width: 14
        height: 14
        opacity: Math.min(1, cal.reveal * 4)
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(0, 14, 14, 0, Math.PI * 2)
            c.fill()
        }
    }
    Fillet { x: sheet.x - 14; y: sheet.y }
    Fillet { x: sheet.x + sheet.width - 14; y: sheet.y + sheet.height; visible: sheet.height > 1 }

    component NavButton: Rectangle {
        id: nb
        property string glyph: ""
        signal clicked()
        width: 26
        height: 26
        radius: 13
        color: nbMouse.containsMouse ? Tokens.fillHover : "transparent"
        Text {
            anchors.centerIn: parent
            text: nb.glyph
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontBody
        }
        MouseArea {
            id: nbMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: nb.clicked()
        }
    }

    Item {
        id: sheet
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Tokens.barHeight
        anchors.rightMargin: 6
        width: 300
        readonly property real fullHeight: body.implicitHeight + 28
        height: fullHeight * Math.max(0, cal.reveal)
        clip: true
        focus: true
        Keys.onEscapePressed: cal.close()
        Keys.onLeftPressed: cal.shiftMonth(-1)
        Keys.onRightPressed: cal.shiftMonth(1)

        Rectangle {
            x: 0
            y: -20
            width: parent.width + 20
            height: parent.height + 20
            radius: Tokens.radiusXl
            color: Tokens.barBg
        }

        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: 16
            y: 12
            width: parent.width - 32
            spacing: 10
            opacity: Math.max(0, Math.min(1, (cal.reveal - 0.3) / 0.5))

            // ---------- Month header ----------
            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(new Date(cal.viewYear, cal.viewMonth, 1), "MMMM yyyy")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontTitle
                    font.weight: Font.DemiBold
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    NavButton { glyph: "‹"; onClicked: cal.shiftMonth(-1) }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: todayText.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: todayMouse.containsMouse ? Tokens.fillHover : Tokens.fillIdle
                        Text {
                            id: todayText
                            anchors.centerIn: parent
                            text: "Today"
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSmall
                        }
                        MouseArea {
                            id: todayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                cal.viewYear = cal.today.getFullYear()
                                cal.viewMonth = cal.today.getMonth()
                                cal.selected = cal.today
                            }
                        }
                    }
                    NavButton { glyph: "›"; onClicked: cal.shiftMonth(1) }
                }
            }

            // ---------- Grid with week numbers ----------
            Row {
                spacing: 4

                // Week numbers
                Column {
                    spacing: 0
                    Text {
                        width: 22
                        height: 22
                        text: "W"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Tokens.textSecondary
                        opacity: 0.6
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSmall
                    }
                    Repeater {
                        model: cal.weekNumbers
                        Text {
                            required property var modelData
                            width: 22
                            height: 34
                            text: modelData
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: Tokens.textSecondary
                            opacity: 0.6
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSmall
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                Column {
                    spacing: 0

                    // Weekday letters
                    Row {
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                required property var modelData
                                required property int index
                                width: 34
                                height: 22
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: index >= 5 ? Tokens.textSecondary : Tokens.textPrimary
                                opacity: 0.8
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSmall
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Grid {
                        columns: 7

                        Repeater {
                            model: cal.cells

                            Item {
                                id: dayCell
                                required property var modelData
                                width: 34
                                height: 34

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: dayCell.modelData.isToday ? Tokens.accent
                                         : dayCell.modelData.isSelected ? Tokens.fillHover
                                         : dayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08)
                                         : "transparent"
                                    Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayCell.modelData.day
                                    color: dayCell.modelData.isToday ? "white"
                                         : dayCell.modelData.inMonth ? Tokens.textPrimary
                                         : Qt.rgba(1, 1, 1, 0.25)
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: Tokens.fontBody
                                    font.weight: dayCell.modelData.isToday ? Font.DemiBold : Font.Normal
                                    font.features: { "tnum": 1 }
                                }

                                // Dot for days with classes
                                Rectangle {
                                    visible: dayCell.modelData.hasEvent && !dayCell.modelData.isToday
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: Tokens.accent
                                }

                                MouseArea {
                                    id: dayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: dayCell.modelData.pick()
                                }
                            }
                        }
                    }
                }
            }

            // ---------- Classes on the selected day ----------
            Rectangle {
                visible: TimetableService.enabled
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Column {
                visible: TimetableService.enabled
                width: parent.width
                spacing: 6

                Text {
                    text: cal.sameDay(cal.selected, cal.today) ? "Today"
                        : Qt.formatDate(cal.selected, "dddd d MMMM")
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall
                    font.weight: Font.Medium
                }

                Text {
                    visible: cal.dayEvents.length === 0
                    text: "No classes"
                    color: Tokens.textSecondary
                    opacity: 0.7
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontBody
                }

                Repeater {
                    model: cal.dayEvents

                    Item {
                        id: ev
                        required property var modelData
                        width: parent.width
                        height: 18

                        Rectangle {
                            id: evBadge
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(28, evCode.implicitWidth + 10)
                            height: 18
                            radius: Tokens.radiusSm
                            color: Tokens.accent
                            Text {
                                id: evCode
                                anchors.centerIn: parent
                                text: TimetableService.shortTitle(ev.modelData)
                                color: "white"
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSmall
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            anchors.left: evBadge.right
                            anchors.leftMargin: 8
                            anchors.right: evTime.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: ev.modelData.location || ev.modelData.title || ""
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontBody
                            elide: Text.ElideRight
                        }

                        Text {
                            id: evTime
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: TimetableService.timeText(ev.modelData.start)
                                + (ev.modelData.end ? "–" + TimetableService.timeText(ev.modelData.end) : "")
                            color: Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSmall
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
