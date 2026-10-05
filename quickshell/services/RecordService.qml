pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording with wf-recorder.
// Videos go to ~/Videos/Recordings. Stop sends Ctrl+C so the file is finished properly.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Videos/Recordings"
    readonly property bool recording: proc.running
    property bool withAudio: true
    // Shrink the finished video to under 20 MB (Discord's free limit)
    property bool forDiscord: false
    readonly property bool compressing: squeeze.running
    property int seconds: 0
    property string file: ""

    readonly property string elapsed: {
        const m = Math.floor(seconds / 60)
        const s = seconds % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // True while slurp waits for you to drag out an area. Not a recording yet.
    readonly property bool selecting: picker.running

    // mode: "screen" (focused monitor) or "area" (drag to select)
    function start(mode) {
        if (recording || selecting) return
        if (mode === "area") {
            picker.running = true   // records once slurp gives back an area
            return
        }
        launch('-o "$(hyprctl monitors -j | jq -r \'.[] | select(.focused) | .name\')"')
    }

    function launch(target) {
        file = dir + "/Recording_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4"
        // Records what you hear (the speakers), not the microphone
        const audio = withAudio ? ' --audio="$(pactl get-default-sink).monitor"' : ""
        const out = ` -f "${file}"`
        proc.command = ["sh", "-c", `mkdir -p "${dir}"; exec wf-recorder ${target}${audio}${out}`]
        seconds = 0
        proc.running = true
    }

    // Stop cancels the area selection too, so it can never get stuck
    function stop() {
        if (selecting) picker.signal(15)
        else if (recording) proc.signal(2)   // SIGINT, so wf-recorder finishes the file
    }

    function toggle() {
        if (recording || selecting) stop()
        else start("screen")
    }

    // Put the video in the notch tray (drag it into Discord from there) and say so
    function finish(path, title) {
        ShelfService.add(["file://" + path])
        Quickshell.execDetached(["notify-send", "-a", "Screen Recording", "-i", "media-record",
            title, path.split("/").pop() + "  ·  in the notch tray"])
    }

    // Area picker. Esc in slurp cancels and nothing is recorded.
    Process {
        id: picker
        // slurp reads preset boxes from stdin when it is not a terminal, and Quickshell keeps
        // stdin open, so it would wait forever. An empty stdin makes it go straight to selecting.
        command: ["sh", "-c", "exec slurp < /dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const g = text.trim()
                if (/^\d+,\d+ \d+x\d+$/.test(g)) root.launch(`-g "${g}"`)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("RecordService: slurp:", text.trim())
        }
    }

    Process {
        id: proc
        onExited: (code, status) => {
            // Nothing to do if the area selection was cancelled
            if (root.seconds === 0) return
            if (root.forDiscord) {
                const out = root.file.replace(/\.mp4$/, "_discord.mp4")
                squeeze.output = out
                squeeze.command = ["sh", "-c", root.squeezeScript, "sh", root.file, out]
                squeeze.running = true
            } else {
                root.finish(root.file, "Recording saved")
            }
        }
    }

    // Aim for about 18 MB: bitrate = size / length, minus room for sound. Small clips are just copied.
    readonly property string squeezeScript: `
in="$1"; out="$2"
size=$(stat -c %s "$in")
if [ "$size" -lt 19000000 ]; then cp "$in" "$out"; exit 0; fi
d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
br=$(awk -v d="$d" 'BEGIN { b = int(18 * 8192 / d - 96); if (b > 8000) b = 8000; if (b < 150) b = 150; print b }')
ffmpeg -y -loglevel error -i "$in" -c:v libx264 -preset veryfast -b:v "\${br}k" -maxrate "\${br}k" -bufsize "$((br * 2))k" \
    -vf "scale='min(1920,iw)':-2" -c:a aac -b:a 96k -movflags +faststart "$out"
`

    Process {
        id: squeeze
        property string output: ""
        onExited: code => {
            if (code === 0) root.finish(output, "Ready for Discord")
            else root.finish(root.file, "Recording saved (could not shrink it)")
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.seconds++
    }

    IpcHandler {
        target: "record"
        function toggle(): void { root.toggle() }
        function area(): void { root.start("area") }
        function stop(): void { root.stop() }
    }
}
