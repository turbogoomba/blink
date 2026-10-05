import QtQuick
import QtQuick.Effects

// Blink login screen for SDDM (Qt 6)
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#101012"

    readonly property string fontFamily: "IBM Plex Sans"
    readonly property string userName: userModel.lastUser
    readonly property string displayName: config.displayName || userName
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool failed: false
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.failed = true
            password.text = ""
            shake.restart()
            failTimer.restart()
        }
    }

    Timer {
        id: failTimer
        interval: 2000
        onTriggered: root.failed = false
    }

    function login() {
        if (password.text.length > 0)
            sddm.login(root.userName, password.text, root.sessionIndex)
    }

    // ---------- Background ----------
    Image {
        id: bg
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: bg
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        autoPaddingEnabled: false
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Number(config.dim) || 0.35
    }

    // ---------- Top bar ----------
    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 22
        text: sddm.hostName
        color: Qt.rgba(0.9, 0.9, 0.91, 0.85)
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 22
        text: Qt.formatDateTime(root.now, "ddd d MMM  HH:mm")
        color: Qt.rgba(0.9, 0.9, 0.91, 0.85)
        font.family: root.fontFamily
        font.pixelSize: 14
    }

    // ---------- Center: avatar, name, password, session ----------
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        spacing: 14

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 104
            height: 104
            radius: 52
            color: "#3a3a3c"
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.displayName.charAt(0).toUpperCase()
                color: "#e5e5e7"
                font.family: root.fontFamily
                font.pixelSize: 42
                font.weight: Font.Medium
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.displayName
            color: "#e5e5e7"
            font.family: root.fontFamily
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        // Password pill
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260
            height: 38

            Rectangle {
                id: pill
                width: parent.width
                height: parent.height
                radius: 19
                color: root.failed ? Qt.rgba(1, 0.41, 0.38, 0.14) : Qt.rgba(1, 1, 1, 0.12)
                border.color: root.failed ? Qt.rgba(1, 0.41, 0.38, 0.55) : Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                TextInput {
                    id: password
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: go.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: "#e5e5e7"
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    clip: true
                    focus: true
                    Keys.onReturnPressed: root.login()
                    Keys.onEnterPressed: root.login()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text.length === 0
                        text: "Enter Password"
                        color: Qt.rgba(0.9, 0.9, 0.91, 0.6)
                        font: password.font
                    }
                }

                Rectangle {
                    id: go
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: 15
                    color: goMouse.pressed ? "#4f97c2" : "#5fa8d3"

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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.login()
                    }
                }

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: pill; property: "x"; to: -10; duration: 50 }
                    NumberAnimation { target: pill; property: "x"; to: 10; duration: 70 }
                    NumberAnimation { target: pill; property: "x"; to: -6; duration: 60 }
                    NumberAnimation { target: pill; property: "x"; to: 6; duration: 60 }
                    NumberAnimation { target: pill; property: "x"; to: 0; duration: 50 }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Wrong password"
            color: "#ff8a83"
            font.family: root.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            opacity: root.failed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Session picker: click to cycle
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: sessionRow.implicitWidth + 24
            height: 26
            radius: 13
            color: sessionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)

            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: sessionModel
                    delegate: Text {
                        visible: index === root.sessionIndex
                        text: name
                        color: Qt.rgba(0.9, 0.9, 0.91, 0.85)
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }
                }

                Text {
                    text: "⌄"
                    color: Qt.rgba(0.9, 0.9, 0.91, 0.85)
                    font.pixelSize: 12
                }
            }

            MouseArea {
                id: sessionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
            }
        }
    }

    // ---------- Power buttons ----------
    component PowerButton: Column {
        id: pb
        property string label: ""
        property string glyph: ""
        signal clicked()
        spacing: 8

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: 44
            radius: 22
            color: pbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.12)
            scale: pbMouse.pressed ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: pb.glyph
                color: "#e5e5e7"
                font.pixelSize: 18
            }

            MouseArea {
                id: pbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pb.clicked()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: pb.label
            color: Qt.rgba(0.9, 0.9, 0.91, 0.85)
            font.family: root.fontFamily
            font.pixelSize: 12
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 40

        PowerButton {
            visible: sddm.canSuspend
            label: "Sleep"
            glyph: "☾"
            onClicked: sddm.suspend()
        }
        PowerButton {
            visible: sddm.canReboot
            label: "Restart"
            glyph: "↻"
            onClicked: sddm.reboot()
        }
        PowerButton {
            visible: sddm.canPowerOff
            label: "Shut Down"
            glyph: "⏻"
            onClicked: sddm.powerOff()
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
