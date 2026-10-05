import QtQuick
import Quickshell
import "../../services"
import "../../theme" as Theme

Flickable {
    id: panel
    contentHeight: col.implicitHeight + 56
    clip: true

    // Nettverket som viser passordfelt
    property string expanded: ""

    // Fjern duplikater (samme nettverk på flere frekvenser), sterkest først
    readonly property var networks: {
        const best = {}
        for (const n of NetworkService.networks) {
            if (!best[n.ssid] || n.signal > best[n.ssid].signal) best[n.ssid] = n
        }
        return Object.values(best).sort((a, b) => b.signal - a.signal)
    }

    function signalIcon(s) {
        if (s > 75) return "network-wireless-signal-excellent-symbolic"
        if (s > 50) return "network-wireless-signal-good-symbolic"
        if (s > 25) return "network-wireless-signal-ok-symbolic"
        return "network-wireless-signal-weak-symbolic"
    }

    Component.onCompleted: NetworkService.scan()

    Column {
        id: col
        x: 28
        y: 28
        width: panel.width - 56
        spacing: Theme.Tokens.spaceLg

        // ---------- Overskrift ----------
        Text {
            text: "Wi-Fi"
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontLarge
            font.weight: Font.DemiBold
        }

        // ---------- Av/på ----------
        Rectangle {
            width: parent.width
            height: 48
            radius: Theme.Tokens.radiusMd
            color: Theme.Tokens.fillIdle
            border.color: "transparent"
            border.width: 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.Tokens.spaceLg
                anchors.verticalCenter: parent.verticalCenter
                text: NetworkService.ethernetConnected
                    ? "Wi-Fi  ·  Ethernet connected"
                    : "Wi-Fi"
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
            }

            // Bryter
            Rectangle {
                id: toggle
                scale: toggleMouse.pressed ? Theme.Tokens.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                anchors.right: parent.right
                anchors.rightMargin: Theme.Tokens.spaceLg
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 22
                radius: 11
                color: NetworkService.wifiEnabled ? Theme.Tokens.accent : Theme.Tokens.fillStrong
                Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    y: 2
                    x: NetworkService.wifiEnabled ? toggle.width - width - 2 : 2
                    color: "white"
                    Behavior on x { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                }

                MouseArea {
                    id: toggleMouse
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: NetworkService.toggleWifi()
                }
            }
        }

        // ---------- Overskrift + oppdater ----------
        Item {
            width: parent.width
            height: 18
            visible: NetworkService.wifiEnabled

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.Tokens.spaceXs
                text: "Networks"
                color: Theme.Tokens.textSecondary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
                font.weight: Font.Medium
            }

            Text {
                scale: refreshMouse.pressed ? Theme.Tokens.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                anchors.right: parent.right
                anchors.rightMargin: Theme.Tokens.spaceXs
                text: NetworkService.scanning ? "Scanning..." : "Refresh"
                color: refreshMouse.containsMouse ? Theme.Tokens.textPrimary : Theme.Tokens.accent
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody

                MouseArea {
                    id: refreshMouse
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    enabled: !NetworkService.scanning
                    onClicked: NetworkService.scan()
                }
            }
        }

        // ---------- Nettverksliste ----------
        Rectangle {
            width: parent.width
            height: list.implicitHeight
            radius: Theme.Tokens.radiusMd
            color: Theme.Tokens.fillIdle
            border.color: "transparent"
            border.width: 1
            visible: NetworkService.wifiEnabled && panel.networks.length > 0

            Column {
                id: list
                width: parent.width

                Repeater {
                    model: panel.networks

                    delegate: Column {
                        id: net
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent:
                            NetworkService.connected && NetworkService.ssid === modelData.ssid
                        readonly property bool open: panel.expanded === modelData.ssid
                        readonly property bool last: index === panel.networks.length - 1

                        width: list.width

                        readonly property bool connecting: NetworkService.connectingSsid === modelData.ssid
                        readonly property bool failed: NetworkService.errorSsid === modelData.ssid

                        function join() {
                            if (net.modelData.enterprise) {
                                if (user.text.trim() === "" || pw.text === "") return
                                NetworkService.connectEnterprise(net.modelData.ssid, user.text.trim(), pw.text)
                            } else {
                                NetworkService.connectToNetwork(net.modelData.ssid, pw.text)
                            }
                            pw.text = ""
                            panel.expanded = ""
                        }

                        // Raden
                        Item {
                            scale: rowMouse.pressed ? Theme.Tokens.pressScale : 1
                            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                            width: parent.width
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Theme.Tokens.spaceXs
                                radius: Theme.Tokens.radiusSm
                                color: Theme.Tokens.fillIdle
                                visible: rowMouse.containsMouse && !net.isCurrent
                            }

                            MouseArea {
                                id: rowMouse
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !net.isCurrent
                                onClicked: {
                                    // Known networks connect straight away; after a failure, ask for details again
                                    if (net.modelData.secured && (!NetworkService.isSaved(net.modelData.ssid) || net.failed))
                                        panel.expanded = net.open ? "" : net.modelData.ssid
                                    else
                                        NetworkService.connectToNetwork(net.modelData.ssid, "")
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.Tokens.spaceLg
                                anchors.right: icons.left
                                anchors.rightMargin: Theme.Tokens.spaceMd
                                anchors.verticalCenter: parent.verticalCenter
                                text: net.modelData.ssid + (net.isCurrent ? "  ·  Connected" : net.connecting ? "  ·  Connecting..." : "")
                                color: Theme.Tokens.textPrimary
                                font.family: Theme.Tokens.fontFamily
                                font.pixelSize: Theme.Tokens.fontBody
                                font.weight: net.isCurrent ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Row {
                                id: icons
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.Tokens.spaceLg
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.Tokens.spaceSm

                                Image {
                                    visible: net.modelData.secured
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    sourceSize: Qt.size(28, 28)
                                    source: Quickshell.iconPath("changes-prevent-symbolic", "lock")
                                }
                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18
                                    sourceSize: Qt.size(36, 36)
                                    source: Quickshell.iconPath(panel.signalIcon(net.modelData.signal))
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.Tokens.spaceLg
                                anchors.right: parent.right
                                height: 1
                                color: Theme.Tokens.divider
                                visible: !net.last || net.open
                            }
                        }

                        // Why the last attempt failed
                        Text {
                            visible: net.failed && !net.connecting
                            width: parent.width
                            leftPadding: Theme.Tokens.spaceLg
                            rightPadding: Theme.Tokens.spaceLg
                            bottomPadding: Theme.Tokens.spaceSm
                            wrapMode: Text.WordWrap
                            text: "Could not connect: " + NetworkService.errorText
                            color: Theme.Tokens.red
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: Theme.Tokens.fontSmall
                        }

                        // Login: username (school and work networks) and password
                        Column {
                            visible: net.open
                            width: parent.width
                            spacing: Theme.Tokens.spaceSm
                            topPadding: Theme.Tokens.spaceSm
                            bottomPadding: Theme.Tokens.spaceMd

                            Text {
                                visible: net.modelData.enterprise
                                leftPadding: Theme.Tokens.spaceLg
                                text: "This network asks for a username and password, like Eduroam."
                                color: Theme.Tokens.textSecondary
                                font.family: Theme.Tokens.fontFamily
                                font.pixelSize: Theme.Tokens.fontSmall
                            }

                            Rectangle {
                                visible: net.modelData.enterprise
                                x: Theme.Tokens.spaceLg
                                width: parent.width - 2 * Theme.Tokens.spaceLg - 64 - Theme.Tokens.spaceSm
                                height: 30
                                radius: Theme.Tokens.radiusSm
                                color: Theme.Tokens.fillIdle
                                border.color: user.activeFocus ? Theme.Tokens.accent : "transparent"
                                border.width: 1

                                TextInput {
                                    id: user
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.Tokens.spaceMd
                                    anchors.rightMargin: Theme.Tokens.spaceMd
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.Tokens.textPrimary
                                    selectionColor: Theme.Tokens.accent
                                    font.family: Theme.Tokens.fontFamily
                                    font.pixelSize: Theme.Tokens.fontBody
                                    clip: true
                                    focus: net.open && net.modelData.enterprise
                                    KeyNavigation.tab: pw
                                    onAccepted: pw.forceActiveFocus()

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: net.modelData.ssid.toLowerCase() === "eduroam" ? "Username (name@school.no)" : "Username"
                                        color: Theme.Tokens.textSecondary
                                        font: user.font
                                        visible: user.text === ""
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 30

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.Tokens.spaceLg
                                    anchors.right: joinBtn.left
                                    anchors.rightMargin: Theme.Tokens.spaceSm
                                    height: 30
                                    radius: Theme.Tokens.radiusSm
                                    color: Theme.Tokens.fillIdle
                                    border.color: pw.activeFocus ? Theme.Tokens.accent : "transparent"
                                    border.width: 1

                                    TextInput {
                                        id: pw
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.Tokens.spaceMd
                                        anchors.rightMargin: Theme.Tokens.spaceMd
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Password
                                        color: Theme.Tokens.textPrimary
                                        selectionColor: Theme.Tokens.accent
                                        font.family: Theme.Tokens.fontFamily
                                        font.pixelSize: Theme.Tokens.fontBody
                                        clip: true
                                        focus: net.open && !net.modelData.enterprise
                                        onAccepted: net.join()

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Password"
                                            color: Theme.Tokens.textSecondary
                                            font: pw.font
                                            visible: pw.text === ""
                                        }
                                    }
                                }

                                Rectangle {
                                    id: joinBtn
                                    readonly property bool ready: pw.text !== "" && (!net.modelData.enterprise || user.text.trim() !== "")
                                    scale: joinBtnMouse.pressed ? Theme.Tokens.pressScale : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.Tokens.spaceLg
                                    width: 64
                                    height: 30
                                    radius: Theme.Tokens.radiusSm
                                    color: Theme.Tokens.accent
                                    opacity: ready ? 1 : 0.5

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Join"
                                        color: Theme.Tokens.onAccent
                                        font.family: Theme.Tokens.fontFamily
                                        font.pixelSize: Theme.Tokens.fontBody
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        id: joinBtnMouse
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        anchors.fill: parent
                                        enabled: joinBtn.ready
                                        onClicked: net.join()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
