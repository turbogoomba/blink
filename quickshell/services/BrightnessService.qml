pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "backlight" (laptop), "ddc" (eksterne skjermer) eller "none"
    property string method: "none"
    property real value: 0.5
    // I2C-bussene til skjermene som støtter DDC (f.eks. "9")
    property var buses: []
    readonly property bool available: method !== "none"

    Component.onCompleted: detect.running = true

    // Finn metode, verdi og skjermbusser én gang
    Process {
        id: detect
        command: ["sh", "-c",
            "if out=$(brightnessctl -m -c backlight info 2>/dev/null); then " +
            "echo backlight $(echo \"$out\" | cut -d, -f4 | tr -d %); " +
            "elif buses=$(ddcutil detect --brief 2>/dev/null | awk '/I2C bus/{sub(\"/dev/i2c-\",\"\",$3); print $3}') && [ -n \"$buses\" ]; then " +
            "first=$(echo $buses | cut -d' ' -f1); " +
            "val=$(ddcutil --bus $first getvcp 10 --brief 2>/dev/null | awk '{print $4/$5}'); " +
            "echo ddc $val $buses; " +
            "else echo none; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/)
                root.method = p[0]
                if (p[0] === "backlight") {
                    root.value = parseFloat(p[1]) / 100
                } else if (p[0] === "ddc") {
                    root.value = parseFloat(p[1])
                    root.buses = p.slice(2)
                }
            }
        }
    }

    // Kalles fra slideren
    function set(v) {
        value = Math.max(0.01, Math.min(1, v))
        debounce.restart()
    }

    // Vent litt mens du drar, så vi ikke spammer skjermen
    Timer {
        id: debounce
        interval: root.method === "ddc" ? 150 : 30
        onTriggered: {
            if (setProc.running) setProc.pending = true
            else setProc.run()
        }
    }

    Process {
        id: setProc
        property bool pending: false

        function run() {
            const pct = Math.round(root.value * 100)
            if (root.method === "backlight") {
                command = ["brightnessctl", "-c", "backlight", "set", pct + "%"]
            } else {
                const cmds = root.buses.map(b =>
                    "ddcutil --bus " + b + " --noverify --sleep-multiplier 0.2 setvcp 10 " + pct + " &")
                command = ["sh", "-c", cmds.join(" ") + " wait"]
            }
            running = true
        }

        onExited: {
            if (pending) {
                pending = false
                run()
            }
        }
    }
}
