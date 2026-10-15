import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import "../services"
import "../theme"
import "../bar"

// Blink lock screen (v3, Caelestia-style): blurred wallpaper inside the frame,
// one big panel in the middle. Left: weather, CPU/RAM/GPU, system info.
// Middle: big clock, date, picture and password. Right: music and next class.
// Lock with:  qs -c blink ipc call lock lock   (hypridle does this)
Scope {
    id: root

    property bool locked: false
    property bool failed: false
    property bool checking: false
    property string pending: ""

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property bool hasMusic: player !== null && (player.trackTitle ?? "") !== ""

    function lock() {
        root.failed = false
        root.locked = true
    }

    function submit(text) {
        if (root.checking || text.length === 0) return
        root.pending = text
        root.checking = true
        pam.start()
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
    }

    // Live GPU and temperatures while locked
    onLockedChanged: {
        SystemService.statsUsers += locked ? 1 : -1
        if (locked) facts.running = true
    }

    // Password check. Uses a tiny PAM file next to this one (pam/password.conf).
    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/lock/pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) this.respond(root.pending)
        }
        onCompleted: result => {
            root.checking = false
            root.pending = ""
            if (result === PamResult.Success) {
                root.locked = false
            } else {
                root.failed = true
                failTimer.restart()
            }
        }
    }

    Timer {
        id: failTimer
        interval: 2200
        onTriggered: root.failed = false
    }

    // ---------- Who and what (read when it locks) ----------
    property var info: ({})
    Process {
        id: facts
        command: ["sh", "-c", `
. /etc/os-release 2>/dev/null
echo "os=\${NAME:-Linux}"
echo "kernel=$(uname -r | cut -d- -f1)"
echo "user=$USER"
echo "host=$(cat /etc/hostname 2>/dev/null)"
echo "name=$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1 | cut -d' ' -f1)"
echo "pkgs=$(pacman -Qq 2>/dev/null | wc -l)"
[ -r "$HOME/.face" ] && echo "face=$HOME/.face"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=")
                    if (i > 0) out[l.slice(0, i)] = l.slice(i + 1).trim()
                }
                root.info = out
            }
        }
    }

    function soft(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property var icons: ({
        lock:  "M6 11h12v9H6zM9 11V8a3 3 0 0 1 6 0v3",
        arrow: "M5 12h14M13 6l6 6-6 6",
        prev:  "M18 6l-8 6 8 6zM6 6v12",
        next:  "M6 6l8 6-8 6zM18 6v12",
        play:  "M7 5l12 7-12 7z",
        pause: "M8 5v14M16 5v14",
        note:  "M9 18V5l11-2v13M3 18a3 3 0 1 0 6 0a3 3 0 1 0 -6 0M14 16a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        school:"M3 21h18M5 21V9l7-5 7 5v12M10 21v-5h4v5"
    })

    // ================= Building blocks =================
    component Card: Rectangle {
        radius: 22
        color: Tokens.ink(0.06)
    }

    component Label: Text {
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: 13
    }

    component Ring: Column {
        id: rg
        property string label: ""
        property real value: 0
        property real shown: Math.max(0, Math.min(1, value))
        Behavior on shown { NumberAnimation { duration: 700; easing.type: Tokens.easeMove } }
        readonly property color tint: value > 0.85 ? Tokens.red : value > 0.7 ? Tokens.orange : Tokens.accent
        spacing: 6
        Canvas {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 58
            height: 58
            property real v: rg.shown
            property color c: rg.tint
            onVChanged: requestPaint()
            onCChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const r = width / 2 - 4
                ctx.lineWidth = 6
                ctx.lineCap = "round"
                ctx.strokeStyle = "rgba(255,255,255,0.1)"
                ctx.beginPath()
                ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI)
                ctx.stroke()
                if (v > 0.003) {
                    ctx.strokeStyle = c.toString()
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * v)
                    ctx.stroke()
                }
            }
            Component.onCompleted: requestPaint()
            Label {
                anchors.centerIn: parent
                text: Math.round(rg.shown * 100) + "%"
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: rg.label
            color: Tokens.textSecondary
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
    }

    // Round button with a line icon
    component IconBtn: Rectangle {
        id: ib
        property string d: ""
        property bool filled: false
        property real size: 44
        signal clicked()
        width: size
        height: size
        radius: size / 2
        color: filled ? Tokens.accent : ibMouse.containsMouse ? Tokens.fillHover : "transparent"
        scale: ibMouse.pressed ? Tokens.pressScaleIcon : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
        LineIcon {
            anchors.centerIn: parent
            d: ib.d
            size: ib.size * 0.42
            stroke: 2.4
            tint: ib.filled ? Tokens.onAccent : Tokens.textPrimary
        }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }


    WlSessionLock {
        id: sessionLock
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: Tokens.barBg

            property date now: new Date()
            Timer {
                interval: 1000
                running: root.locked
                repeat: true
                triggeredOnStart: true
                onTriggered: surface.now = new Date()
            }

            Connections {
                target: root
                function onFailedChanged() {
                    if (root.failed) {
                        input.text = ""
                        shake.restart()
                    }
                }
            }

            // Any click puts the cursor back in the password field
            MouseArea {
                anchors.fill: parent
                onClicked: input.forceActiveFocus()
            }

            // ================= Blurred wallpaper inside the frame =================
            ClippingRectangle {
                id: inner
                anchors.fill: parent
                anchors.topMargin: SettingsService.topInset
                anchors.leftMargin: SettingsService.leftInset
                anchors.rightMargin: Tokens.frameT
                anchors.bottomMargin: Tokens.frameT
                radius: 20
                color: "#101012"

                Image {
                    id: wall
                    anchors.fill: parent
                    source: WallpaperService.current ? "file://" + WallpaperService.current : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: wall
                    blurEnabled: true
                    blurMax: 64
                    blur: 1.0
                    autoPaddingEnabled: false
                }
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.35
                }
            }

            // ================= The panel =================
            Rectangle {
                id: panel
                readonly property real fullW: Math.min(1200, inner.width - 80)
                readonly property real fullH: Math.min(660, inner.height - 80)
                width: fullW
                height: fullH
                x: inner.x + (inner.width - width) / 2
                y: inner.y + (inner.height - height) / 2
                radius: 32
                color: Qt.rgba(0, 0, 0, 0.82)

                // Grows in with a small bounce
                opacity: 0
                scale: 0.94
                Component.onCompleted: openAnim.start()
                ParallelAnimation {
                    id: openAnim
                    NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Tokens.durSlow; easing.type: Tokens.easeMove }
                    NumberAnimation { target: panel; property: "scale"; to: 1; duration: 460; easing.type: Tokens.easeGrow; easing.overshoot: Tokens.bounce }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Tokens.shadowColor
                    shadowBlur: 1.0
                    blurMax: 48
                    shadowVerticalOffset: 8
                }

                readonly property real sideW: Math.min(300, (width - 52) * 0.27)

                // ---------- Left: weather, usage, system ----------
                Column {
                    id: leftCol
                    x: 26
                    y: 26
                    width: panel.sideW
                    height: panel.height - 52
                    spacing: 16

                    Card {
                        width: parent.width
                        height: 92
                        visible: WeatherService.ready
                        Image {
                            id: wIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            height: 46
                            sourceSize: Qt.size(92, 92)
                            source: Quickshell.iconPath(WeatherService.icon, "weather-overcast")
                        }
                        Column {
                            anchors.left: wIcon.right
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            Label {
                                text: Math.round(WeatherService.temperature) + "°"
                                font.pixelSize: 32
                                font.weight: Font.Medium
                            }
                            Label {
                                text: WeatherService.description
                                color: Tokens.textSecondary
                            }
                        }
                    }

                    Card {
                        width: parent.width
                        height: 112
                        Row {
                            anchors.centerIn: parent
                            spacing: (parent.width - 3 * 58) / 4
                            Ring { label: "CPU"; value: SystemService.cpu }
                            Ring { label: "RAM"; value: SystemService.ram }
                            Ring { label: "GPU"; value: Math.max(0, SystemService.gpu); visible: SystemService.gpu >= 0 }
                        }
                    }

                    Card {
                        width: parent.width
                        height: Math.max(150, leftCol.height - y)
                        Column {
                            x: 18
                            y: 18
                            width: parent.width - 36
                            spacing: 10

                            Row {
                                spacing: 10
                                Rectangle {
                                    width: 30
                                    height: 24
                                    radius: 8
                                    color: Tokens.barBg
                                    border.width: 1
                                    border.color: Tokens.ink(0.1)
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Rectangle { width: 3; height: 7; radius: 1.5; color: Tokens.textPrimary }
                                        Rectangle { width: 3; height: 7; radius: 1.5; color: Tokens.textPrimary }
                                    }
                                }
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (root.info.user || "") + "@" + (root.info.host || "")
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                            }

                            Repeater {
                                model: [
                                    { k: "OS", v: root.info.os || "" },
                                    { k: "Kernel", v: root.info.kernel || "" },
                                    { k: "Shell", v: "Blink" },
                                    { k: "Uptime", v: SystemService.uptime > 0 ? SystemService.duration(SystemService.uptime) : "" },
                                    { k: "Packages", v: root.info.pkgs || "" }
                                ]
                                delegate: Item {
                                    required property var modelData
                                    width: parent.width
                                    height: 18
                                    Label {
                                        text: parent.modelData.k
                                        color: Tokens.accent
                                        font.weight: Font.Medium
                                    }
                                    Label {
                                        anchors.right: parent.right
                                        text: parent.modelData.v
                                        color: Tokens.textSecondary
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------- Middle: clock, picture, password ----------
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(surface.now, "HH")
                        font.pixelSize: Math.min(150, panel.height * 0.22)
                        font.weight: Font.DemiBold
                        font.letterSpacing: -2
                        lineHeight: 0.9
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(surface.now, "mm")
                        color: Tokens.accent
                        font.pixelSize: Math.min(150, panel.height * 0.22)
                        font.weight: Font.Light
                        font.letterSpacing: -2
                        lineHeight: 0.9
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 14
                        text: Qt.formatDate(surface.now, "dddd, d MMMM")
                        color: Tokens.textSecondary
                        font.pixelSize: 17
                    }

                    Item { width: 1; height: 30 }

                    // Picture: ~/.face if you have one, else your initial
                    ClippingRectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72
                        height: 72
                        radius: 24
                        color: Tokens.accent
                        Label {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            text: (root.info.name || root.info.user || "?").charAt(0).toUpperCase()
                            color: Tokens.onAccent
                            font.pixelSize: 30
                            font.weight: Font.Bold
                        }
                        Image {
                            id: face
                            anchors.fill: parent
                            source: root.info.face ? "file://" + root.info.face : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    Item { width: 1; height: 14 }

                    // Password field: dots instead of characters
                    Rectangle {
                        id: field
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320
                        height: 50
                        radius: 25
                        color: Tokens.ink(0.08)
                        border.width: 1
                        border.color: root.failed ? Tokens.red : root.soft(Tokens.accent, input.activeFocus ? 0.6 : 0.3)
                        Behavior on border.color { ColorAnimation { duration: Tokens.durFast } }

                        transform: Translate { id: shakeT }
                        SequentialAnimation {
                            id: shake
                            NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 50 }
                            NumberAnimation { target: shakeT; property: "x"; to: 12; duration: 70 }
                            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 60 }
                            NumberAnimation { target: shakeT; property: "x"; to: 6; duration: 60 }
                            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 50 }
                        }

                        TextInput {
                            id: input
                            anchors.fill: parent
                            opacity: 0
                            focus: true
                            echoMode: TextInput.Password
                            enabled: !root.checking
                            Component.onCompleted: forceActiveFocus()
                            onAccepted: {
                                root.submit(text)
                                text = ""
                            }
                            Keys.onEscapePressed: text = ""
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Repeater {
                                model: Math.min(14, input.text.length)
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 9
                                    height: 9
                                    radius: 4.5
                                    color: Tokens.textPrimary
                                }
                            }
                            // Blinking cursor
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 20
                                color: Tokens.accent
                                visible: input.activeFocus && !root.checking
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0; duration: 500 }
                                    NumberAnimation { to: 1; duration: 500 }
                                }
                            }
                        }

                        IconBtn {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            size: 38
                            filled: true
                            d: root.icons.arrow
                            opacity: input.text.length > 0 || root.checking ? 1 : 0.5
                            onClicked: {
                                root.submit(input.text)
                                input.text = ""
                            }
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 12
                        text: root.checking ? "Checking..."
                            : root.failed ? "Wrong password, try again"
                            : "Type your password and press Enter"
                        color: root.failed ? Tokens.red : Tokens.textSecondary
                        font.pixelSize: 12
                    }
                }

                // ---------- Right: music, next class ----------
                Column {
                    id: rightCol
                    x: panel.width - 26 - width
                    y: 26
                    width: panel.sideW
                    height: panel.height - 52
                    spacing: 16

                    Card {
                        width: parent.width
                        height: musicCol.implicitHeight + 36
                        Column {
                            id: musicCol
                            x: 18
                            y: 18
                            width: parent.width - 36
                            spacing: 14

                            ClippingRectangle {
                                width: parent.width
                                height: Math.min(150, parent.width * 0.55)
                                radius: 16
                                color: "#2c2550"
                                LineIcon {
                                    anchors.centerIn: parent
                                    visible: art.status !== Image.Ready
                                    d: root.icons.note
                                    size: 40
                                    tint: "#8e8aa8"
                                }
                                Image {
                                    id: art
                                    anchors.fill: parent
                                    source: root.player?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            Column {
                                width: parent.width
                                spacing: 2
                                Label {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: root.hasMusic ? root.player.trackTitle : "Nothing playing"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: root.hasMusic
                                    text: root.player?.trackArtist ?? ""
                                    color: Tokens.textSecondary
                                }
                            }
                            Rectangle {
                                visible: root.hasMusic && (root.player?.lengthSupported ?? false)
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Tokens.ink(0.12)
                                Rectangle {
                                    height: parent.height
                                    radius: 2
                                    color: Tokens.accent
                                    width: (root.player?.length ?? 0) > 0
                                        ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                                }
                                // Mpris does not push position updates
                                Timer {
                                    interval: 1000
                                    repeat: true
                                    running: root.locked && (root.player?.isPlaying ?? false)
                                    onTriggered: root.player.positionChanged()
                                }
                            }
                            Row {
                                visible: root.hasMusic
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 18
                                IconBtn { anchors.verticalCenter: parent.verticalCenter; d: root.icons.prev; size: 38; onClicked: root.player.previous() }
                                IconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    filled: true
                                    d: (root.player?.isPlaying ?? false) ? root.icons.pause : root.icons.play
                                    onClicked: root.player.togglePlaying()
                                }
                                IconBtn { anchors.verticalCenter: parent.verticalCenter; d: root.icons.next; size: 38; onClicked: root.player.next() }
                            }
                        }
                    }

                    // Next class
                    Card {
                        id: classCard
                        width: parent.width
                        height: Math.max(150, rightCol.height - y)
                        readonly property var next: TimetableService.upcoming[0] ?? null
                        readonly property var later: TimetableService.upcoming.slice(1, 3)
                        Column {
                            x: 18
                            y: 18
                            width: parent.width - 36
                            spacing: 12

                            Label {
                                text: "NEXT CLASS"
                                color: Tokens.textSecondary
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }

                            Rectangle {
                                visible: classCard.next !== null
                                width: parent.width
                                height: classCol.implicitHeight + 28
                                radius: 16
                                color: root.soft(Tokens.accent, 0.12)
                                border.width: 1
                                border.color: root.soft(Tokens.accent, 0.4)
                                Column {
                                    id: classCol
                                    x: 14
                                    y: 14
                                    width: parent.width - 28
                                    spacing: 3
                                    readonly property var e: classCard.next
                                    Item {
                                        width: parent.width
                                        height: 24
                                        Label {
                                            id: classCode
                                            text: classCol.e ? TimetableService.shortTitle(classCol.e) : ""
                                            font.pixelSize: 18
                                            font.weight: Font.DemiBold
                                        }
                                        Label {
                                            anchors.right: parent.right
                                            anchors.baseline: classCode.baseline
                                            text: classCol.e ? TimetableService.whenText(classCol.e) : ""
                                            color: Tokens.accent
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                    Label {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: classCol.e ? (classCol.e.title || "").replace(TimetableService.shortTitle(classCol.e), "").trim() : ""
                                        color: Tokens.textSecondary
                                    }
                                    Label {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: classCol.e
                                            ? Qt.formatDate(classCol.e.start, "ddd") + " " + TimetableService.timeText(classCol.e.start)
                                              + (classCol.e.end ? " – " + TimetableService.timeText(classCol.e.end) : "")
                                              + (classCol.e.location ? "  ·  " + classCol.e.location : "")
                                            : ""
                                        color: Tokens.textSecondary
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            Repeater {
                                model: classCard.later
                                delegate: Item {
                                    required property var modelData
                                    width: parent.width
                                    height: 18
                                    Label {
                                        x: 4
                                        text: TimetableService.shortTitle(parent.modelData)
                                        color: Tokens.textSecondary
                                    }
                                    Label {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 4
                                        text: TimetableService.whenText(parent.modelData)
                                        color: Tokens.textSecondary
                                    }
                                }
                            }

                            Label {
                                visible: classCard.next === null
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: TimetableService.enabled ? "No more classes coming up"
                                    : "Add your timetable link in Settings > Notch to see your next class here"
                                color: Tokens.textSecondary
                            }
                        }
                    }
                }
            }
        }
    }
}
