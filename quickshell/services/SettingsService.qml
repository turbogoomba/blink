pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// All shell settings, saved to ~/.config/blink/settings.json
// (per machine, outside the repo). Change a value here -> it is saved automatically.
Singleton {
    id: root

    // Bar: "top" (with the notch) or "left" (Caelestia-style side bar)
    property alias barPosition: adapter.barPosition
    readonly property bool sideBar: barPosition === "left"
    readonly property int sideWidth: 52
    // How far down the screen content starts, and where it starts on the left
    readonly property int topInset: sideBar ? Tokens.frameT : Tokens.barHeight
    readonly property int leftInset: sideBar ? sideWidth : Tokens.frameT

    // Hot corners
    property alias hotCornersEnabled: adapter.hotCornersEnabled
    property alias cornerTopLeft: adapter.cornerTopLeft
    property alias cornerTopRight: adapter.cornerTopRight
    property alias cornerBottomLeft: adapter.cornerBottomLeft
    property alias cornerBottomRight: adapter.cornerBottomRight
    property alias cornerDelay: adapter.cornerDelay

    // Notch: "auto" (timetable if a link exists), "timetable" or "buses"
    property alias notchRight: adapter.notchRight
    property alias timetableUrl: adapter.timetableUrl

    // Desktop widgets. Position -1 = the default place (top right)
    property alias widgetTimetable: adapter.widgetTimetable
    property alias widgetX: adapter.widgetX
    property alias widgetY: adapter.widgetY
    property alias widgetBattery: adapter.widgetBattery
    property alias batWidgetX: adapter.batWidgetX
    property alias batWidgetY: adapter.batWidgetY

    // Dock
    property alias dockEnabled: adapter.dockEnabled
    // Apps the launcher never shows, by name (other settings apps that Blink's own Settings replace)
    property alias launcherHidden: adapter.launcherHidden
    property alias dockSize: adapter.dockSize
    // "bottom", "left" or "right". The drawer goes on the other side.
    property alias drawerEnabled: adapter.drawerEnabled
    property alias bootAnimation: adapter.bootAnimation
    property alias frameViz: adapter.frameViz
    property alias dockPosition: adapter.dockPosition
    // When the dock shows: "intellihide" (out whenever no window covers it, and at the edge),
    // "autohide" (only when the mouse touches the edge), "" = intellihide on laptops, autohide elsewhere
    property alias dockHide: adapter.dockHide
    // The dock hovers above the edge with all corners round, instead of growing out of the frame
    property alias dockFloating: adapter.dockFloating
    // Pinned apps (desktop entry ids), in order
    property alias dockApps: adapter.dockApps

    // Blink moved from Thunar to Nautilus: swap it in the pinned apps once
    function migrate() {
        const nautilus = "org.gnome.Nautilus"
        let changed = false
        const list = []
        for (const a of dockApps) {
            const id = /^thunar(\.desktop)?$/i.test(a) ? nautilus : a
            if (id !== a) changed = true
            if (list.indexOf(id) === -1) list.push(id)
            else changed = true
        }
        if (changed) dockApps = list
    }

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

    // Put a pinned app at a new place in the list (drag and drop in the dock)
    function moveTo(id, to) {
        const list = dockApps.filter(a => a !== id)
        if (list.length === dockApps.length) return
        list.splice(Math.max(0, Math.min(list.length, to)), 0, id)
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
    // A fixed accent ("#rrggbb"), used when not matching the wallpaper. "" = the theme's own.
    property alias accentColor: adapter.accentColor

    // Theme for the whole shell (Tokens.themes): blink, daylight, paper, fjord, dusk, forest, ember
    property alias theme: adapter.theme
    // Apps that follow the theme (ThemeService writes their colors)
    property alias themeKitty: adapter.themeKitty
    property alias themeGtk: adapter.themeGtk
    property alias themeVesktop: adapter.themeVesktop
    property alias themeSpotify: adapter.themeSpotify
    property alias themeFirefox: adapter.themeFirefox
    onThemeChanged: Tokens.themeName = theme
    Component.onCompleted: Tokens.themeName = theme

    // Notifications: "notch" (one at a time in the notch) or "corner" (cards out of the frame)
    property alias notifStyle: adapter.notifStyle
    property alias notifCorner: adapter.notifCorner      // "left" or "right"
    property alias notifMax: adapter.notifMax            // cards on screen
    property alias notifTimeout: adapter.notifTimeout    // seconds
    property alias notifShowBody: adapter.notifShowBody

    // Control Center: section order, what is hidden (sections and tiles), and width
    property alias ccSections: adapter.ccSections
    property alias ccHidden: adapter.ccHidden
    property alias ccWidth: adapter.ccWidth           // "compact", "normal" or "wide"

    // Every section and tile the Control Center knows about, with names for Settings
    readonly property var ccSectionInfo: [
        { id: "connections", label: "Connections & toggles", hint: "Wi-Fi, Bluetooth, modes and more" },
        { id: "record",      label: "Screen Recording",      hint: "Record the screen or an area" },
        { id: "display",     label: "Display",               hint: "Brightness slider (laptops)" },
        { id: "sound",       label: "Sound",                 hint: "Volume slider" },
        { id: "battery",     label: "Battery",               hint: "Charge and power mode (laptops)" }
    ]
    readonly property var ccTileInfo: [
        { id: "wifi",       label: "Wi-Fi" },
        { id: "bluetooth",  label: "Bluetooth" },
        { id: "airplane",   label: "Airplane Mode" },
        { id: "modes",      label: "Modes",       hint: "Do Not Disturb, Focus, Game Mode" },
        { id: "windows",    label: "Windows",     hint: "Floating or tiling" },
        { id: "nightshift", label: "Night Shift" }
    ]
    // Saved order, plus any section added later at the end
    readonly property var ccOrder: {
        const known = ccSectionInfo.map(s => s.id)
        const saved = ccSections.filter(id => known.indexOf(id) >= 0)
        return [...saved, ...known.filter(id => saved.indexOf(id) < 0)]
    }
    function ccShown(id) { return ccHidden.indexOf(id) < 0 }
    function ccSetShown(id, on) {
        const rest = ccHidden.filter(h => h !== id)
        ccHidden = on ? rest : [...rest, id]
    }
    // dir -1 = up, 1 = down
    function ccMove(id, dir) {
        const list = [...ccOrder]
        const i = list.indexOf(id)
        const j = i + dir
        if (i < 0 || j < 0 || j >= list.length) return
        list[i] = list[j]
        list[j] = id
        ccSections = list
    }
    function ccReset() {
        ccSections = ccSectionInfo.map(s => s.id)
        ccHidden = []
        ccWidth = "normal"
    }

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
        onLoaded: root.migrate()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter()
        }

        JsonAdapter {
            id: adapter
            property string barPosition: "top"
            property bool hotCornersEnabled: true
            property string cornerTopLeft: "mission"
            property string cornerTopRight: "controlcenter"
            property string cornerBottomLeft: "none"
            property string cornerBottomRight: "power"
            property int cornerDelay: 250
            property string notchRight: "auto"
            property string timetableUrl: ""
            property bool widgetTimetable: true
            property int widgetX: -1
            property int widgetY: -1
            property bool widgetBattery: true
            property int batWidgetX: -1
            property int batWidgetY: -1
            property bool dockEnabled: true
            property var launcherHidden: ["System Settings", "KDE System Settings", "Thunar Preferences", "Volume Control"]
            property int dockSize: 64
            property bool drawerEnabled: true
            property bool bootAnimation: true
            property string frameViz: "glow"
            property string dockPosition: "bottom"
            property string dockHide: ""
            property bool dockFloating: true
            property list<string> dockApps: ["firefox", "org.gnome.Nautilus", "kitty"]
            property list<string> favApps: []
            property list<string> favFolders: []
            property bool accentFromWallpaper: true
            property string accentColor: ""
            property string theme: "blink"
            property bool themeKitty: true
            property bool themeGtk: true
            property bool themeVesktop: true
            property bool themeSpotify: false
            property bool themeFirefox: true
            property bool nightLight: false
            property int nightTemp: 4000
            property string notifStyle: "notch"
            property string notifCorner: "right"
            property int notifMax: 3
            property int notifTimeout: 5
            property bool notifShowBody: true
            property list<string> ccSections: ["connections", "record", "display", "sound", "battery"]
            property list<string> ccHidden: []
            property string ccWidth: "normal"
        }
    }
}
