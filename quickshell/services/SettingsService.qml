pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// All shell settings, saved to ~/.config/blink/settings.json
// (per machine, outside the repo). Change a value here -> it is saved automatically.
Singleton {
    id: root

    // Hot corners
    property alias hotCornersEnabled: adapter.hotCornersEnabled
    property alias cornerTopLeft: adapter.cornerTopLeft
    property alias cornerTopRight: adapter.cornerTopRight
    property alias cornerDelay: adapter.cornerDelay

    // Notch: "auto" (timetable if a link exists), "timetable" or "buses"
    property alias notchRight: adapter.notchRight
    property alias timetableUrl: adapter.timetableUrl

    // Dock
    property alias dockSize: adapter.dockSize
    // "bottom", "left" or "right". The drawer goes on the other side.
    property alias drawerEnabled: adapter.drawerEnabled
    property alias bootAnimation: adapter.bootAnimation
    property alias frameViz: adapter.frameViz
    property alias dockPosition: adapter.dockPosition
    // Pinned apps (desktop entry ids), in order
    property alias dockApps: adapter.dockApps

    // Drawer: favorite apps (desktop entry ids) and folders (paths)
    property alias favApps: adapter.favApps
    property alias favFolders: adapter.favFolders

    readonly property string drawerSide: dockPosition === "left" ? "right" : "left"

    // ---------- Helpers for the lists ----------
    function isPinned(id) { return dockApps.indexOf(id) !== -1 }
    function pin(id) { if (id && !isPinned(id)) dockApps = [...dockApps, id] }
    function unpin(id) { dockApps = dockApps.filter(a => a !== id) }
    function togglePin(id) { isPinned(id) ? unpin(id) : pin(id) }
    // Move a pinned app one step: dir -1 = left/up, 1 = right/down
    function movePinned(id, dir) {
        const list = [...dockApps]
        const i = list.indexOf(id)
        const j = i + dir
        if (i < 0 || j < 0 || j >= list.length) return
        list[i] = list[j]
        list[j] = id
        dockApps = list
    }

    function isFavorite(id) { return favApps.indexOf(id) !== -1 }
    function addFavorite(id) { if (id && !isFavorite(id)) favApps = [...favApps, id] }
    function removeFavorite(id) { favApps = favApps.filter(a => a !== id) }

    function addFolder(path) {
        const p = decodeURIComponent(path.toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
        if (p && favFolders.indexOf(p) === -1) favFolders = [...favFolders, p]
    }
    function removeFolder(path) { favFolders = favFolders.filter(f => f !== path) }

    // Accent color from the wallpaper
    property alias accentFromWallpaper: adapter.accentFromWallpaper

    // Notifications: "notch" (one at a time in the notch) or "corner" (cards out of the frame)
    property alias notifStyle: adapter.notifStyle
    property alias notifCorner: adapter.notifCorner      // "left" or "right"
    property alias notifMax: adapter.notifMax            // cards on screen
    property alias notifTimeout: adapter.notifTimeout    // seconds
    property alias notifShowBody: adapter.notifShowBody

    // Night Shift
    property alias nightLight: adapter.nightLight
    property alias nightTemp: adapter.nightTemp

    readonly property string dir: Quickshell.env("HOME") + "/.config/blink"

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        running: true
    }

    FileView {
        id: file
        path: root.dir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter()
        }

        JsonAdapter {
            id: adapter
            property bool hotCornersEnabled: true
            property string cornerTopLeft: "mission"
            property string cornerTopRight: "controlcenter"
            property int cornerDelay: 250
            property string notchRight: "auto"
            property string timetableUrl: ""
            property int dockSize: 60
            property bool drawerEnabled: true
            property bool bootAnimation: true
            property string frameViz: "glow"
            property string dockPosition: "bottom"
            property list<string> dockApps: ["firefox", "thunar", "kitty"]
            property list<string> favApps: []
            property list<string> favFolders: []
            property bool accentFromWallpaper: true
            property bool nightLight: false
            property int nightTemp: 4000
            property string notifStyle: "notch"
            property string notifCorner: "right"
            property int notifMax: 3
            property int notifTimeout: 5
            property bool notifShowBody: true
        }
    }
}
