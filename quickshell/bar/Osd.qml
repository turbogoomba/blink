import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Keys for volume and brightness. The popup itself now lives in the notch.
// Keys call: qs ipc call osd volumeUp | volumeDown | mute | brightnessUp | brightnessDown
Scope {
    IpcHandler {
        target: "osd"

        function volumeUp(): void { OsdService.volumeUp() }
        function volumeDown(): void { OsdService.volumeDown() }
        function mute(): void { OsdService.toggleMute() }
        function brightnessUp(): void { OsdService.brightnessUp() }
        function brightnessDown(): void { OsdService.brightnessDown() }
    }

    // Touch the service so it starts listening right away
    Component.onCompleted: OsdService.ready
}
