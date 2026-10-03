import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../services"
import "../theme"

// Mac Rice lock screen (v2): same black frame, bar and notch as the desktop.
// Lock with:  qs -p <shell> ipc call lock lock   (hypridle does this)
Scope {
    id: root

    property bool locked: false
    property bool failed: false
    property bool checking: false
    property string pending: ""
    property int typing: 0          // bumps on every key press, wakes the face

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

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
        interval: 1800
        onTriggered: root.failed = false
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: "#000000"

            property date now: new Date()
            Timer {
                interval: 1000
                running: root.locked
                repeat: true
                triggeredOnStart: true
                onTriggered: surface.now = new Date()
            }

            // Awake while typing, asleep after 4 s without keys
            property bool awake: false
            Timer {
                id: sleepTimer
                interval: 4000
                onTriggered: surface.awake = false
            }
            Connections {
                target: root
                function onTypingChanged() {
                    surface.awake = true
                    sleepTimer.restart()
                }
                function onFailedChanged() {
                    if (root.failed) {
                        input.text = ""
                        shake.restart()
                    }
                }
            }

            Item {
                id: content
                anchors.fill: parent
                opacity: 0
                Component.onCompleted: fadeIn.start()
                NumberAnimation { id: fadeIn; target: content; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }

                // ================= Inner screen (inside the frame) =================
                ClippingRectangle {
                    id: inner
                    anchors.fill: parent
                    anchors.topMargin: Tokens.barHeight
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    anchors.bottomMargin: 6
                    radius: 14
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
                        opacity: 0.3
                    }

                    // ---------- Date + clock ----------
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: parent.height * 0.1
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(surface.now, "dddd d MMMM")
                            color: Qt.rgba(0.9, 0.9, 0.91, 0.8)
                            font.family: Tokens.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(surface.now, "HH:mm")
                            color: "#f2f2f4"
                            font.family: Tokens.fontFamily
                            font.pixelSize: 132
                            font.weight: Font.Light
                            font.letterSpacing: -3
                        }

                        // ---------- Now playing ----------
                        Rectangle {
                            visible: root.player !== null && (root.player.trackTitle ?? "") !== ""
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 330
                            height: 70
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.07)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            ClippingRectangle {
                                id: art
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46
                                height: 46
                                radius: 10
                                color: Qt.rgba(1, 1, 1, 0.12)

                                Image {
                                    anchors.fill: parent
                                    source: root.player?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            Column {
                                anchors.left: art.right
                                anchors.leftMargin: 12
                                anchors.right: playBtn.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: root.player?.trackTitle ?? ""
                                    color: "#e5e5e7"
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: root.player?.trackArtist ?? ""
                                    color: Tokens.textSecondary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                id: playBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                height: 34
                                radius: 17
                                color: playMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.12)
                                scale: playMouse.pressed ? 0.92 : 1
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    sourceSize: Qt.size(32, 32)
                                    source: Quickshell.iconPath(root.player?.isPlaying
                                        ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                                }

                                MouseArea {
                                    id: playMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.player?.togglePlaying()
                                }
                            }
                        }
                    }

                    // ---------- Name + password ----------
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 64
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Herman"
                            color: "#e5e5e7"
                            font.family: Tokens.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 250
                            height: 40

                            Rectangle {
                                id: field
                                width: parent.width
                                height: parent.height
                                radius: 14
                                color: root.failed ? Qt.rgba(1, 0.41, 0.38, 0.14) : Qt.rgba(0, 0, 0, 0.45)
                                border.width: 1
                                border.color: root.failed ? Qt.rgba(1, 0.41, 0.38, 0.6)
                                    : input.activeFocus ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Image {
                                    id: lockIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    sourceSize: Qt.size(28, 28)
                                    opacity: 0.6
                                    source: Quickshell.iconPath("system-lock-screen-symbolic", "changes-prevent-symbolic")
                                }

                                TextInput {
                                    id: input
                                    anchors.left: lockIcon.right
                                    anchors.leftMargin: 10
                                    anchors.right: go.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    echoMode: TextInput.Password
                                    passwordCharacter: "•"
                                    color: "#e5e5e7"
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: 13
                                    clip: true
                                    focus: true
                                    enabled: !root.checking
                                    Component.onCompleted: forceActiveFocus()
                                    onTextChanged: root.typing++
                                    onAccepted: root.submit(text)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: input.text.length === 0
                                        text: root.failed ? "Wrong password" : root.checking ? "Checking..." : "Password"
                                        color: root.failed ? "#ff8a83" : Qt.rgba(0.9, 0.9, 0.91, 0.55)
                                        font: input.font
                                    }
                                }

                                Rectangle {
                                    id: go
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    radius: 9
                                    color: goMouse.pressed ? Qt.darker(Tokens.accent, 1.15) : Tokens.accent
                                    opacity: input.text.length > 0 ? 1 : 0.5
                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "→"
                                        color: "white"
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        id: goMouse
                                        anchors.fill: parent
                                        onClicked: root.submit(input.text)
                                    }
                                }

                                SequentialAnimation {
                                    id: shake
                                    NumberAnimation { target: field; property: "x"; to: -10; duration: 50 }
                                    NumberAnimation { target: field; property: "x"; to: 10; duration: 70 }
                                    NumberAnimation { target: field; property: "x"; to: -6; duration: 60 }
                                    NumberAnimation { target: field; property: "x"; to: 6; duration: 60 }
                                    NumberAnimation { target: field; property: "x"; to: 0; duration: 50 }
                                }
                            }
                        }
                    }
                }

                // ================= Bar =================
                Item {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Tokens.barHeight

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            sourceSize: Qt.size(26, 26)
                            opacity: 0.7
                            source: Quickshell.iconPath("system-lock-screen-symbolic", "changes-prevent-symbolic")
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Locked"
                            color: Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 13
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        // Battery, same drawing as the bar
                        Row {
                            visible: UPower.displayDevice?.isLaptopBattery ?? false
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Rectangle {
                                width: 24
                                height: 11
                                radius: 3
                                color: "transparent"
                                border.width: 1.5
                                border.color: "#e5e5e7"

                                Rectangle {
                                    x: 2.5
                                    y: 2.5
                                    height: parent.height - 5
                                    width: (parent.width - 5) * (UPower.displayDevice?.percentage ?? 0)
                                    radius: 1
                                    color: !UPower.onBattery ? "#30d158"
                                        : PowerProfiles.profile === PowerProfile.PowerSaver ? "#ff9f0a"
                                        : (UPower.displayDevice?.percentage ?? 1) < 0.2 ? "#ff453a" : "#e5e5e7"
                                }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 4
                                radius: 1
                                color: "#e5e5e7"
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatTime(surface.now, "HH:mm")
                            color: "#e5e5e7"
                            font.family: Tokens.fontFamily
                            font.pixelSize: 13
                        }
                    }
                }

                // ================= Notch with face =================
                Item {
                    id: notch
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: 190 + 28
                    height: 58

                    // Fillets where the notch meets the bar
                    Canvas {
                        x: 0
                        y: Tokens.barHeight
                        width: 14
                        height: 14
                        onPaint: {
                            const c = getContext("2d")
                            c.fillStyle = "#000"
                            c.fillRect(0, 0, 14, 14)
                            c.globalCompositeOperation = "destination-out"
                            c.beginPath(); c.arc(0, 14, 14, 0, Math.PI * 2); c.fill()
                        }
                    }
                    Canvas {
                        x: parent.width - 14
                        y: Tokens.barHeight
                        width: 14
                        height: 14
                        onPaint: {
                            const c = getContext("2d")
                            c.fillStyle = "#000"
                            c.fillRect(0, 0, 14, 14)
                            c.globalCompositeOperation = "destination-out"
                            c.beginPath(); c.arc(14, 14, 14, 0, Math.PI * 2); c.fill()
                        }
                    }

                    Rectangle {
                        x: 14
                        y: -20
                        width: 190
                        height: 78
                        radius: 18
                        color: "#000000"
                    }

                    // Eyes: asleep (lines), awake (open), wrong password (frown, red)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 4
                        spacing: 18

                        Repeater {
                            model: 2
                            delegate: Rectangle {
                                required property int index
                                readonly property bool open: surface.awake && !root.failed
                                anchors.verticalCenter: parent.verticalCenter
                                width: open ? 9 : 12
                                height: open ? 13 : (root.failed ? 4 : 3)
                                radius: open ? 5 : 2
                                color: root.failed ? "#ff8a83" : "#e5e5e7"
                                rotation: root.failed ? (index === 0 ? 18 : -18) : 0
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Behavior on rotation { NumberAnimation { duration: 150 } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
