pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool controlCenterOpen: false
    property bool doNotDisturb: false
    property bool settingsOpen: false
    property bool launcherOpen: false
    property bool locked: false
    property bool calendarOpen: false

    // Bumped every time a screenshot is taken (the notch face reacts)
    property int screenshotTick: 0
}
