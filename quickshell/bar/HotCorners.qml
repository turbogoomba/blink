import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"
import "../theme"

// Hot corners. What each corner does is set in Settings > Hot Corners.
// Actions: "mission", "controlcenter", "launcher", "wallpaper", "none"
Scope {
    id: root

    Process {
        id: ipc
    }

    function callIpc(target) {
        ipc.command = ["qs", "-p", Quickshell.shellDir, "ipc", "call", target, "toggle"]
        ipc.running = true
    }

    function run(action) {
        if (action === "mission") callIpc("mission")
        else if (action === "wallpaper") callIpc("wallpaper")
        else if (action === "launcher") ShellState.launcherOpen = !ShellState.launcherOpen
        else if (action === "controlcenter") ShellState.controlCenterOpen = !ShellState.controlCenterOpen
    }

    component Corner: PanelWindow {
        id: win
        required property var modelData
        property bool right: false
        property string action: "none"
        readonly property bool active: SettingsService.hotCornersEnabled && action !== "none" && !ShellState.focusMode

        screen: modelData
        visible: active
        color: "transparent"
        anchors.top: true
        anchors.left: !right
        anchors.right: right
        implicitWidth: 48
        implicitHeight: 48
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hotcorner"

        // Only the tiny corner square catches the mouse
        mask: Region { item: hit }

        readonly property bool fullscreen: {
            const mon = Hyprland.monitorFor(win.screen)
            return mon && mon.activeWorkspace ? mon.activeWorkspace.hasFullscreen : false
        }

        property bool armed: true

        // Glow
        Rectangle {
            width: 56
            height: 56
            radius: 28
            x: win.right ? parent.width - 28 : -28
            y: -28
            color: Tokens.accent
            opacity: hover.hovered && !win.fullscreen ? 0.55 : 0
            scale: hover.hovered && !win.fullscreen ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }
            Behavior on scale { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeGrow } }
        }

        Item {
            id: hit
            width: 4
            height: 4
            x: win.right ? parent.width - width : 0
            y: 0

            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        if (win.armed && !win.fullscreen) timer.restart()
                    } else {
                        timer.stop()
                        win.armed = true
                    }
                }
            }
        }

        Timer {
            id: timer
            interval: SettingsService.cornerDelay
            onTriggered: {
                win.armed = false
                root.run(win.action)
            }
        }
    }

    Variants {
        model: Quickshell.screens
        Corner {
            right: false
            action: SettingsService.cornerTopLeft
        }
    }

    Variants {
        model: Quickshell.screens
        Corner {
            right: true
            action: SettingsService.cornerTopRight
        }
    }
}
