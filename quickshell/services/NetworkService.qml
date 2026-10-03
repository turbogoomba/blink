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

    Component.onCompleted: refreshStatus()

    function refreshStatus() {
        if (!statusProc.running) statusProc.running = true
    }

    function scan() {
        scanning = true
        scanProc.running = true
    }

    function connectToNetwork(targetSsid, password) {
        connectProc.ssidArg = targetSsid
        connectProc.passwordArg = password
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
            "export LC_ALL=C; nmcli -t -f SSID,SIGNAL,SECURITY device wifi list --rescan yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const results = []
                for (const line of text.split("\n")) {
                    const parts = line.split(":")
                    if (parts.length < 3 || parts[0] === "") continue
                    results.push({
                        ssid: parts[0],
                        signal: parseInt(parts[1]) || 0,
                        secured: parts[2] !== "" && parts[2] !== "--"
                    })
                }
                root.networks = results
                root.scanning = false
            }
        }
    }

    Process {
        id: connectProc
        property string ssidArg: ""
        property string passwordArg: ""
        command: passwordArg.length > 0
            ? ["nmcli", "device", "wifi", "connect", ssidArg, "password", passwordArg]
            : ["nmcli", "device", "wifi", "connect", ssidArg]
        onExited: root.refreshStatus()
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
