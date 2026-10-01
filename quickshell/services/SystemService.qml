pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0   // 0 til 1
    property real ram: 0   // 0 til 1

    // Forrige CPU-måling, for å regne ut forskjellen
    property real lastTotal: 0
    property real lastIdle: 0

    Process {
        id: proc
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                // CPU: "cpu  user nice system idle iowait irq softirq steal ..."
                const f = lines[0].trim().split(/\s+/).slice(1, 9).map(Number)
                const idle = f[3] + f[4]
                const total = f.reduce((a, b) => a + b, 0)
                if (root.lastTotal > 0) {
                    const dTotal = total - root.lastTotal
                    const dIdle = idle - root.lastIdle
                    if (dTotal > 0) root.cpu = 1 - dIdle / dTotal
                }
                root.lastTotal = total
                root.lastIdle = idle

                // RAM
                const memTotal = parseInt(lines[1].split(/\s+/)[1])
                const memAvail = parseInt(lines[2].split(/\s+/)[1])
                if (memTotal > 0) root.ram = 1 - memAvail / memTotal
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
