pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// Keep awake: stops hypridle from dimming, locking and sleeping.
// Uses a Wayland idle inhibitor, which hypridle respects.
//   IdleService.keepAwake(30)  -> on for 30 minutes
//   IdleService.keepAwake(0)   -> on until turned off
//   IdleService.stop()
Singleton {
    id: root

    property bool awake: false
    // When it turns off by itself (ms since epoch). 0 = never.
    property real until: 0
    // Minutes picked last time (0 = until turned off), so the menu can show it
    property int minutes: 0

    // Minutes left, for the menu ("-1" = no time limit)
    property int left: -1

    function keepAwake(mins) {
        minutes = mins
        until = mins > 0 ? Date.now() + mins * 60000 : 0
        awake = true
        update()
    }

    function stop() {
        awake = false
        until = 0
        left = -1
    }

    function toggle() {
        if (awake) stop()
        else keepAwake(minutes)
    }

    function update() {
        if (!awake || until === 0) {
            left = -1
            return
        }
        const ms = until - Date.now()
        if (ms <= 0) stop()
        else left = Math.ceil(ms / 60000)
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.awake && root.until > 0
        onTriggered: root.update()
    }

    // The inhibitor needs a mapped window, so keep a 1x1 invisible one around
    PanelWindow {
        id: holder
        visible: root.awake
        anchors { top: true; left: true }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "blink-keepawake"
    }

    IdleInhibitor {
        window: holder
        enabled: root.awake
    }
}
