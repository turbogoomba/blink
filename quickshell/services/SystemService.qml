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

    // Read /proc directly, so no shell is started every 2 seconds.
    // If that ever comes back empty, fall back to the old way (a small shell command).
    property bool useFallback: false

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true; printErrors: false }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true; printErrors: false }

    function parse(stat, mem) {
        // CPU: "cpu  user nice system idle iowait irq softirq steal ..."
        const f = stat.split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number)
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
        const memTotal = /MemTotal:\s+(\d+)/.exec(mem)
        const memAvail = /MemAvailable:\s+(\d+)/.exec(mem)
        if (memTotal && memAvail) root.ram = 1 - parseInt(memAvail[1]) / parseInt(memTotal[1])
    }

    function sample() {
        if (useFallback) {
            fallback.running = true
            return
        }
        statFile.reload()
        memFile.reload()
        const stat = statFile.text()
        const mem = memFile.text()
        if (!stat || !mem) {
            useFallback = true
            fallback.running = true
            return
        }
        parse(stat, mem)
    }

    Process {
        id: fallback
        command: ["sh", "-c", "head -1 /proc/stat; echo; cat /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const i = text.indexOf("\n")
                root.parse(text.slice(0, i), text.slice(i + 1))
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }
}
