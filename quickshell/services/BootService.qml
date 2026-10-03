pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Startup sequence, played once per login (and on demand from Settings or IPC):
// an accent line traces the frame, the wallpaper fades in, the notch drops and
// opens its eyes, the bar slides out from the notch and the dock pops up.
// Every value is 1 when nothing is playing, so the shell looks normal by default.
Singleton {
    id: root

    property bool active: false
    property real trace: 1        // frame line drawn (0..1)
    property real traceAlpha: 0   // frame line visibility
    property real cover: 0        // black over the wallpaper (1 = fully black)
    property real notch: 1        // notch grown (0..1)
    property real eyes: 1         // eyes open (0..1)
    property real bar: 1          // bar contents slid in (0..1)
    property bool dockPeek: false // dock shows itself for a moment

    // Marker in the runtime dir (cleared at logout/reboot), so a shell restart does not replay it
    readonly property string markerPath: Quickshell.env("XDG_RUNTIME_DIR") + "/mac-rice-booted"
    FileView {
        id: marker
        path: root.markerPath
        blockLoading: true
        printErrors: false
    }

    function play() {
        seq.stop()
        active = true
        trace = 0
        traceAlpha = 1
        cover = 1
        notch = 0
        eyes = 0
        bar = 0
        dockPeek = false
        seq.start()
    }

    Component.onCompleted: {
        const seen = (marker.text() ?? "").trim() !== ""
        if (!seen) {
            Quickshell.execDetached(["sh", "-c", "echo 1 > \"" + root.markerPath + "\""])
            if (SettingsService.bootAnimation) play()
        }
    }

    IpcHandler {
        target: "boot"
        function play(): void { root.play() }
    }

    // Timeline in ms (matches the mockup)
    component Step: SequentialAnimation {
        id: step
        property int at: 0
        property string prop: ""
        property real to: 1
        property int duration: 300
        property int ease: Easing.OutCubic
        property real overshoot: 1.70158
        PauseAnimation { duration: step.at }
        NumberAnimation {
            target: root
            property: step.prop
            to: step.to
            duration: step.duration
            easing.type: step.ease
            easing.overshoot: step.overshoot
        }
    }

    ParallelAnimation {
        id: seq
        Step { at: 250;  prop: "trace";      to: 1; duration: 650; ease: Easing.InOutCubic }
        Step { at: 600;  prop: "cover";      to: 0; duration: 450; ease: Easing.OutCubic }
        Step { at: 1000; prop: "traceAlpha"; to: 0; duration: 500; ease: Easing.OutCubic }
        Step { at: 1000; prop: "notch";      to: 1; duration: 450; ease: Easing.OutBack; overshoot: 1.4 }
        Step { at: 1250; prop: "bar";        to: 1; duration: 420; ease: Easing.OutCubic }
        Step { at: 1400; prop: "eyes";       to: 1; duration: 220; ease: Easing.OutBack }
        SequentialAnimation {
            PauseAnimation { duration: 1450 }
            ScriptAction { script: root.dockPeek = true }
            PauseAnimation { duration: 1500 }
            ScriptAction { script: root.dockPeek = false }
        }
        onFinished: root.active = false
    }
}
