import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"
import "snap.js" as Snap

// The timetable as a desktop widget, like the macOS "Up Next" widget.
// It lies under all windows (layer "bottom"), so it shows on an empty desktop.
// Drag it to move it; the place is saved in settings (widgetX / widgetY).
// The window covers the whole screen but only takes the mouse over the card (mask),
// so dragging moves the card inside it, smoothly, without moving a window around.
PanelWindow {
    id: w

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "blink-widget"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    // Explicit numbers (not item:) so the mask follows the card while it is dragged
    mask: Region { x: card.x; y: card.y; width: card.width; height: card.height }

    // ---------- Position ----------
    readonly property real defX: width - card.width - Tokens.frameT - 36
    readonly property real defY: SettingsService.topInset + 32
    function clampX(x) { return Math.max(0, Math.min(width - card.width, x)) }
    function clampY(y) { return Math.max(0, Math.min(height - card.height, y)) }
    readonly property real savedX: clampX(SettingsService.widgetX >= 0 ? SettingsService.widgetX : defX)
    readonly property real savedY: clampY(SettingsService.widgetY >= 0 ? SettingsService.widgetY : defY)

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
        x: w.savedX
        y: w.savedY
        // Glides into place after a drop (not while dragging)
        Behavior on x { enabled: !drag.pressed; NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on y { enabled: !drag.pressed; NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        // Tell the other widgets where this one is
        function publish() { ShellState.setWidgetRect("timetable", { x: w.savedX, y: w.savedY, w: width, h: height }) }
        Component.onCompleted: publish()
        Connections {
            target: w
            function onSavedXChanged() { card.publish() }
            function onSavedYChanged() { card.publish() }
        }
        width: 340
        height: 164
        radius: 22
        color: Tokens.cardBg
        border.color: Tokens.ink(0.08)
        border.width: 1
        scale: drag.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

        GlassEdge { radius: 22; z: 10 }

        // Drag anywhere to move it
        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
            drag.target: card
            drag.threshold: 2
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: w.width - card.width
            drag.maximumY: w.height - card.height
            onReleased: {
                // Snap into line with the screen edges or the other widgets
                const others = Object.keys(ShellState.widgetRects).filter(k => k !== "timetable")
                    .map(k => ShellState.widgetRects[k])
                const p = Snap.snap(card.x, card.y, card.width, card.height, w.width, w.height,
                    SettingsService.topInset, 110, others)
                SettingsService.widgetX = Math.round(p.x)
                SettingsService.widgetY = Math.round(p.y)
                // Dragging replaced the bindings; follow the settings again (it glides there)
                card.x = Qt.binding(() => w.savedX)
                card.y = Qt.binding(() => w.savedY)
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
