pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Varselet som vises akkurat nå
    property var current: null

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true
            if (ShellState.doNotDisturb) return
            root.current = n
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 5000
        onTriggered: root.hide()
    }

    function hide() {
        hideTimer.stop()
        current = null
    }
    function pause()  { hideTimer.stop() }
    function resume() { if (current) hideTimer.restart() }

    // Bilde eller app-ikon for et varsel
    function iconFor(n) {
        if (!n) return ""
        if (n.image) return n.image
        const icon = n.appIcon ?? ""
        if (icon.startsWith("/")) return "file://" + icon
        if (icon.startsWith("file://")) return icon
        return Quickshell.iconPath(icon, "dialog-information")
    }
}
