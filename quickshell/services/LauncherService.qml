pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Badges and progress that apps send themselves, the way docks on other desktops get them
// (com.canonical.Unity.LauncherEntry "Update" over D-Bus): unread counts, a download or copy
// in progress, "needs attention". Telegram, KDE apps, and Electron / Chromium apps
// (Discord / Vesktop and others) when they think the desktop supports it.
// Read with busctl, one JSON line per signal. The dock uses these before notification counts.
Singleton {
    id: root

    // desktop id (lower case, no ".desktop") -> { count, countVisible, progress, progressVisible, urgent }
    property var entries: ({})

    Process {
        id: monitor
        running: true
        command: ["busctl", "--user", "monitor", "--json=short", "--match",
            "type='signal',interface='com.canonical.Unity.LauncherEntry',member='Update'"]
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        // busctl missing or the bus went away: try again a little later
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 10000
        onTriggered: monitor.running = true
    }

    function handle(line) {
        let msg
        try { msg = JSON.parse(line) } catch (e) { return }
        const data = msg?.payload?.data
        if (!data || data.length < 2) return

        const id = String(data[0]).replace(/^application:\/\//, "").replace(/\.desktop$/, "").toLowerCase()
        if (!id) return
        const props = data[1] ?? {}
        const has = k => props[k] !== undefined
        const val = k => props[k]?.data

        const cur = Object.assign({ count: 0, countVisible: false, progress: 0, progressVisible: false, urgent: false },
            entries[id] ?? {})
        if (has("count")) cur.count = Number(val("count")) || 0
        if (has("count-visible")) cur.countVisible = !!val("count-visible")
        if (has("progress")) cur.progress = Math.max(0, Math.min(1, Number(val("progress")) || 0))
        if (has("progress-visible")) cur.progressVisible = !!val("progress-visible")
        if (has("urgent")) cur.urgent = !!val("urgent")

        const e = Object.assign({}, entries)
        e[id] = cur
        entries = e
    }

    // The entry for a dock icon: give it every name the app goes by
    function entryFor(names) {
        const n = names.filter(x => !!x)
        for (const id in entries)
            if (n.some(x => NotificationService.sameApp(id, x))) return entries[id]
        return null
    }
}
