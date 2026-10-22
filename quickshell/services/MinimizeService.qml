pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Minimizing, which Hyprland does not have. A minimized window moves to the hidden
// "special:minimized" workspace (the dock shows it as a tile), and a picture of it shrinks
// into the dock (dock/MinimizeFx.qml). Restoring grows it back out to where it was.
//
// Every way of minimizing ends up here:
//   the dock (click the app you are using), Super+M and the title bar button (ipc "minimize active"),
//   and apps' own minimize buttons (Nautilus ...), which Hyprland passes on as a "minimized" event.
Singleton {
    id: root

    // Each dock tells where its windows shrink to: screen name -> function returning a point
    // in layout coordinates (where the minimized tiles sit)
    property var targets: ({})
    function provideTarget(screenName, fn) {
        const t = Object.assign({}, targets)
        t[screenName] = fn
        targets = t
    }

    // Where each minimized window was and what it looked like, by address:
    // { rect, grab }  (grab keeps the picture alive for the way back)
    property var saved: ({})

    // For the effect overlays, one per screen
    signal shrink(var win, string screenName, rect from, point to)
    signal grow(var win, string screenName, rect to, point from, url picture)
    // For the docks: peek out while a window goes into them
    signal peek(string screenName)

    function addr(t) {
        const a = t.address
        return a.startsWith("0x") ? a : "0x" + a
    }
    function isMinimized(t) { return t?.workspace?.name === "special:minimized" }
    function find(address) {
        const a = String(address).replace(/^0x/, "")
        return Hyprland.toplevels.values.find(t => t.address.replace(/^0x/, "") === a) ?? null
    }
    function screenOf(t) {
        return t?.monitor?.name ?? t?.workspace?.monitor?.name ?? Hyprland.focusedMonitor?.name ?? ""
    }
    function rectOf(t) {
        const o = t?.lastIpcObject
        if (!o || !o.at || !o.size || o.size[0] <= 0) return null
        return Qt.rect(o.at[0], o.at[1], o.size[0], o.size[1])
    }
    // t: the window, so the dock can point at that app's icon
    function targetOn(screenName, t) {
        const fn = targets[screenName]
        try { return fn ? fn(t) : null } catch (e) { return null }
    }

    // ---------- Minimize ----------
    property var pending: null
    function minimize(t) {
        if (!t || isMinimized(t)) return
        // Fresh position first: lastIpcObject only updates when asked
        pending = t
        Hyprland.refreshToplevels()
        settle.restart()
    }
    Timer {
        id: settle
        interval: 70
        onTriggered: {
            const t = root.pending
            root.pending = null
            if (!t) return
            const scr = root.screenOf(t)
            const r = root.rectOf(t)
            const to = root.targetOn(scr, t)
            root.peek(scr)
            if (!r || !to) { root.hide(t); return }
            root.shrink(t, scr, r, to)   // MinimizeFx hides the window once it has its picture
        }
    }

    // Hyprland's own open/close animation would play on top of ours: off for this window
    // while it is minimized, back on a moment after it has come back
    function setNoAnim(t, on) {
        Hyprland.dispatch(`hl.dsp.window.set_prop({ prop = "no_anim", value = "${on ? "1" : "unset"}", window = "address:${addr(t)}" })`)
    }

    // Off to the hidden workspace (called by MinimizeFx, or straight away without an effect)
    function hide(t) {
        if (!t) return
        setNoAnim(t, true)
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:${addr(t)}" })`)
    }

    function remember(t, rect, grab) {
        const s = Object.assign({}, saved)
        s[addr(t)] = { rect: rect, grab: grab }
        saved = s
    }

    // ---------- Restore ----------
    function restore(t) {
        if (!t) return
        if (!isMinimized(t)) { focus(t); return }
        const s = saved[addr(t)]
        const scr = Hyprland.focusedMonitor?.name ?? ""
        const from = targetOn(scr, t)
        if (s && s.rect && s.grab && from) root.grow(t, scr, s.rect, from, s.grab.url)
        else bringBack(t)   // never seen shrinking (minimized before Blink started): no picture
    }

    // Back to the workspace you are on, in focus (called by MinimizeFx when it has grown)
    function bringBack(t) {
        if (!t) return
        const ws = Hyprland.focusedWorkspace?.id ?? 1
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${ws}", window = "address:${addr(t)}" })`)
        focus(t)
        const s = Object.assign({}, saved)
        delete s[addr(t)]
        saved = s
        animBack.win = t
        animBack.restart()
    }
    Timer {
        id: animBack
        property var win: null
        interval: 500
        onTriggered: if (win) { root.setNoAnim(win, false); win = null }
    }
    // Focus it and put it on top of the other windows (floating windows keep their stacking
    // order on focus). Again a moment later, once the move to this workspace has settled.
    function focus(t) {
        raise(t)
        raiseAgain.win = t
        raiseAgain.restart()
    }
    function raise(t) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`)
        Hyprland.dispatch(`hl.dsp.window.alter_zorder({ mode = "top", window = "address:${addr(t)}" })`)
    }
    Timer {
        id: raiseAgain
        property var win: null
        interval: 80
        onTriggered: if (win) { root.raise(win); win = null }
    }

    // ---------- Requests from apps ----------
    // "minimized>>ADDRESS,1" when an app's own minimize button is pressed
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "minimized") return
            const parts = String(event.data).split(",")
            const t = root.find(parts[0])
            if (!t) return
            if (parts[1] === "1") root.minimize(t)
            else if (root.isMinimized(t)) root.restore(t)
        }
    }

    // ---------- Keys and the title bar button ----------
    //   qs -c blink ipc call minimize active
    IpcHandler {
        target: "minimize"
        function active(): void { root.minimize(Hyprland.activeToplevel) }
    }
}
