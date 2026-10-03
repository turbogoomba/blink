pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool controlCenterOpen: false
    // Modes: "" (off), "dnd", "focus" or "game". Only one at a time.
    property string mode: ""
    readonly property bool doNotDisturb: mode !== ""
    readonly property bool focusMode: mode === "focus" || mode === "game"
    readonly property bool gameMode: mode === "game"
    property bool settingsOpen: false
    property bool launcherOpen: false
    property bool calendarOpen: false
    property bool weatherOpen: false
    property real weatherAnchorX: 0
    property bool soundOpen: false
    property real soundAnchorX: 0

    // Bumped every time a screenshot is taken (the notch face reacts)
    property int screenshotTick: 0

    // Current notch width (set by Bar.qml), so the frame glow can leave a gap for it
    property real notchWidth: 200
}
