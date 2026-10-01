import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pam
import "../theme"
import "../services"

WlSessionLock {
    id: lock
    locked: ShellState.locked

    // TESTMODUS: låser opp av seg selv etter 30 sek. Sett til false når alt virker.
    readonly property bool testMode: true

    property bool unlocking: false
    onLockedChanged: if (locked) unlocking = false

    Timer {
        running: lock.locked && lock.testMode
        interval: 30000
        onTriggered: ShellState.locked = false
    }

    // Spill av ut-animasjonen før vi faktisk låser opp
    Timer {
        id: unlockTimer
        interval: 350
        onTriggered: ShellState.locked = false
    }
    function unlock() {
        unlocking = true
        unlockTimer.restart()
    }

    // Én flate per skjerm
    WlSessionLockSurface {
        id: surface
        color: "transparent"

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        // Mørk tone over det blurrede skrivebordet
        Rectangle {
            id: tint
            anchors.fill: parent
            color: "black"
            opacity: 0
        }

        // Alt innholdet, så vi kan animere det samlet ut
        Item {
            id: content
            anchors.fill: parent
            opacity: lock.unlocking ? 0 : 1
            scale: lock.unlocking ? 1.04 : 1
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            // ---------- Dato og klokke ----------
            Column {
                id: clockBlock
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.12
                opacity: 0
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd d. MMMM")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Medium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 110
                    font.weight: Font.DemiBold
                }
            }

            // ---------- Bruker og passord ----------
            Column {
                id: loginBlock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.12
                spacing: 12
                opacity: 0

                // Avatar: ~/.face hvis den finnes, ellers forbokstav
                ClippingRectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72
                    height: 72
                    radius: 36
                    color: Tokens.surface

                    Text {
                        anchors.centerIn: parent
                        text: (Quickshell.env("USER") ?? "?").charAt(0).toUpperCase()
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }
                    Image {
                        anchors.fill: parent
                        source: "file://" + Quickshell.env("HOME") + "/.face"
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Quickshell.env("USER") ?? ""
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                // Passordfelt
                Rectangle {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 220
                    height: 36
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.15)
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1

                    // Brukes til rist-animasjonen
                    property real shakeOffset: 0
                    transform: Translate { x: field.shakeOffset }

                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: field; property: "shakeOffset"; to: -12; duration: 50 }
                        NumberAnimation { target: field; property: "shakeOffset"; to: 12;  duration: 70 }
                        NumberAnimation { target: field; property: "shakeOffset"; to: -8;  duration: 60 }
                        NumberAnimation { target: field; property: "shakeOffset"; to: 6;   duration: 50 }
                        NumberAnimation { target: field; property: "shakeOffset"; to: 0;   duration: 40 }
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 14
                        enabled: !pam.active
                        focus: true

                        onAccepted: {
                            if (text.length > 0 && !pam.active) pam.start()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: pam.active ? "Checking..." : "Enter Password"
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font: input.font
                            visible: input.text === "" || pam.active
                        }
                    }
                }

                // Hint ved feil passord
                Text {
                    id: hint
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Incorrect password"
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.family: Tokens.fontFamily
                    font.pixelSize: 12
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
        }

        // ---------- Passordsjekk ----------
        PamContext {
            id: pam
            onResponseRequiredChanged: {
                if (responseRequired) respond(input.text)
            }
            onCompleted: result => {
                if (result === PamResult.Success) {
                    lock.unlock()
                } else {
                    input.text = ""
                    hint.opacity = 1
                    shake.restart()
                    input.forceActiveFocus()
                }
            }
        }

        // ---------- Inn-animasjon ----------
        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: tint; property: "opacity"; from: 0; to: 0.35; duration: 400; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 100 }
                ParallelAnimation {
                    NumberAnimation { target: clockBlock; property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }
                    NumberAnimation { target: clockBlock; property: "y"; from: surface.height * 0.12 - 30; to: surface.height * 0.12; duration: 450; easing.type: Easing.OutCubic }
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 250 }
                NumberAnimation { target: loginBlock; property: "opacity"; from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }
            }
        }

        Component.onCompleted: {
            enterAnim.start()
            input.forceActiveFocus()
        }
    }
}
