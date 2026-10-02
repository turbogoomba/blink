import QtQuick
import Quickshell
import Quickshell.Io
import "./bar" as BarUI
import "./dock" as DockUI
import "./controlcenter" as CCUI
import "./launcher" as LauncherUI
import "./screenshot" as ScreenshotUI
import "./missioncontrol" as MissionUI
import "./settings" as SettingsUI
import "./services"
import "./theme" as Theme
import "./wallpaper" as WallpaperUI
import "./lock" as LockUI

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

    // Ramme rundt skjermen
    BarUI.Frame {}
    BarUI.HotCorners {}
    BarUI.Osd {}
    LockUI.Lock {}

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

    // Skjermbilder
    ScreenshotUI.Screenshot {}

    // Mission Control
    MissionUI.Mission {}

    // Bakgrunnsvelger
    WallpaperUI.WallpaperPicker {}

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
}
