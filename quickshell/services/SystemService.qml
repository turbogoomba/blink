pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0   // 0 til 1
    property real ram: 0   // 0 til 1
    property real ramUsedGb: 0
    property real ramTotalGb: 0

    // Last 60 samples (2 minutes) for the graphs in the drawer
    readonly property int historyLength: 60
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property var netDownHistory: []

    // Extra numbers, only measured while the drawer is open (set `detailed`)
    property bool detailed: false
    property real gpu: -1          // 0 til 1, -1 = unknown
    property real cpuTemp: -1      // °C
    property real gpuTemp: -1      // °C
    property real netDown: 0       // bytes per second
    property real netUp: 0
    property real diskUsed: 0      // bytes
    property real diskTotal: 0
    property real uptime: 0        // seconds

    // Forrige CPU-måling, for å regne ut forskjellen
    property real lastTotal: 0
    property real lastIdle: 0
    property real lastRx: -1
    property real lastTx: -1
    property real lastNetTime: 0

    function push(list, v) {
        const out = list.concat([v])
        return out.length > historyLength ? out.slice(out.length - historyLength) : out
    }

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
        if (memTotal && memAvail) {
            const t = parseInt(memTotal[1])
            const a = parseInt(memAvail[1])
            root.ram = 1 - a / t
            root.ramTotalGb = t / 1048576
            root.ramUsedGb = (t - a) / 1048576
        }

        root.cpuHistory = root.push(root.cpuHistory, root.cpu)
        root.ramHistory = root.push(root.ramHistory, root.ram)
    }

    function sample() {
        if (useFallback) {
            fallback.running = true
        } else {
            statFile.reload()
            memFile.reload()
            const stat = statFile.text()
            const mem = memFile.text()
            if (!stat || !mem) {
                useFallback = true
                fallback.running = true
            } else {
                parse(stat, mem)
            }
        }
        if (detailed && !details.running) details.running = true
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

    // GPU load (AMD), temperatures, network and disk, in one small script
    Process {
        id: details
        command: ["sh", "-c", `
g=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
ct=""; gt=""
for d in /sys/class/hwmon/hwmon*; do
    case "$(cat "$d/name" 2>/dev/null)" in
        k10temp|zenpower|coretemp) [ -z "$ct" ] && ct=$(cat "$d/temp1_input" 2>/dev/null) ;;
        amdgpu) [ -z "$gt" ] && gt=$(cat "$d/temp1_input" 2>/dev/null) ;;
    esac
done
net=$(awk 'NR > 2 && $1 !~ /^lo:/ { rx += $2; tx += $10 } END { print rx, tx }' /proc/net/dev)
disk=$(df -B1 --output=used,size / | tail -1)
up=$(cut -d' ' -f1 /proc/uptime)
echo "$g|$ct|$gt|$net|$disk|$up"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("|")
                if (p.length < 6) return
                root.gpu = p[0] !== "" ? Number(p[0]) / 100 : -1
                root.cpuTemp = p[1] !== "" ? Number(p[1]) / 1000 : -1
                root.gpuTemp = p[2] !== "" ? Number(p[2]) / 1000 : -1

                const [rx, tx] = p[3].trim().split(/\s+/).map(Number)
                const now = Date.now()
                if (root.lastRx >= 0 && now > root.lastNetTime) {
                    const dt = (now - root.lastNetTime) / 1000
                    root.netDown = Math.max(0, (rx - root.lastRx) / dt)
                    root.netUp = Math.max(0, (tx - root.lastTx) / dt)
                }
                root.lastRx = rx
                root.lastTx = tx
                root.lastNetTime = now

                const [used, size] = p[4].trim().split(/\s+/).map(Number)
                root.diskUsed = used || 0
                root.diskTotal = size || 0
                root.uptime = Number(p[5]) || 0

                if (root.gpu >= 0) root.gpuHistory = root.push(root.gpuHistory, root.gpu)
                root.netDownHistory = root.push(root.netDownHistory, root.netDown)
            }
        }
    }

    // "2.4 MB/s"
    function rate(bytes) {
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB/s"
        if (bytes >= 1024) return Math.round(bytes / 1024) + " KB/s"
        return Math.round(bytes) + " B/s"
    }

    // "3 h 12 min"
    function duration(sec) {
        const d = Math.floor(sec / 86400)
        const h = Math.floor(sec % 86400 / 3600)
        const m = Math.floor(sec % 3600 / 60)
        if (d > 0) return d + " d " + h + " h"
        if (h > 0) return h + " h " + m + " min"
        return m + " min"
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }
}
