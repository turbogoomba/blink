import QtQuick
import Quickshell
import Quickshell.Io
import "./bar" as BarUI
import "./dock" as DockUI
import "./controlcenter" as CCUI
import "./launcher" as LauncherUI
import "./lockscreen" as LockUI
import "./settings" as SettingsUI
import "./services"
import "./theme" as Theme

ShellRoot {
    Component.onCompleted: {
        console.log("Shell started")
        console.log("accent color:", Theme.Tokens.accent)
    }

    // Bar på hver skjerm
    Variants {
        model: Quickshell.screens
        BarUI.Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Dock på hver skjerm
    Variants {
        model: Quickshell.screens
        DockUI.Dock {
            required property var modelData
            screen: modelData
        }
    }

    // Kontrollpanel
    CCUI.ControlCenter {}

    // Launcher
    LauncherUI.Launcher {}

    // Låseskjerm
    LockUI.LockScreen {}

    // Settings lastes bare når den er åpen
    LazyLoader {
        active: ShellState.settingsOpen
        SettingsUI.Settings {
            visible: true
            onVisibleChanged: if (!visible) ShellState.settingsOpen = false
        }
    }

    // Kommandoer Hyprland kan sende til shellet
    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.launcherOpen = !ShellState.launcherOpen }
    }
    IpcHandler {
        target: "lock"
        function lock(): void { ShellState.locked = true }
    }
}
