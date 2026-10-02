pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property var files: []
    property string current: ""
    property int slideshowMinutes: 0   // 0 = av

    Component.onCompleted: refresh()

    function refresh() {
        listProc.running = true
        currentProc.running = true
    }

    // Alle bildene i mappa
    Process {
        id: listProc
        command: ["sh", "-c",
            `find "${root.dir}" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \\) | sort`]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.trim().split("\n").filter(l => l !== "")
        }
    }

    // Bakgrunnen som vises nå
    Process {
        id: currentProc
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/image: (.+)/)
                if (m) root.current = m[1].trim()
            }
        }
    }

    function apply(path, transition) {
        current = path
        Quickshell.execDetached(["awww", "img", path,
            "--transition-type", transition,
            "--transition-duration", "1",
            "--transition-fps", "60"])
    }

    function nameOf(path) { return path.split("/").pop() }

    // ---------- Slideshow ----------
    FileView {
        id: settings
        path: Quickshell.env("HOME") + "/.config/mac-hypr-rice/slideshow"
        printErrors: false
        onLoaded: root.slideshowMinutes = parseInt(text()) || 0
    }

    function setSlideshow(minutes) {
        slideshowMinutes = minutes
        settings.setText(String(minutes))
    }

    Timer {
        interval: Math.max(1, root.slideshowMinutes) * 60000
        running: root.slideshowMinutes > 0
        repeat: true
        onTriggered: {
            const others = root.files.filter(f => f !== root.current)
            if (others.length === 0) return
            root.apply(others[Math.floor(Math.random() * others.length)], "fade")
        }
    }
}
