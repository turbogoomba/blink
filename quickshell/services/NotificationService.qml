pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Hyprland

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
        actionsSupported: true
        inlineReplySupported: true

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
            if (SettingsService.notifStyle === "corner") {
                root.addPopup(n)
                return
            }
            root.current = n
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: SettingsService.notifTimeout * 1000
        onTriggered: root.hide()
    }

    // ---------- Corner cards ----------
    // Newest first. Each card: { uid, n, appName, summary, body, icon, time, actions, due }
    property var popups: []
    property bool popupsPaused: false
    property int nextUid: 1

    function addPopup(n) {
        const card = {
            uid: nextUid++,
            n: n,
            appName: n.appName ?? "",
            desktopEntry: n.desktopEntry ?? "",
            summary: n.summary ?? "",
            body: n.body ?? "",
            icon: iconFor(n),
            time: new Date(),
            // Some apps (Telegram, KDE Connect...) let you answer right in the notification
            canReply: n.hasInlineReply ?? false,
            replyHint: n.inlineReplyPlaceholder || "Reply",
            // App buttons, like "Reply". Not the plain "default" click action.
            actions: (n.actions ?? []).filter(a => a.identifier !== "default").map(a => ({ id: a.identifier, text: a.text })),
            due: Date.now() + SettingsService.notifTimeout * 1000
        }
        popups = [card, ...popups].slice(0, 20)
        // The app can take it back (for example when you read the message there)
        n.closed.connect(() => removePopup(card.uid))
    }

    function removePopup(uid) {
        popups = popups.filter(c => c.uid !== uid)
    }

    // You closed it: tell the app, keep it in the history
    function dismissPopup(uid) {
        const c = popups.find(c => c.uid === uid)
        removePopup(uid)
        try { c?.n?.dismiss() } catch (e) {}
    }

    // Clicked: do what the app asks for a click, and bring its window forward.
    // Discord and many other apps send no click action, so focusing the window is what opens the chat.
    function openPopup(uid) {
        const c = popups.find(c => c.uid === uid)
        if (!c) return
        removePopup(uid)
        try {
            const d = (c.n?.actions ?? []).find(a => a.identifier === "default")
            d?.invoke()
        } catch (e) {}
        const keys = [c.desktopEntry, c.appName].filter(k => k).map(k => k.toLowerCase())
        for (const t of Hyprland.toplevels.values) {
            const id = (t.wayland?.appId ?? "").toLowerCase()
            if (id && keys.some(k => id === k || id.indexOf(k) >= 0 || k.indexOf(id) >= 0)) {
                const a = t.address.startsWith("0x") ? t.address : "0x" + t.address
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${a}" })`)
                break
            }
        }
    }

    function reply(uid, text) {
        const c = popups.find(c => c.uid === uid)
        removePopup(uid)
        try { c?.n?.sendInlineReply(text) } catch (e) {}
    }

    function invokeAction(uid, actionId) {
        const c = popups.find(c => c.uid === uid)
        removePopup(uid)
        try {
            const a = (c?.n?.actions ?? []).find(a => a.identifier === actionId)
            a?.invoke()
        } catch (e) {}
    }

    // Hovering the cards stops the clock; leaving gives every card its full time again
    function pausePopups(paused) {
        popupsPaused = paused
        if (!paused) {
            const due = Date.now() + SettingsService.notifTimeout * 1000
            popups = popups.map(c => Object.assign({}, c, { due: due }))
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0 && !root.popupsPaused
        onTriggered: {
            const now = Date.now()
            if (root.popups.some(c => c.due <= now))
                root.popups = root.popups.filter(c => c.due > now)
        }
    }

    // Switching to the notch, or turning on Do Not Disturb, clears the cards
    Connections {
        target: SettingsService
        function onNotifStyleChanged() { root.popups = []; root.hide() }
    }
    Connections {
        target: ShellState
        function onDoNotDisturbChanged() { if (ShellState.doNotDisturb) root.popups = [] }
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
