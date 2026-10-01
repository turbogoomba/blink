pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Varselet som vises akkurat nå
    property var current: null
    // Historikk, nyeste først
    property var history: []
    property int unread: 0

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true
            root.history = [{
                appName: n.appName ?? "",
                summary: n.summary ?? "",
                body: n.body ?? "",
                icon: root.iconFor(n),
                time: new Date()
            }, ...root.history].slice(0, 50)
            root.unread += 1

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

    function removeAt(i) {
        const h = [...history]
        h.splice(i, 1)
        history = h
    }
    function clearAll() {
        history = []
        unread = 0
    }
    function markRead() { unread = 0 }

    // "nå", "5 min", "2 h", "3 d"
    function ago(t) {
        const m = Math.round((Date.now() - t) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + " min"
        const h = Math.floor(m / 60)
        if (h < 24) return h + " h"
        return Math.floor(h / 24) + " d"
    }

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
