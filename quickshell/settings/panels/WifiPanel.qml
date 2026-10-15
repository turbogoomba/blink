import QtQuick
import Quickshell
import "../../services"
import "../../bar"
import "../../theme" as Theme

// Wi-Fi page: status card (with details), known and other networks,
// and a form for school/work networks like Eduroam.
Flickable {
    id: panel
    contentHeight: col.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // The network whose password field is open
    property string expanded: ""
    property bool detailsOpen: false

    readonly property color accent: Theme.Tokens.accent
    readonly property color card: Theme.Tokens.cardBg
    readonly property color line: Theme.Tokens.ink(0.05)
    function soft(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }

    // One entry per name (the same network on several bands), strongest first
    readonly property var networks: {
        const best = {}
        for (const n of NetworkService.networks)
            if (!best[n.ssid] || n.signal > best[n.ssid].signal) best[n.ssid] = n
        return Object.values(best).sort((a, b) => b.signal - a.signal)
    }
    function isCurrent(n) { return NetworkService.connected && NetworkService.ssid === n.ssid }
    readonly property var known: networks.filter(n => isCurrent(n) || NetworkService.savedNames.indexOf(n.ssid) >= 0)
        .sort((a, b) => (isCurrent(b) ? 1 : 0) - (isCurrent(a) ? 1 : 0))
    readonly property var others: networks.filter(n => known.indexOf(n) < 0)

    readonly property var icons: ({
        s0: "M12 19h.01",
        s1: "M8.5 16a5 5 0 0 1 7 0M12 19h.01",
        s2: "M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19h.01",
        s3: "M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19h.01",
        off: "M2 9a15 15 0 0 1 4.5-3M9.5 4.6A15 15 0 0 1 22 9M5 12.5a10 10 0 0 1 3-2M8.5 16a5 5 0 0 1 7 0M12 19h.01M3 3l18 18",
        lock: "M6 11h12v9H6zM9 11V8a3 3 0 0 1 6 0v3",
        refresh: "M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5",
        school: "M3 21h18M5 21V9l7-5 7 5v12M10 21v-5h4v5"
    })
    function signalIcon(s) { return s > 75 ? icons.s3 : s > 50 ? icons.s2 : s > 25 ? icons.s1 : icons.s0 }

    // ---------- School / work form ----------
    property string eapSsid: "eduroam"
    property bool eapAdvanced: false
    property string eapMethod: "peap"
    property bool eapCheckCert: true
    // Guess the domain from the username (name@school.no -> school.no)
    readonly property string eapDomainGuess: {
        const at = eapUser.text.indexOf("@")
        return at >= 0 ? eapUser.text.slice(at + 1).trim() : ""
    }

    function openEnterprise(name) {
        eapSsid = name
        eapNet.text = name
        expanded = ""
        contentY = Math.max(0, Math.min(contentHeight - height, eduCard.y + col.y - 16))
        eapUser.focusInput()
    }

    function joinEnterprise() {
        if (eapUser.text.trim() === "" || eapPass.text === "") return
        const domain = eapDomain.text.trim() || eapDomainGuess
        NetworkService.connectEnterprise(eapSsid, eapUser.text.trim(), eapPass.text, {
            method: eapMethod,
            domain: eapCheckCert ? domain : "",
            anonymous: eapAnon.text.trim() || (domain ? "anonymous@" + domain : ""),
            systemCa: eapCheckCert
        })
        eapPass.text = ""
    }

    Component.onCompleted: {
        NetworkService.refreshStatus()
        NetworkService.scan()
    }

    // ================= Building blocks =================

    component Card: Rectangle {
        default property alias content: inner.data
        width: col.width
        height: inner.implicitHeight
        radius: 16
        color: panel.card
        clip: true
        Column {
            id: inner
            width: parent.width
        }
    }

    component SectionHeader: Item {
        id: sh
        property string text: ""
        property string action: ""
        property bool busy: false
        signal clicked()
        width: col.width
        height: 22

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: sh.text.toUpperCase()
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 0.7
        }

        Row {
            visible: sh.action !== ""
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: sh.busy
                size: 14
                tint: panel.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sh.busy ? "Scanning" : sh.action
                color: shMouse.containsMouse ? Theme.Tokens.textPrimary : panel.accent
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                MouseArea {
                    id: shMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    enabled: !sh.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sh.clicked()
                }
            }
        }
    }

    // Refresh arrow that spins while something is running
    component Spinner: LineIcon {
        id: sp
        property bool running: false
        d: panel.icons.refresh
        RotationAnimation on rotation {
            running: sp.running
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
            onRunningChanged: if (!running) sp.rotation = 0
        }
    }

    component Switch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        width: 44
        height: 26
        radius: 13
        color: checked ? panel.accent : Theme.Tokens.fillStrong
        scale: swMouse.pressed ? Theme.Tokens.pressScale : 1
        Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
        Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
        Rectangle {
            width: 20
            height: 20
            radius: 10
            y: 3
            x: sw.checked ? sw.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: Theme.Tokens.durNormal; easing.type: Theme.Tokens.easeMove } }
        }
        MouseArea {
            id: swMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    // Small rounded button. kind: "plain", "accent", "soft" or "danger"
    component Pill: Rectangle {
        id: pl
        property string text: ""
        property string kind: "plain"
        property bool busy: false
        signal clicked()
        width: plRow.implicitWidth + 24
        height: 30
        radius: 9
        color: kind === "accent" ? (plMouse.containsMouse ? Qt.lighter(panel.accent, 1.08) : panel.accent)
             : kind === "soft" ? panel.soft(0.18)
             : kind === "danger" ? Qt.rgba(1, 0.27, 0.23, plMouse.containsMouse ? 0.26 : 0.16)
             : plMouse.containsMouse ? Theme.Tokens.fillStrong : Theme.Tokens.fillHover
        scale: plMouse.pressed ? Theme.Tokens.pressScale : 1
        Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
        Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }

        Row {
            id: plRow
            anchors.centerIn: parent
            spacing: 6
            Spinner {
                visible: pl.busy
                anchors.verticalCenter: parent.verticalCenter
                running: pl.busy
                size: 13
                tint: plText.color
            }
            Text {
                id: plText
                anchors.verticalCenter: parent.verticalCenter
                text: pl.text
                color: pl.kind === "accent" ? Theme.Tokens.onAccent
                     : pl.kind === "soft" ? panel.accent
                     : pl.kind === "danger" ? "#ff6961"
                     : Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
        MouseArea {
            id: plMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !pl.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: pl.clicked()
        }
    }

    // Text field with a label above it
    component Field: Column {
        id: fld
        property string label: ""
        property string placeholder: ""
        property alias text: input.text
        property bool secret: false
        property bool error: false
        signal accepted()
        function focusInput() { input.forceActiveFocus() }
        spacing: 6

        Text {
            visible: fld.label !== ""
            text: fld.label
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 12
        }
        Rectangle {
            width: fld.width
            height: 38
            radius: 10
            color: Theme.Tokens.ink(0.05)
            border.width: 1
            border.color: fld.error ? "#ff6961" : input.activeFocus ? panel.accent : Theme.Tokens.ink(0.08)
            Behavior on border.color { ColorAnimation { duration: Theme.Tokens.durFast } }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.Tokens.textPrimary
                selectionColor: panel.accent
                selectedTextColor: Theme.Tokens.onAccent
                echoMode: fld.secret ? TextInput.Password : TextInput.Normal
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: 14
                clip: true
                onAccepted: fld.accepted()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: fld.placeholder
                    color: Theme.Tokens.textSecondary
                    opacity: 0.7
                    font: input.font
                }
            }
        }
    }

    // A label and a value, for the details card
    component InfoRow: Item {
        property string label: ""
        property string value: ""
        width: col.width
        height: 44
        visible: value !== ""
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 13
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            height: 1
            color: panel.line
        }
    }

    // One network in a list
    component NetworkRow: Column {
        id: row
        required property var modelData
        required property int index
        property int count: 0
        readonly property var net: modelData
        readonly property bool current: panel.isCurrent(net)
        readonly property bool saved: NetworkService.savedNames.indexOf(net.ssid) >= 0
        readonly property bool connecting: NetworkService.connectingSsid === net.ssid
        readonly property bool failed: NetworkService.errorSsid === net.ssid
        readonly property bool open: panel.expanded === net.ssid
        width: col.width

        function activate() {
            if (current) { panel.detailsOpen = !panel.detailsOpen; return }
            if (net.enterprise) { panel.openEnterprise(net.ssid); return }
            if (net.secured && (!saved || failed)) {
                const opening = !open
                panel.expanded = opening ? net.ssid : ""
                if (opening) Qt.callLater(() => pw.focusInput())
                return
            }
            NetworkService.connectToNetwork(net.ssid, "")
        }
        function join() {
            if (pw.text === "") return
            NetworkService.connectToNetwork(net.ssid, pw.text)
            pw.text = ""
            panel.expanded = ""
        }

        Item {
            width: parent.width
            height: 56

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 10
                color: Theme.Tokens.fillIdle
                opacity: rowMouse.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.Tokens.durFast } }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.activate()
            }

            LineIcon {
                id: sig
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                d: panel.signalIcon(row.net.signal)
                tint: row.current ? panel.accent : Theme.Tokens.textPrimary
                size: 18
            }

            Column {
                anchors.left: sig.right
                anchors.leftMargin: 14
                anchors.right: rightSide.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.net.ssid
                    color: Theme.Tokens.textPrimary
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.connecting ? "Connecting..."
                        : row.failed ? NetworkService.errorText
                        : row.current ? "Connected"
                        : row.net.enterprise ? "School or work login"
                        : row.saved ? "Saved"
                        : row.net.secured ? "Secured" : "Open network"
                    color: row.failed ? "#ff6961" : Theme.Tokens.textSecondary
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: 12
                }
            }

            Row {
                id: rightSide
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                LineIcon {
                    visible: row.net.secured
                    anchors.verticalCenter: parent.verticalCenter
                    d: row.net.enterprise ? panel.icons.school : panel.icons.lock
                    tint: Theme.Tokens.textSecondary
                    size: 14
                }
                Pill {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.current ? "Connected" : row.connecting ? "Connecting" : row.open ? "Cancel" : "Connect"
                    kind: row.current ? "soft" : "plain"
                    busy: row.connecting
                    onClicked: {
                        if (row.open) panel.expanded = ""
                        else row.activate()
                    }
                }
            }

            Rectangle {
                visible: row.index < row.count - 1 && !row.open
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 48
                anchors.right: parent.right
                height: 1
                color: panel.line
            }
        }

        // Password, slides open under the row
        Item {
            width: parent.width
            height: row.open ? form.implicitHeight + 16 : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Theme.Tokens.durNormal; easing.type: Theme.Tokens.easeMove } }

            Row {
                id: form
                x: 48
                width: parent.width - 48 - 16
                spacing: 8
                Field {
                    id: pw
                    width: form.width - joinBtn.width - 8
                    placeholder: "Password for " + row.net.ssid
                    secret: true
                    error: row.failed
                    onAccepted: row.join()
                }
                Pill {
                    id: joinBtn
                    height: 38
                    text: "Join"
                    kind: "accent"
                    onClicked: row.join()
                }
            }
        }
    }

    // ================= The page =================
    Column {
        id: col
        x: 32
        y: 24
        width: panel.width - 64
        spacing: 14

        // ---------- Status ----------
        Rectangle {
            id: hero
            width: parent.width
            height: 88
            radius: 18
            readonly property bool on: NetworkService.wifiEnabled
            color: on ? panel.soft(0.12) : Theme.Tokens.fillIdle
            border.width: 1
            border.color: on ? panel.soft(0.35) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.Tokens.durNormal } }

            Rectangle {
                id: heroIcon
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 52
                radius: 16
                color: hero.on ? panel.accent : Theme.Tokens.fillStrong
                Behavior on color { ColorAnimation { duration: Theme.Tokens.durNormal } }
                LineIcon {
                    anchors.centerIn: parent
                    d: !hero.on ? panel.icons.off : NetworkService.connected ? panel.signalIcon(NetworkService.signalStrength) : panel.icons.s3
                    tint: hero.on ? Theme.Tokens.onAccent : Theme.Tokens.textSecondary
                    size: 26
                }
            }

            Column {
                anchors.left: heroIcon.right
                anchors.leftMargin: 16
                anchors.right: heroActions.left
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
                            if (NetworkService.details.band) parts.push(NetworkService.details.band)
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

            Row {
                id: heroActions
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                Pill {
                    visible: hero.on && NetworkService.connected
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.detailsOpen ? "Hide details" : "Details"
                    onClicked: panel.detailsOpen = !panel.detailsOpen
                }
                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: hero.on
                    onToggled: NetworkService.toggleWifi()
                }
            }
        }

        // ---------- Details of the connected network ----------
        Item {
            width: parent.width
            height: panel.detailsOpen && NetworkService.connected ? detailsCard.height : 0
            visible: height > 0
            clip: true
            Behavior on height { NumberAnimation { duration: Theme.Tokens.durNormal; easing.type: Theme.Tokens.easeMove } }

            Card {
                id: detailsCard
                InfoRow { label: "IP address"; value: NetworkService.details.ip }
                InfoRow { label: "Band"; value: NetworkService.details.band }
                InfoRow { label: "Security"; value: NetworkService.details.security }
                Item {
                    width: col.width
                    height: 56
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: "Join automatically"
                            color: Theme.Tokens.textPrimary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        Text {
                            text: "Connect to this network when it is in range"
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 12
                        }
                    }
                    Switch {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        checked: NetworkService.details.autoconnect
                        onToggled: NetworkService.setAutoconnect(NetworkService.ssid, !checked)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        height: 1
                        color: panel.line
                    }
                }
                Item {
                    width: col.width
                    height: 58
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Pill {
                            text: "Disconnect"
                            onClicked: NetworkService.disconnect()
                        }
                        Pill {
                            text: "Forget network"
                            kind: "danger"
                            onClicked: {
                                NetworkService.forget(NetworkService.ssid)
                                panel.detailsOpen = false
                            }
                        }
                    }
                }
            }
        }

        // ---------- Known networks ----------
        Item { width: 1; height: 4; visible: hero.on }

        SectionHeader {
            visible: hero.on && panel.known.length > 0
            text: "Known networks"
            action: "Scan again"
            busy: NetworkService.scanning
            onClicked: NetworkService.scan()
        }
        Card {
            visible: hero.on && panel.known.length > 0
            Repeater {
                model: panel.known
                delegate: NetworkRow { count: panel.known.length }
            }
        }

        // ---------- Other networks ----------
        SectionHeader {
            visible: hero.on
            text: "Other networks"
            action: panel.known.length > 0 ? "" : "Scan again"
            busy: NetworkService.scanning
            onClicked: NetworkService.scan()
        }
        Card {
            visible: hero.on && panel.others.length > 0
            Repeater {
                model: panel.others
                delegate: NetworkRow { count: panel.others.length }
            }
        }

        // Nothing found (yet)
        Card {
            visible: hero.on && panel.others.length === 0
            Item {
                width: col.width
                height: 96
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Spinner {
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: NetworkService.scanning
                        visible: NetworkService.scanning
                        size: 20
                        tint: panel.accent
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: NetworkService.scanning ? "Looking for networks..." : "No other networks nearby"
                        color: Theme.Tokens.textSecondary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: 13
                    }
                }
            }
        }

        // ---------- School / work network ----------
        Item { width: 1; height: 4 }

        SectionHeader { text: "School or work network" }
        Card {
            id: eduCard
            Column {
                x: 18
                width: col.width - 36
                topPadding: 18
                bottomPadding: 18
                spacing: 14

                Row {
                    spacing: 12
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 10
                        color: panel.soft(0.16)
                        LineIcon {
                            anchors.centerIn: parent
                            d: panel.icons.school
                            tint: panel.accent
                            size: 18
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "Connect to " + (panel.eapSsid || "a network")
                            color: Theme.Tokens.textPrimary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Networks like Eduroam that ask for your school or work login"
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12
                    Field {
                        id: eapNet
                        width: (parent.width - 12) / 2
                        label: "Network"
                        text: panel.eapSsid
                        onTextChanged: panel.eapSsid = text
                    }
                    Column {
                        width: (parent.width - 12) / 2
                        spacing: 6
                        Text {
                            text: "Method"
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: 12
                        }
                        Rectangle {
                            width: parent.width
                            height: 38
                            radius: 10
                            color: Theme.Tokens.ink(0.05)
                            Row {
                                id: methodRow
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 3
                                Repeater {
                                    model: [{ id: "peap", label: "PEAP" }, { id: "ttls", label: "TTLS" }]
                                    delegate: Rectangle {
                                        id: methodOpt
                                        required property var modelData
                                        readonly property bool on: panel.eapMethod === modelData.id
                                        width: (methodRow.width - 3) / 2
                                        height: methodRow.height
                                        radius: 8
                                        color: on ? Theme.Tokens.fillStrong : mMouse.containsMouse ? Theme.Tokens.fillIdle : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: methodOpt.modelData.label
                                            color: methodOpt.on ? Theme.Tokens.textPrimary : Theme.Tokens.textSecondary
                                            font.family: Theme.Tokens.fontFamily
                                            font.pixelSize: 13
                                            font.weight: methodOpt.on ? Font.DemiBold : Font.Normal
                                        }
                                        MouseArea {
                                            id: mMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: panel.eapMethod = methodOpt.modelData.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12
                    Field {
                        id: eapUser
                        width: (parent.width - 12) / 2
                        label: "Username"
                        placeholder: "name@school.no"
                        error: NetworkService.errorSsid === panel.eapSsid
                        onAccepted: eapPass.focusInput()
                    }
                    Field {
                        id: eapPass
                        width: (parent.width - 12) / 2
                        label: "Password"
                        secret: true
                        error: NetworkService.errorSsid === panel.eapSsid
                        onAccepted: panel.joinEnterprise()
                    }
                }

                // Advanced
                Text {
                    text: panel.eapAdvanced ? "Hide advanced"
                        : "Advanced  ·  domain " + (eapDomain.text || panel.eapDomainGuess || "from your username")
                    color: advMouse.containsMouse ? Theme.Tokens.textPrimary : panel.accent
                    font.family: Theme.Tokens.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    MouseArea {
                        id: advMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.eapAdvanced = !panel.eapAdvanced
                    }
                }

                Column {
                    visible: panel.eapAdvanced
                    width: parent.width
                    spacing: 14
                    Row {
                        width: parent.width
                        spacing: 12
                        Field {
                            id: eapDomain
                            width: (parent.width - 12) / 2
                            label: "Server domain"
                            placeholder: panel.eapDomainGuess || "school.no"
                        }
                        Field {
                            id: eapAnon
                            width: (parent.width - 12) / 2
                            label: "Anonymous identity"
                            placeholder: "anonymous@" + (eapDomain.text || panel.eapDomainGuess || "school.no")
                        }
                    }
                    Item {
                        width: parent.width
                        height: 40
                        Column {
                            anchors.left: parent.left
                            anchors.right: certSwitch.left
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: "Check the server certificate"
                                color: Theme.Tokens.textPrimary
                                font.family: Theme.Tokens.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: "Uses the system certificates and the domain above. Safer, and what Eduroam expects."
                                color: Theme.Tokens.textSecondary
                                font.family: Theme.Tokens.fontFamily
                                font.pixelSize: 12
                            }
                        }
                        Switch {
                            id: certSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: panel.eapCheckCert
                            onToggled: panel.eapCheckCert = !panel.eapCheckCert
                        }
                    }
                }

                // Error + buttons
                Item {
                    width: parent.width
                    height: 36
                    Text {
                        anchors.left: parent.left
                        anchors.right: eapButtons.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: NetworkService.errorSsid === panel.eapSsid
                        elide: Text.ElideRight
                        text: NetworkService.errorText
                        color: "#ff6961"
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: 12
                    }
                    Row {
                        id: eapButtons
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Pill {
                            visible: NetworkService.savedNames.indexOf(panel.eapSsid) >= 0
                            height: 36
                            text: "Forget"
                            onClicked: NetworkService.forget(panel.eapSsid)
                        }
                        Pill {
                            height: 36
                            text: NetworkService.connectingSsid === panel.eapSsid ? "Connecting" : "Connect"
                            kind: "accent"
                            busy: NetworkService.connectingSsid === panel.eapSsid
                            opacity: eapUser.text.trim() !== "" && eapPass.text !== "" ? 1 : 0.5
                            onClicked: panel.joinEnterprise()
                        }
                    }
                }
            }
        }
    }
}
