pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Firefox bookmarks, so the launcher can open your favorite sites.
// Firefox locks its database while running, so a copy is read (needs the sqlite3 command).
// Refreshed every time the launcher opens.
Singleton {
    id: root

    property var items: []        // [{ title, url, host }]
    property bool available: true  // false if sqlite3 or the Firefox profile is missing

    function refresh() {
        if (!reader.running) reader.running = true
    }

    Process {
        id: reader
        command: ["sh", "-c", `
db=$(ls -t "$HOME"/.mozilla/firefox/*/places.sqlite "$HOME"/.config/mozilla/firefox/*/places.sqlite 2>/dev/null | head -1)
[ -n "$db" ] || exit 3
command -v sqlite3 >/dev/null || exit 4
tmp="\${XDG_RUNTIME_DIR:-/tmp}/qs-places.sqlite"
cp "$db" "$tmp" 2>/dev/null || exit 5
# New bookmarks may still be in the write-ahead log, so copy that too
rm -f "$tmp-wal"; [ -f "$db-wal" ] && cp "$db-wal" "$tmp-wal"
sqlite3 -init /dev/null -batch -list -noheader -separator '\t' "$tmp" "SELECT DISTINCT COALESCE(NULLIF(b.title, ''), p.title, p.url), p.url FROM moz_bookmarks b JOIN moz_places p ON b.fk = p.id WHERE b.type = 1 AND p.url LIKE 'http%' ORDER BY p.frecency DESC LIMIT 400"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const i = line.lastIndexOf("\t")
                    if (i < 0) continue
                    const url = line.slice(i + 1).trim()
                    const host = url.replace(/^https?:\/\//, "").replace(/^www\./, "").split("/")[0]
                    out.push({ title: line.slice(0, i).trim() || host, url: url, host: host })
                }
                root.items = out
            }
        }
        onExited: code => root.available = code === 0
    }

    Component.onCompleted: refresh()
}
