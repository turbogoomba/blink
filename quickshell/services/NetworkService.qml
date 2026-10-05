pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool wifiEnabled: false
    property bool connected: false
    property string ssid: ""
    property int signalStrength: 0
    property bool ethernetConnected: false
    property string ethernetName: ""
    property var networks: []
    property bool scanning: false
    property var savedNames: []        // Wi-Fi profiles NetworkManager already knows
    property string connectingSsid: "" // set while a connection attempt runs
    property string errorSsid: ""      // last attempt that failed, and why
    property string errorText: ""

    Component.onCompleted: refreshStatus()

    function refreshStatus() {
        if (!statusProc.running) statusProc.running = true
    }

    function scan() {
        scanning = true
        scanProc.running = true
    }

    function isSaved(name) { return savedNames.indexOf(name) >= 0 }

    // Open or password (WPA-PSK) networks. A saved network with no new password reuses its profile.
    function connectToNetwork(targetSsid, password) {
        if (password.length === 0 && isSaved(targetSsid))
            run(targetSsid, ["nmcli", "connection", "up", "id", targetSsid])
        else if (password.length > 0)
            run(targetSsid, ["nmcli", "device", "wifi", "connect", targetSsid, "password", password])
        else
            run(targetSsid, ["nmcli", "device", "wifi", "connect", targetSsid])
    }

    // Networks that ask for a username and password (WPA2-Enterprise, like Eduroam).
    // PEAP with MSCHAPv2 is what Eduroam and most schools and offices use.
    // An old profile with the same name is replaced, so new details always win.
    function connectEnterprise(targetSsid, user, password) {
        run(targetSsid, ["sh", "-c",
            'nmcli connection delete id "$1" >/dev/null 2>&1; '
            + 'nmcli connection add type wifi con-name "$1" ssid "$1" '
            + 'wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 '
            + '802-1x.identity "$2" 802-1x.password "$3" >/dev/null && nmcli connection up id "$1"',
            "sh", targetSsid, user, password])
    }

    function run(targetSsid, cmd) {
        if (connectProc.running) return
        errorSsid = ""
        errorText = ""
        connectingSsid = targetSsid
        connectProc.command = cmd
        connectProc.running = true
    }

    function toggleWifi() {
        toggleProc.enable = !wifiEnabled
        toggleProc.running = true
    }

    // LC_ALL=C gjør at nmcli svarer på engelsk ("yes"/"connected"),
    // uansett hvilket språk systemet er satt til.
    Process {
        id: statusProc
        command: ["sh", "-c",
            "export LC_ALL=C; " +
            "echo \"RADIO:$(nmcli -t -f WIFI general)\"; " +
            "nmcli -t -f TYPE,STATE,CONNECTION device | sed 's/^/DEV:/'; " +
            "nmcli -t -f IN-USE,SSID,SIGNAL device wifi list --rescan no | sed 's/^/WIFI:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let wifiOn = false
                let conn = false
                let ss = ""
                let sig = 0
                let eth = false
                let ethName = ""

                for (const line of text.split("\n")) {
                    if (line.startsWith("RADIO:")) {
                        wifiOn = line.slice(6).trim() === "enabled"
                    } else if (line.startsWith("DEV:")) {
                        const parts = line.slice(4).split(":")
                        const type = parts[0]
                        const state = parts[1]
                        const name = parts.slice(2).join(":")
                        if (type === "ethernet" && state === "connected") {
                            eth = true
                            ethName = name
                        }
                        if (type === "wifi" && state === "connected") {
                            conn = true
                            if (ss === "") ss = name
                        }
                    } else if (line.startsWith("WIFI:")) {
                        const p = line.slice(5).split(":")
                        if (p[0] === "*") {
                            conn = true
                            ss = p[1]
                            sig = parseInt(p[2]) || 0
                        }
                    }
                }

                root.wifiEnabled = wifiOn
                root.connected = conn
                root.ssid = ss
                root.signalStrength = sig
                root.ethernetConnected = eth
                root.ethernetName = ethName
            }
        }
    }

    Process {
        id: scanProc
        command: ["sh", "-c",
            "export LC_ALL=C; nmcli -t -f NAME,TYPE connection show | sed 's/^/SAVED:/'; "
            + "nmcli -t -f SSID,SIGNAL,SECURITY device wifi list --rescan yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const results = []
                const saved = []
                for (const line of text.split("\n")) {
                    if (line.startsWith("SAVED:")) {
                        const m = line.slice(6).match(/^(.*):(802-11-wireless|wifi)$/)
                        if (m) saved.push(m[1].replace(/\\:/g, ":"))
                        continue
                    }
                    const parts = line.split(":")
                    if (parts.length < 3 || parts[0] === "") continue
                    const security = parts.slice(2).join(":")
                    results.push({
                        ssid: parts[0],
                        signal: parseInt(parts[1]) || 0,
                        secured: security !== "" && security !== "--",
                        // "WPA2 802.1X" and friends: needs a username, not just a password
                        enterprise: /802\.1X|EAP/i.test(security)
                    })
                }
                root.savedNames = saved
                root.networks = results
                root.scanning = false
            }
        }
    }

    Process {
        id: connectProc
        environment: ({ LC_ALL: "C" })
        stderr: StdioCollector { id: connectErr }
        // Wait a tick so the error text has arrived before reading it
        onExited: code => Qt.callLater(() => root.finishConnect(code))
    }

    function finishConnect(code) {
        if (code !== 0) {
            // nmcli says "Error: <why>". Keep the first line, without "Error:".
            const msg = (connectErr.text || "").split("\n").find(l => l.trim() !== "") ?? ""
            root.errorText = msg.replace(/^Error:\s*/, "").trim() || "Could not connect"
            root.errorSsid = root.connectingSsid
        }
        root.connectingSsid = ""
        root.refreshStatus()
        if (!root.scanning) root.scan()
    }

    Process {
        id: toggleProc
        property bool enable: true
        command: ["nmcli", "radio", "wifi", enable ? "on" : "off"]
        onExited: root.refreshStatus()
    }

    // React when NetworkManager reports a change, instead of asking every 5 seconds
    Process {
        id: monitor
        running: true
        command: ["sh", "-c", "LC_ALL=C exec nmcli monitor"]
        stdout: SplitParser {
            onRead: line => changed.restart()
        }
        // NetworkManager restarted: start listening again
        onExited: restartMonitor.start()
    }

    // Several events come at once: refresh once after they settle
    Timer {
        id: changed
        interval: 400
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }

    // Signal strength changes without events: refresh often while a panel shows it, rarely otherwise
    Timer {
        interval: ShellState.controlCenterOpen || ShellState.settingsOpen ? 5000 : 60000
        running: true
        repeat: true
        onTriggered: root.refreshStatus()
    }
}
