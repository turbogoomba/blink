pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root
    property int bars: 4
    property var values: Array(bars).fill(0)

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
