pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Battery of USB-dongle headsets (SteelSeries Arctis, Logitech, Corsair ...)
// through HeadsetControl, since they do not report it to Bluetooth or UPower.
// Needs:  sudo pacman -S headsetcontrol   (or yay -S headsetcontrol)
//   HeadsetService.headsets -> [{ name, level (0-1), charging }]
Singleton {
    id: root

    property var headsets: []
    property bool available: true

    function parse(text) {
        if (text.trim() === "") { headsets = []; return }
        try {
            const data = JSON.parse(text)
            const list = []
            for (const d of data.devices ?? []) {
                const b = d.battery ?? {}
                const status = String(b.status ?? "")
                if (status !== "BATTERY_AVAILABLE" && status !== "BATTERY_CHARGING") continue
                const level = Number(b.level ?? -1)
                if (level < 0) continue
                list.push({
                    name: (d.product || d.device || "Headset").replace(/^SteelSeries\s+/i, ""),
                    level: Math.max(0, Math.min(1, level / 100)),
                    charging: status === "BATTERY_CHARGING"
                })
            }
            headsets = list
        } catch (e) {
            headsets = []
        }
    }

    Process {
        id: proc
        command: ["sh", "-c", "command -v headsetcontrol >/dev/null || exit 3; headsetcontrol -b -o json 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        onExited: code => { if (code === 3) root.available = false }
    }

    // Once a minute is plenty for a battery
    Timer {
        interval: 60000
        repeat: true
        running: root.available
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }
}
