pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Phone batteries through KDE Connect (the app on the phone, paired with this computer).
// Reads the KDE Connect daemon over D-Bus with busctl once a minute; the daemon starts by
// itself when asked. Pair the phone once in the KDE Connect app.
//   PhoneService.phones -> [{ name, type, level (0-1), charging }]
Singleton {
    id: root

    property var phones: []

    // One line per reachable device that reports a battery: name|type|charge|charging
    readonly property string script: `
B="busctl --user"
S=org.kde.kdeconnect
ids=$($B call $S /modules/kdeconnect org.kde.kdeconnect.daemon devices bb true true 2>/dev/null) || exit 0
for id in $(echo "$ids" | grep -o '"[^"]*"' | tr -d '"'); do
    P=/modules/kdeconnect/devices/$id
    charge=$($B get-property $S $P/battery org.kde.kdeconnect.device.battery charge 2>/dev/null | awk '{print $2}')
    [ -n "$charge" ] && [ "$charge" -ge 0 ] 2>/dev/null || continue
    charging=$($B get-property $S $P/battery org.kde.kdeconnect.device.battery isCharging 2>/dev/null | awk '{print $2}')
    name=$($B get-property $S $P org.kde.kdeconnect.device name 2>/dev/null | sed 's/^s "//;s/"$//')
    type=$($B get-property $S $P org.kde.kdeconnect.device type 2>/dev/null | sed 's/^s "//;s/"$//')
    echo "$name|$type|$charge|$charging"
done`

    Process {
        id: proc
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p.length < 4 || p[2] === "") continue
                    list.push({
                        name: p[0] || "Phone",
                        type: p[1],
                        level: Math.max(0, Math.min(1, Number(p[2]) / 100)),
                        charging: p[3] === "true"
                    })
                }
                root.phones = list
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }
}
