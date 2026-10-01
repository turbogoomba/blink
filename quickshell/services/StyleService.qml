pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string mode: "tiling"

    function refresh() { readProc.running = true }
    function toggle()  { toggleProc.running = true }

    Component.onCompleted: refresh()

    // Spør Hyprland hvilken modus som er aktiv
    Process {
        id: readProc
        command: ["hyprctl", "repl", "MacStyle and MacStyle.mode or 'unknown'"]
        stdout: StdioCollector {
            onStreamFinished: root.mode = text.trim()
        }
    }

    // Be Hyprland bytte modus
    Process {
        id: toggleProc
        command: ["hyprctl", "eval", "MacStyle.toggle()"]
        onExited: root.refresh()
    }
}
