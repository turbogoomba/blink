import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"
import "../theme"

// Hot corners: top left -> Mission Control, top right -> Control Center
Scope {
    id: root

    // How long the cursor must stay in the corner (ms)
    property int dwell: 250

    Process {
        id: missionProc
        command: ["qs", "-p", Quickshell.shellDir, "ipc", "call", "mission", "toggle"]
    }

    function openMission() {
        missionProc.running = true
    }

    function openControlCenter() {
        ShellState.controlCenterOpen = !ShellState.controlCenterOpen
    }

    component Corner: PanelWindow {
        id: win
        required property var modelData
        property bool right: false
        property var action

        screen: modelData
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
            id: glow
            width: 56
            height: 56
            radius: 28
            x: win.right ? parent.width - 28 : -28
            y: -28
            color: Tokens.accent
            opacity: hover.hovered && !win.fullscreen ? 0.55 : 0
            scale: hover.hovered && !win.fullscreen ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
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
            interval: root.dwell
            onTriggered: {
                win.armed = false
                win.action()
            }
        }
    }

    Variants {
        model: Quickshell.screens
        Corner {
            right: false
            action: root.openMission
        }
    }

    Variants {
        model: Quickshell.screens
        Corner {
            right: true
            action: root.openControlCenter
        }
    }
}
