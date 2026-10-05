pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reads the OsloMet timetable (ICS link) and exposes the next classes.
// Settings > Notch decides: auto (timetable if a link exists), timetable or buses.
// The link comes from Settings, or ~/.config/blink/timetable-url as fallback.
Singleton {
    id: root

    property string fileUrl: ""
    readonly property string url: SettingsService.timetableUrl.trim() !== ""
        ? SettingsService.timetableUrl.trim() : root.fileUrl
    readonly property bool enabled: SettingsService.notchRight === "timetable"
        || (SettingsService.notchRight === "auto" && root.url !== "")

    property string error: ""
    property var events: []      // all future events, sorted
    property var upcoming: []    // the next few (today and onwards)
    property date now: new Date()

    onUrlChanged: refresh()
    onEnabledChanged: refresh()

    // Old link file (fallback)
    Process {
        id: readCfg
        command: ["sh", "-c", "cat \"$HOME/.config/blink/timetable-url\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.fileUrl = text.trim()
        }
    }

    Component.onCompleted: readCfg.running = true

    function refresh() {
        if (!root.enabled) return
        if (root.url === "") {
            root.error = "No timetable link"
            root.events = []
            root.upcoming = []
            return
        }
        fetch.command = ["curl", "-sfL", "--max-time", "15", root.url]
        fetch.running = true
    }

    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("BEGIN:VCALENDAR") === -1) {
                    root.error = "Could not load timetable"
                    return
                }
                root.error = ""
                root.events = root.parse(text)
                root.update()
            }
        }
        onExited: code => {
            if (code !== 0) root.error = "Could not load timetable"
        }
    }

    // ---------- ICS parsing ----------
    function parseDate(v) {
        // 20261005T081500Z (UTC), 20261005T081500 (local) or 20261005 (all day)
        const y = +v.substr(0, 4), mo = +v.substr(4, 2) - 1, d = +v.substr(6, 2)
        if (v.length < 15) return new Date(y, mo, d)
        const h = +v.substr(9, 2), mi = +v.substr(11, 2), s = +v.substr(13, 2)
        if (v.endsWith("Z")) return new Date(Date.UTC(y, mo, d, h, mi, s))
        return new Date(y, mo, d, h, mi, s)
    }

    function clean(s) {
        return s.replace(/\\n/g, " ").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\").trim()
    }

    function parse(raw) {
        // Unfold wrapped lines
        const lines = raw.replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "").split(/\r?\n/)
        const out = []
        let ev = null
        for (const line of lines) {
            if (line === "BEGIN:VEVENT") { ev = {}; continue }
            if (line === "END:VEVENT") {
                if (ev && ev.start) out.push(ev)
                ev = null
                continue
            }
            if (!ev) continue
            const i = line.indexOf(":")
            if (i < 0) continue
            const key = line.substr(0, i).split(";")[0]
            const val = line.substr(i + 1)
            if (key === "DTSTART") ev.start = parseDate(val)
            else if (key === "DTEND") ev.end = parseDate(val)
            else if (key === "SUMMARY") ev.title = clean(val)
            else if (key === "LOCATION") ev.location = clean(val)
        }
        const cutoff = new Date()
        return out
            .filter(e => (e.end || e.start) > cutoff)
            .sort((a, b) => a.start - b.start)
    }

    function update() {
        root.now = new Date()
        root.upcoming = root.events.filter(e => (e.end || e.start) > root.now).slice(0, 4)
    }

    // ---------- Helpers for the UI ----------
    function isNow(e) {
        return e.start <= root.now && (e.end || e.start) > root.now
    }

    function timeText(d) {
        return Qt.formatTime(d, "HH:mm")
    }

    // "Now", "in 25 min", "14:15", "Tomorrow 08:15", "Mon 10:15"
    function whenText(e) {
        if (isNow(e)) return "Now"
        const mins = Math.round((e.start - root.now) / 60000)
        if (mins < 60) return "in " + mins + " min"
        const today = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate())
        const day = new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate())
        const diff = Math.round((day - today) / 86400000)
        if (diff === 0) return timeText(e.start)
        if (diff === 1) return "Tomorrow " + timeText(e.start)
        return Qt.formatDate(e.start, "ddd") + " " + timeText(e.start)
    }

    // Short course name: "MEK1000 Matematikk 1" -> "MEK1000"
    function shortTitle(e) {
        const m = (e.title || "").match(/[A-ZÆØÅ]{2,5}\d{3,4}/)
        return m ? m[0] : (e.title || "Class")
    }

    // Recompute "in X min" every 30 s, fetch again every 30 min
    Timer {
        interval: 30000
        running: root.enabled
        repeat: true
        onTriggered: root.update()
    }
    Timer {
        interval: 30 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }
}
