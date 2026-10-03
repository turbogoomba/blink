pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the modes do outside the shell.
//   Do Not Disturb: no notification popups (handled by NotificationService)
//   Focus:          + no dock and no hot corners
//   Game Mode:      + no frame, Hyprland animations/blur/shadows off, no idle dim/lock
Singleton {
    id: root

    readonly property var modes: [
        { id: "dnd",   label: "Do Not Disturb", icon: "notifications-disabled-symbolic", hint: "Silence notifications" },
        { id: "focus", label: "Focus",          icon: "weather-clear-night-symbolic",   hint: "Silence, hide dock and hot corners" },
        { id: "game",  label: "Game Mode",      icon: "input-gaming-symbolic",          hint: "Bar only, no animations, no idle" }
    ]

    function info(id) { return modes.find(m => m.id === id) ?? null }

    // Pick a mode, or turn it off if it is already on
    function toggle(id) {
        ShellState.mode = ShellState.mode === id ? "" : id
    }

    property bool wasGame: false

    Process { id: cmd }
    function run(shell) {
        cmd.command = ["sh", "-c", shell]
        cmd.running = true
    }

    Connections {
        target: ShellState
        function onModeChanged() {
            if (ShellState.gameMode && !root.wasGame) {
                root.wasGame = true
                root.run("hyprctl eval 'hl.config({ animations = { enabled = false }, "
                    + "decoration = { blur = { enabled = false }, shadow = { enabled = false } } })'; "
                    + "systemctl --user stop hypridle.service")
            } else if (!ShellState.gameMode && root.wasGame) {
                root.wasGame = false
                // Reload brings back animations, blur and shadows exactly as in the config
                root.run("hyprctl reload; systemctl --user start hypridle.service")
            }
        }
    }
}
