pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// WhatsApp lives hidden in its own special workspace ("special:whatsapp").
// It starts with Hyprland (see hyprland.lua), so notifications always come through.
// toggle() shows/hides it, and starts it first if it is not running.
Singleton {
    id: root

    // ZapZap (Flatpak). Swap for a Chromium web app if you prefer:
    //   "chromium --app=https://web.whatsapp.com"
    readonly property string command: "flatpak run com.rtosta.zapzap"

    // Matches ZapZap and Chromium/Brave web app windows
    function isWhatsApp(appId) {
        return /zapzap|whatsapp/i.test(appId ?? "")
    }

    readonly property bool running: Hyprland.toplevels.values.some(t => isWhatsApp(t.wayland?.appId))

    function toggle() {
        if (!running) Quickshell.execDetached(["sh", "-c", command])
        // The window rule puts it in special:whatsapp, so showing that workspace is enough
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special("whatsapp")`)
    }

    IpcHandler {
        target: "whatsapp"
        function toggle(): void { root.toggle() }
    }
}
