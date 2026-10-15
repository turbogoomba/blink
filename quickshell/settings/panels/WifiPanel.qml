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
        x: 32
        y: 24
        width: panel.width - 64
        spacing: Theme.Tokens.spaceLg

        // ---------- Status ----------
        Rectangle {
            id: hero
            width: parent.width
            height: 88
            radius: 18
            readonly property bool on: NetworkService.wifiEnabled
            color: on ? Qt.rgba(Theme.Tokens.accent.r, Theme.Tokens.accent.g, Theme.Tokens.accent.b, 0.12) : Theme.Tokens.fillIdle
            border.width: 1
            border.color: on ? Qt.rgba(Theme.Tokens.accent.r, Theme.Tokens.accent.g, Theme.Tokens.accent.b, 0.35) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.Tokens.durNormal } }

            Rectangle {
                id: heroIcon
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 52
                radius: 16
                color: hero.on ? Theme.Tokens.accent : Theme.Tokens.fillStrong
                Behavior on color { ColorAnimation { duration: Theme.Tokens.durNormal } }
                Image {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    sourceSize: Qt.size(52, 52)
                    source: Quickshell.iconPath(hero.on ? "network-wireless-symbolic" : "network-wireless-disabled-symbolic", "network-wireless")
                }
            }

            Column {
                anchors.left: heroIcon.right
                anchors.leftMargin: 16
                anchors.right: toggle.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: !hero.on ? "Wi-Fi is off"
                        : NetworkService.connected && NetworkService.ssid !== "" ? "Connected to " + NetworkService.ssid
                        : NetworkService.connectingSsid !== "" ? "Connecting to " + NetworkService.connectingSsid + "..."
                        : "Not connected"
                    color: Theme.Tokens.textPrimary
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: {
                        const parts = []
                        if (hero.on && NetworkService.connected) {
                            const s = NetworkService.signalStrength
                            parts.push(s > 75 ? "Strong signal" : s > 50 ? "Good signal" : s > 25 ? "Fair signal" : "Weak signal")
                        } else if (hero.on) {
                            parts.push("Pick a network below")
                        } else {
                            parts.push("Turn it on to see networks")
                        }
                        if (NetworkService.ethernetConnected) parts.push("Ethernet connected")
                        return parts.join("  ·  ")
                    }
                    color: Theme.Tokens.textSecondary
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: 13
                }
            }

            // Switch
            Rectangle {
                id: toggle
                scale: toggleMouse.pressed ? Theme.Tokens.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 26
                radius: 13
                color: hero.on ? Theme.Tokens.accent : Theme.Tokens.fillStrong
                Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    y: 3
                    x: hero.on ? toggle.width - width - 3 : 3
                    color: "white"
                    Behavior on x { NumberAnimation { duration: Theme.Tokens.durNormal; easing.type: Theme.Tokens.easeMove } }
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
