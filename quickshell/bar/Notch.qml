import QtQuick
import QtQml
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import "../theme"
import "../services"

Rectangle {
    id: notch
    property int baseHeight: 36

    // ---------- Tilstand ----------
    readonly property var player:
        Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property var notif: NotificationService.current
    readonly property bool hasMusic: player !== null && (player.trackTitle ?? "") !== ""
    readonly property bool hasShelf: ShelfService.files.length > 0
    readonly property bool dragging: dropArea.containsDrag

    // Det store panelet (klikk)
    property bool open: false
    property string tab: "nook"

    // Bluetooth-hendelse
    property var btDevice: null
    property bool btConnected: false

    // Hva som vises, i prioritert rekkefølge
    readonly property bool showNotif: notif !== null && !open
    readonly property bool showBt: btDevice !== null && !open && !showNotif
    readonly property bool peek: !open && !showNotif && !showBt && hover.hovered && hasMusic
    readonly property bool compact: !open && !showNotif && !showBt && !peek && (hasMusic || hasShelf)

    onDraggingChanged: {
        if (dragging) {
            open = true
            tab = "tray"
        }
    }
    onOpenChanged: {
        if (open) {
            BusService.refresh()
            if (tab === "notifications") NotificationService.markRead()
        }
    }
    onTabChanged: if (tab === "notifications") NotificationService.markRead()

    // ISO-ukenummer
    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }
    readonly property int week: {
        const d = clock.date
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }

    // ---------- Størrelse ----------
    width: open ? 660
         : showNotif ? 400
         : showBt ? 360
         : peek ? 420
         : compact ? 280
         : 200
    height: open ? openContent.implicitHeight + 30
          : showNotif ? 84
          : showBt ? 64
          : peek ? 110
          : baseHeight
    radius: open || showNotif || peek ? 24 : showBt ? 22 : 10
    color: Tokens.barBg
    clip: true

    Behavior on width  { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // ---------- Bluetooth: lytt etter til/frakobling ----------
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                notch.btDevice = modelData
                notch.btConnected = modelData.connected
                btTimer.restart()
            }
        }
    }
    Timer {
        id: btTimer
        interval: 3500
        onTriggered: notch.btDevice = null
    }

    // ---------- Mus ----------
    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                NotificationService.pause()
                closeTimer.stop()
            } else {
                NotificationService.resume()
                if (notch.open) closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 700
        onTriggered: notch.open = false
    }

    MouseArea {
        anchors.fill: parent
        enabled: !notch.open && !notch.showNotif
        onClicked: {
            notch.tab = "nook"
            notch.open = true
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        onEntered: drag => drag.accepted = drag.hasUrls
        onDropped: drop => {
            if (drop.hasUrls) ShelfService.add(drop.urls)
            drop.accept(Qt.CopyAction)
            closeTimer.interval = 1500
            closeTimer.restart()
            closeTimer.interval = 700
        }
    }

    // ---------- Små byggeklosser ----------
    component CtrlButton: Item {
        id: btn
        property string icon: ""
        property int size: 20
        signal clicked()
        width: size + 12
        height: size + 12

        Image {
            anchors.centerIn: parent
            width: btn.size
            height: btn.size
            sourceSize: Qt.size(btn.size * 2, btn.size * 2)
            source: Quickshell.iconPath(btn.icon)
            opacity: btnMouse.pressed ? 0.6 : 1
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            onClicked: btn.clicked()
        }
    }

    component TabButton: Rectangle {
        id: tb
        property string tabId: ""
        property string label: ""
        property int badge: 0
        readonly property bool selected: notch.tab === tabId

        width: tbRow.implicitWidth + 24
        height: 26
        radius: 13
        color: selected ? Tokens.surface
             : tbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06)
             : "transparent"

        Row {
            id: tbRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tb.label
                color: tb.selected ? Tokens.textPrimary : Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: tb.badge > 0
                width: Math.max(16, badgeText.implicitWidth + 8)
                height: 16
                radius: 8
                color: Tokens.accent

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: tb.badge
                    color: "white"
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
        }

        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: notch.tab = tb.tabId
        }
    }

    component FileTile: Item {
        id: tile
        required property string modelData
        width: 64
        height: 76

        ClippingRectangle {
            id: thumb
            anchors.horizontalCenter: parent.horizontalCenter
            width: 52
            height: 52
            radius: 10
            color: Tokens.surface

            Image {
                anchors.fill: parent
                visible: ShelfService.isImage(tile.modelData)
                source: visible ? tile.modelData : ""
                sourceSize: Qt.size(104, 104)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Image {
                anchors.centerIn: parent
                width: 32
                height: 32
                visible: !ShelfService.isImage(tile.modelData)
                sourceSize: Qt.size(64, 64)
                source: Quickshell.iconPath("text-x-generic")
            }
        }

        Text {
            anchors.top: thumb.bottom
            anchors.topMargin: 4
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: ShelfService.nameOf(tile.modelData)
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }

        Item {
            id: dragProxy
            Drag.active: tileMouse.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.mimeData: { "text/uri-list": tile.modelData }
            Drag.onDragFinished: action => {
                if (action === Qt.MoveAction) ShelfService.remove(tile.modelData)
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: dragProxy
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) ShelfService.remove(tile.modelData)
            }
            onDoubleClicked: Quickshell.execDetached(["xdg-open", tile.modelData])
        }
    }

    // ============================================================
    // FJES
    // ============================================================
    component Eye: Item {
        id: eye
        property string mood: "normal"

        width: 10
        height: 12

        Rectangle {
            anchors.centerIn: parent
            visible: eye.mood !== "happy"
            width: eye.mood === "sleepy" || eye.mood === "excited" ? 7 : 5
            height: eye.mood === "blink" ? 1
                  : eye.mood === "sleepy" ? 2
                  : eye.mood === "excited" ? 10
                  : 8
            radius: Math.min(width, height) / 2
            color: Tokens.textPrimary
            Behavior on width  { NumberAnimation { duration: 90 } }
            Behavior on height { NumberAnimation { duration: 90 } }
        }

        Canvas {
            anchors.fill: parent
            visible: eye.mood === "happy"
            onPaint: {
                const c = getContext("2d")
                c.reset()
                c.strokeStyle = Tokens.textPrimary.toString()
                c.lineWidth = 2
                c.lineCap = "round"
                c.beginPath()
                c.arc(width / 2, height / 2 + 3, 3.5, Math.PI, 0)
                c.stroke()
            }
            Component.onCompleted: requestPaint()
        }
    }

    Item {
        id: face
        readonly property int hour: clock.date.getHours()
        readonly property string baseMood:
              hover.hovered ? "excited"
            : (hour >= 23 || hour < 6) ? "sleepy"
            : (notch.player?.isPlaying ?? false) ? "happy"
            : "normal"
        property bool blinking: false
        property real look: 0
        readonly property string mood:
            blinking && (baseMood === "normal" || baseMood === "excited") ? "blink" : baseMood
        readonly property bool smiling: baseMood === "happy" || baseMood === "excited"

        anchors.horizontalCenter: parent.horizontalCenter
        y: (notch.baseHeight - height) / 2 + 1
        width: 40
        height: 20
        opacity: !notch.open && !notch.showNotif && !notch.showBt && !notch.peek ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            id: eyes
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: face.look * 2
            y: face.smiling ? 0 : 4
            spacing: 8

            Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 150 } }

            Eye { mood: face.mood }
            Eye { mood: face.mood }
        }

        Canvas {
            anchors.horizontalCenter: eyes.horizontalCenter
            anchors.top: eyes.bottom
            anchors.topMargin: 1
            width: 12
            height: 6
            opacity: face.smiling ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            onPaint: {
                const c = getContext("2d")
                c.reset()
                c.strokeStyle = Tokens.textPrimary.toString()
                c.lineWidth = 1.5
                c.lineCap = "round"
                c.beginPath()
                c.arc(width / 2, 0, 4, 0.2 * Math.PI, 0.8 * Math.PI)
                c.stroke()
            }
            Component.onCompleted: requestPaint()
        }

        Timer {
            interval: 3000
            running: face.opacity > 0
            repeat: true
            onTriggered: {
                face.blinking = true
                unblink.restart()
                interval = 2500 + Math.random() * 4000
            }
        }
        Timer {
            id: unblink
            interval: 130
            onTriggered: face.blinking = false
        }
        Timer {
            interval: 5000
            running: face.opacity > 0
            repeat: true
            onTriggered: {
                const r = Math.random()
                face.look = r < 0.25 ? -1 : r < 0.5 ? 1 : 0
                interval = 3000 + Math.random() * 5000
            }
        }
    }

    // ============================================================
    // KOMPAKT
    // ============================================================
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: notch.baseHeight
        opacity: notch.compact ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ClippingRectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 5
            color: notch.hasMusic ? Tokens.surface : "transparent"

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(40, 40)
                fillMode: Image.PreserveAspectCrop
                source: notch.hasMusic
                    ? (notch.player?.trackArtUrl ?? "")
                    : Quickshell.iconPath("folder-symbolic", "folder")
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: notch.hasMusic

            Repeater {
                model: CavaService.bars

                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 3 + (CavaService.values[index] ?? 0)
                    radius: 1.5
                    color: Tokens.accent
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: !notch.hasMusic
            text: ShelfService.files.length
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    // ============================================================
    // TITT (hover med musikk)
    // ============================================================
    Item {
        anchors.fill: parent
        anchors.margins: 16
        opacity: notch.peek ? 1 : 0
        enabled: notch.peek
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ClippingRectangle {
            id: peekArt
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            height: 64
            radius: 12
            color: Tokens.surface

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                source: notch.player?.trackArtUrl ?? ""
            }
        }

        Column {
            anchors.left: peekArt.right
            anchors.leftMargin: 14
            anchors.right: peekControls.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: notch.player?.trackTitle ?? ""
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: notch.player?.trackArtist ?? ""
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Row {
            id: peekControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            CtrlButton {
                icon: "media-skip-backward-symbolic"
                onClicked: notch.player?.previous()
            }
            CtrlButton {
                icon: notch.player?.isPlaying ? "media-playback-pause-symbolic"
                                              : "media-playback-start-symbolic"
                onClicked: notch.player?.togglePlaying()
            }
            CtrlButton {
                icon: "media-skip-forward-symbolic"
                onClicked: notch.player?.next()
            }
        }
    }

    // ============================================================
    // BLUETOOTH
    // ============================================================
    Item {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        opacity: notch.showBt ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        readonly property real level: notch.btDevice?.battery ?? 0
        readonly property bool hasBattery: notch.btConnected && (notch.btDevice?.batteryAvailable ?? false)

        Image {
            id: btIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            sourceSize: Qt.size(60, 60)
            source: Quickshell.iconPath(notch.btDevice?.icon || "bluetooth", "bluetooth")
            opacity: notch.btConnected ? 1 : 0.5
        }

        Column {
            anchors.left: btIcon.right
            anchors.leftMargin: 12
            anchors.right: batteryRing.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: notch.btConnected ? "Connected" : "Disconnected"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 11
            }
            Text {
                width: parent.width
                text: notch.btDevice?.name ?? ""
                color: notch.btConnected ? Tokens.textPrimary : Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        // Batteriring
        Item {
            id: batteryRing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.hasBattery ? 34 : 0
            height: 34
            visible: parent.hasBattery

            Canvas {
                id: ring
                anchors.fill: parent
                property real level: parent.parent.level
                onLevelChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    const r = width / 2 - 2.5
                    c.lineWidth = 3
                    c.lineCap = "round"
                    c.strokeStyle = "rgba(255,255,255,0.15)"
                    c.beginPath()
                    c.arc(width / 2, height / 2, r, 0, 2 * Math.PI)
                    c.stroke()
                    c.strokeStyle = level < 0.2 ? "#ff453a" : "#30d158"
                    c.beginPath()
                    c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * level)
                    c.stroke()
                }
                Component.onCompleted: requestPaint()
            }

            Text {
                anchors.centerIn: parent
                text: Math.round(parent.parent.level * 100)
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
    }

    // ============================================================
    // PANELET (klikk)
    // ============================================================
    Column {
        id: openContent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 12
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 14
        opacity: notch.open ? 1 : 0
        enabled: notch.open
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // ---------- Faner + uke ----------
        Item {
            width: parent.width
            height: 26

            Row {
                spacing: 4

                TabButton { tabId: "nook"; label: "Nook" }
                TabButton { tabId: "tray"; label: "Tray"; badge: ShelfService.files.length }
                TabButton { tabId: "notifications"; label: "Notifications"; badge: NotificationService.unread }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Week " + notch.week
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        // ---------- NOOK: musikk + busser ----------
        Item {
            width: parent.width
            height: 104
            visible: notch.tab === "nook"

            Item {
                id: mediaArea
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: (parent.width - 41) / 2

                ClippingRectangle {
                    id: openArt
                    visible: notch.hasMusic
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 76
                    height: 76
                    radius: 12
                    color: Tokens.surface

                    Image {
                        anchors.fill: parent
                        sourceSize: Qt.size(152, 152)
                        fillMode: Image.PreserveAspectCrop
                        source: notch.player?.trackArtUrl ?? ""
                    }
                }

                Column {
                    visible: notch.hasMusic
                    anchors.left: openArt.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        text: notch.player?.trackTitle ?? ""
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: notch.player?.trackArtist ?? ""
                        color: Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Row {
                        leftPadding: -6

                        CtrlButton {
                            icon: "media-skip-backward-symbolic"
                            size: 16
                            onClicked: notch.player?.previous()
                        }
                        CtrlButton {
                            icon: notch.player?.isPlaying ? "media-playback-pause-symbolic"
                                                          : "media-playback-start-symbolic"
                            onClicked: notch.player?.togglePlaying()
                        }
                        CtrlButton {
                            icon: "media-skip-forward-symbolic"
                            size: 16
                            onClicked: notch.player?.next()
                        }
                    }
                }

                Text {
                    visible: !notch.hasMusic
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Nothing playing"
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 13
                }
            }

            Rectangle {
                anchors.left: mediaArea.right
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Tokens.surface
              }

            // Timetable (shown instead of buses when a timetable link exists)
            Column {
                anchors { right: parent.right; top: parent.top }
                width: (parent.width - 41) / 2
                spacing: 6
                visible: TimetableService.enabled

                Text {
                    width: parent.width
                    text: TimetableService.error !== "" ? TimetableService.error
                        : TimetableService.upcoming.length === 0 ? "No upcoming classes"
                        : "Timetable"
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Repeater {
                    model: TimetableService.upcoming

                    delegate: Item {
                        id: cls
                        required property var modelData
                        readonly property bool live: TimetableService.now && TimetableService.isNow(modelData)

                        width: parent.width
                        height: 18

                        Rectangle {
                            id: codeBadge
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(28, codeText.implicitWidth + 10)
                            height: 18
                            radius: 4
                            color: cls.live ? "#30d158" : Tokens.accent

                            Text {
                                id: codeText
                                anchors.centerIn: parent
                                text: TimetableService.shortTitle(cls.modelData)
                                color: "white"
                                font.family: Tokens.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            anchors.left: codeBadge.right
                            anchors.leftMargin: 8
                            anchors.right: whenText.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: cls.modelData.location || cls.modelData.title || ""
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            id: whenText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: TimetableService.now && TimetableService.whenText(cls.modelData)
                            color: cls.live ? "#30d158" : Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Column {
                anchors { right: parent.right; top: parent.top }
                width: (parent.width - 41) / 2
                spacing: 6
                visible: !TimetableService.enabled

                Text {
                    width: parent.width
                    text: BusService.error !== "" ? BusService.error
                        : BusService.stopName !== "" ? BusService.stopName
                        : "Loading..."
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Repeater {
                    model: BusService.departures.slice(0, 4)

                    delegate: Item {
                        id: dep
                        required property var modelData
                        readonly property int mins: BusService.minutesUntil(modelData.time)

                        width: parent.width
                        height: 18

                        Rectangle {
                            id: lineBadge
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(28, lineText.implicitWidth + 10)
                            height: 18
                            radius: 4
                            color: BusService.lineColor(dep.modelData.mode)

                            Text {
                                id: lineText
                                anchors.centerIn: parent
                                text: dep.modelData.line
                                color: "white"
                                font.family: Tokens.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            anchors.left: lineBadge.right
                            anchors.leftMargin: 8
                            anchors.right: minsText.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: dep.modelData.dest
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            id: minsText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: dep.mins === 0 ? "Now" : dep.mins + " min"
                            color: dep.modelData.realtime ? Tokens.textPrimary : Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 12
                            font.weight: dep.mins <= 2 ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }

        // ---------- TRAY ----------
        Item {
            width: parent.width
            height: 80
            visible: notch.tab === "tray"

            Row {
                id: shelfRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: notch.hasShelf && !notch.dragging

                Repeater {
                    model: ShelfService.files.slice(0, 6)
                    FileTile {}
                }
            }

            Rectangle {
                anchors.left: shelfRow.visible ? shelfRow.right : parent.left
                anchors.leftMargin: shelfRow.visible ? 12 : 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 70
                radius: 12
                color: "transparent"
                border.color: notch.dragging ? Tokens.accent : Tokens.border
                border.width: 1.5

                Text {
                    anchors.centerIn: parent
                    text: "Drop files here"
                    color: notch.dragging ? Tokens.textPrimary : Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 12
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    visible: notch.hasShelf && !notch.dragging
                    text: "Clear"
                    color: clearMouse.containsMouse ? Tokens.textPrimary : Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 11

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: ShelfService.clear()
                    }
                }
            }
        }

        // ---------- NOTIFICATIONS ----------
        Item {
            width: parent.width
            height: NotificationService.history.length === 0 ? 40 : Math.min(200, list.contentHeight + 24)
            visible: notch.tab === "notifications"

            Text {
                visible: NotificationService.history.length === 0
                anchors.centerIn: parent
                text: "No notifications"
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 13
            }

            Text {
                visible: NotificationService.history.length > 0
                anchors.right: parent.right
                anchors.top: parent.top
                text: "Clear all"
                color: clearAllMouse.containsMouse ? Tokens.textPrimary : Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 11

                MouseArea {
                    id: clearAllMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: NotificationService.clearAll()
                }
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.topMargin: 20
                clip: true
                spacing: 4
                model: NotificationService.history

                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    required property int index

                    width: list.width
                    height: 52
                    radius: 10
                    color: entryMouse.containsMouse ? Tokens.surface : Qt.rgba(1, 1, 1, 0.04)

                    Image {
                        id: entryIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        sourceSize: Qt.size(56, 56)
                        fillMode: Image.PreserveAspectFit
                        source: entry.modelData.icon
                    }

                    Column {
                        anchors.left: entryIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: entry.modelData.appName + "  ·  " + NotificationService.ago(entry.modelData.time)
                            color: Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: entry.modelData.summary
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: entry.modelData.body
                            textFormat: Text.PlainText
                            color: Tokens.textPrimary
                            opacity: 0.75
                            font.family: Tokens.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: NotificationService.removeAt(entry.index)
                    }
                }
            }
        }
    }

    // ============================================================
    // VARSEL som popper ut
    // ============================================================
    Item {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        opacity: notch.showNotif ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ClippingRectangle {
            id: notifIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            color: Tokens.surface

            Image {
                anchors.centerIn: parent
                width: 28
                height: 28
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectFit
                source: NotificationService.iconFor(notch.notif)
            }
        }

        Column {
            anchors.left: notifIcon.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: notch.notif?.appName ?? ""
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: notch.notif?.summary ?? ""
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: notch.notif?.body ?? ""
                textFormat: Text.PlainText
                color: Tokens.textPrimary
                opacity: 0.8
                font.family: Tokens.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: NotificationService.hide()
        }
    }
}
