pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root
    // 12 bands: the frame visualizer uses all of them, the notch shows 4 (small)
    property int bars: 12
    property var values: Array(bars).fill(0)
    readonly property int maxValue: 12
    readonly property bool active: cava.running

    // 4 bands for the notch, each the average of 3
    readonly property var small: [0, 1, 2, 3].map(i =>
        ((values[i * 3] ?? 0) + (values[i * 3 + 1] ?? 0) + (values[i * 3 + 2] ?? 0)) / 3)

    // Bass loudness 0..1 (first 3 bands), for the frame glow
    readonly property real level: Math.min(1,
        ((values[0] ?? 0) + (values[1] ?? 0) + (values[2] ?? 0)) / (3 * maxValue))

    Process {
        id: cava
        // Kjør bare når noe spilles
        running: Mpris.players.values.some(p => p.isPlaying)

        command: ["sh", "-c",
            "printf '[general]\\nbars = " + root.bars + "\\nframerate = 30\\n" +
            "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\n" +
            "data_format = ascii\\nascii_max_range = 12\\n" +
            "bar_delimiter = 59\\nframe_delimiter = 10\\n' > /tmp/qs-cava.conf" +
            " && exec cava -p /tmp/qs-cava.conf"]

        stdout: SplitParser {
            onRead: line => {
                root.values = line.split(";").filter(s => s !== "").map(Number)
            }
        }

        onRunningChanged: {
            if (!running) root.values = Array(root.bars).fill(0)
        }
    }
}
