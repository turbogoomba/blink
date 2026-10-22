import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

// The timetable as a desktop widget, like the macOS "Up Next" widget.
// It lies under all windows (layer "bottom"), so it shows on an empty desktop.
// Drag it to move it; the place is saved in settings (widgetX / widgetY).
PanelWindow {
    id: w

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "blink-widget"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors { top: true; left: true }
    implicitWidth: card.width + 2 * pad
    implicitHeight: card.height + 2 * pad

    readonly property int pad: 12   // room for the shadow and the press bounce

    // ---------- Position ----------
    readonly property real screenW: screen ? screen.width : 1920
    readonly property real screenH: screen ? screen.height : 1080
    readonly property real defX: screenW - implicitWidth - Tokens.frameT - 24
    readonly property real defY: SettingsService.topInset + 20
    // Saved place, plus how far it has been dragged right now
    property real dragX: 0
    property real dragY: 0
    readonly property real posX: Math.max(0, Math.min(screenW - implicitWidth,
        (SettingsService.widgetX >= 0 ? SettingsService.widgetX : defX) + dragX))
    readonly property real posY: Math.max(0, Math.min(screenH - implicitHeight,
        (SettingsService.widgetY >= 0 ? SettingsService.widgetY : defY) + dragY))
    margins.left: Math.round(posX)
    margins.top: Math.round(posY)

    // ---------- What to show: the next day with classes ----------
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }
    readonly property date now: TimetableService.now
    readonly property var future: TimetableService.events.filter(e => (e.end || e.start) > now)
    readonly property date day: future.length > 0 ? future[0].start : now
    readonly property var dayClasses: future.filter(e => sameDay(e.start, day))
    readonly property var shown: dayClasses.slice(0, 3)
    readonly property int more: dayClasses.length - shown.length

    readonly property string dayLabel: {
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const d = new Date(day.getFullYear(), day.getMonth(), day.getDate())
        const diff = Math.round((d - today) / 86400000)
        if (diff === 0) return "Today"
        if (diff === 1) return "Tomorrow"
        return Qt.formatDate(day, "dddd")
    }

    Rectangle {
        id: card
        x: w.pad
        y: w.pad
        width: 340
        height: 164
        radius: 22
        color: Tokens.cardBg
        border.color: Tokens.ink(0.08)
        border.width: 1
        scale: drag.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        // Drag anywhere to move it. The window moves under the mouse, so the mouse
        // stays at the same place inside it; add the difference each time.
        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
            property real sx: 0
            property real sy: 0
            onPressed: m => { sx = m.x; sy = m.y }
            onPositionChanged: m => {
                if (!pressed) return
                w.dragX += m.x - sx
                w.dragY += m.y - sy
            }
            onReleased: {
                const x = Math.round(w.posX), y = Math.round(w.posY)
                w.dragX = 0
                w.dragY = 0
                SettingsService.widgetX = x
                SettingsService.widgetY = y
            }
        }

        // ---------- Left: the day ----------
        Column {
            id: dayCol
            x: 18
            y: 16
            width: 84
            spacing: 0

            Text {
                text: w.dayLabel.toUpperCase()
                color: Tokens.accent
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
                font.weight: Font.Bold
                font.letterSpacing: 0.6
                width: parent.width
                elide: Text.ElideRight
            }
            Text {
                text: Qt.formatDate(w.day, "d")
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 44
                font.weight: Font.Light
                font.features: { "tnum": 1 }
            }
            Text {
                text: Qt.formatDate(w.day, "MMMM")
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
            }
        }

        // ---------- Right: the classes ----------
        Column {
            x: dayCol.x + dayCol.width + 8
            y: 16
            width: card.width - x - 16
            spacing: 6

            Text {
                visible: w.shown.length === 0
                width: parent.width
                topPadding: 38
                wrapMode: Text.WordWrap
                text: TimetableService.url === "" ? "Add your timetable link in Settings > Notch"
                    : TimetableService.error !== "" ? TimetableService.error
                    : "No classes coming up"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontBody
            }

            Repeater {
                model: w.shown

                Item {
                    id: cls
                    required property var modelData
                    readonly property bool live: w.now && TimetableService.isNow(modelData)
                    width: parent.width
                    height: 36

                    // Colored line on the left, like events in the macOS widget
                    Rectangle {
                        id: line
                        width: 4
                        height: parent.height
                        radius: 2
                        color: Tokens.accent
                        opacity: cls.live ? 1 : 0.7
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radiusSm
                        color: Tokens.accent
                        opacity: cls.live ? 0.16 : 0.08
                    }

                    Text {
                        id: code
                        x: line.width + 8
                        y: 3
                        text: TimetableService.shortTitle(cls.modelData)
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontBody
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        y: 4
                        text: cls.live ? "Now" : TimetableService.whenText(cls.modelData)
                        color: cls.live ? Tokens.accent : Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSmall
                        font.weight: cls.live ? Font.Bold : Font.Normal
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        x: code.x
                        y: 19
                        width: parent.width - x - 8
                        text: TimetableService.timeText(cls.modelData.start)
                            + (cls.modelData.end ? "–" + TimetableService.timeText(cls.modelData.end) : "")
                            + (cls.modelData.location ? "  ·  " + cls.modelData.location : "")
                        color: Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSmall
                        font.features: { "tnum": 1 }
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                visible: w.more > 0
                text: "+" + w.more + " more"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSmall
            }
        }
    }
}
