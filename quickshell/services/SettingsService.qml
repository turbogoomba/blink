pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// All shell settings, saved to ~/.config/mac-hypr-rice/settings.json
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

    readonly property string dir: Quickshell.env("HOME") + "/.config/mac-hypr-rice"

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
        }
    }
}
