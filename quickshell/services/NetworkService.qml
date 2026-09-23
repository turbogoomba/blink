pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import QtQml

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
        statusProcess.running = true
    }

    function scan() {
        scanning = true
        scanProcess.running = true
	}

	function connectToNetwork(targetSsid, password) {
		connectProcess.ssidArg = targetSsid
		connectProcess.passwordArg = password
		connectProcess.running = true
	}

	function toggleWifi() {
		toggleProcess.enable = !wifiEnabled
		toggleProcess.running = true
	}

    Process {
        id: statusProcess
        command: ["bash", "-c",
            "echo WIFI:$(nmcli -t -f WIFI g); " +
            "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi; " +
            "echo ETH:$(nmcli -t -f TYPE,STATE,CONNECTION dev | grep '^ethernet')"]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("WIFI:")) {
                    root.wifiEnabled = line.substring(5).trim() === "enabled"
                    return
                }
                if (line.startsWith("ETH:")) {
                    const ethPart = line.substring(4).trim()
                    if (ethPart === "") {
                        root.ethernetConnected = false
                        root.ethernetName = ""
                        return
                    }
                    const ethBits = ethPart.split(":")
                    root.ethernetName = ethBits[2] || ""
                    root.ethernetConnected = ethBits[1] === "connected"
                    return
                }
                const parts = line.split(":")
                if (parts.length < 3) return
                if (parts[0] === "yes") {
                    root.connected = true
                    root.ssid = parts[1]
                    root.signalStrength = parseInt(parts[2]) || 0
                }
            }
        }
    }

    Process {
        id: scanProcess
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
        property var results: []
        onRunningChanged: {
            if (running) results = []
        }
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(":")
                if (parts.length < 3 || parts[0] === "") return
                scanProcess.results.push({
                    ssid: parts[0],
                    signal: parseInt(parts[1]) || 0,
                    secured: parts[2] !== "" && parts[2] !== "--"
                })
            }
        }
        onExited: {
            root.networks = scanProcess.results
            root.scanning = false
        }
	}

	Process {
		id: connectProcess
		property string ssidArg: ""
		property string passwordArg: ""
		command: passwordArg.length > 0
			? ["nmcli", "dev", "wifi", "connect", ssidArg, "password", passwordArg]
			: ["nmcli", "dev", "wifi", "connect", ssidArg]
		onExited: exitCode => {
			if (exitCode === 0) root.refreshStatus()
		}

	}

	Process {
		id: toggleProcess
		property bool enable: true
		command: ["nmcli", "radio", "wifi", enable ? "on" : "off"]
		onExited: root.refreshStatus()
	}

	Timer {
		interval: 5000
		running: true
		repeat: true
		onTriggered: root.refreshStatus()
	}
}
