pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night Shift: warmer screen colors with hyprsunset.
// On/off and warmth are saved in SettingsService.
Singleton {
    id: root

    property bool available: false
    readonly property bool enabled: SettingsService.nightLight
    readonly property int temperature: SettingsService.nightTemp

    function toggle() {
        SettingsService.nightLight = !SettingsService.nightLight
    }

    onEnabledChanged: apply()
    onTemperatureChanged: apply()

    // Stop hyprsunset, then start it again with the new warmth (if on)
    function apply() {
        sunset.running = false
        if (root.enabled && root.available) restart.restart()
    }

    Timer {
        id: restart
        interval: 250
        onTriggered: {
            sunset.command = ["hyprsunset", "-t", String(root.temperature)]
            sunset.running = true
        }
    }

    Process {
        id: sunset
    }

    // Check that hyprsunset exists and stop any old copy
    Process {
        id: check
        command: ["sh", "-c", "pkill -x hyprsunset; command -v hyprsunset"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() !== ""
                root.apply()
            }
        }
    }
}
