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
import "./switcher" as SwitcherUI
import "./drawer" as DrawerUI

ShellRoot {
    Component.onCompleted: {
        console.log("Shell started")
        console.log("accent color:", Theme.Tokens.accent)
        ModeService.modes   // start the mode watcher
        AccentService.enabled   // start the wallpaper accent
        RecordService.recording // start the recorder (keys)
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
    BarUI.BootOverlay {}
    BarUI.FrameViz {}
    BarUI.HotCorners {}
    BarUI.Osd {}
    BarUI.Calendar {}
    BarUI.NotifCards {}
    BarUI.Weather {}
    BarUI.SoundMenu {}
    SwitcherUI.Switcher {}
    LockUI.Lock {}

    // Dock på hver skjerm
    Variants {
        model: Quickshell.screens
        DockUI.Dock {
            required property var modelData
            screen: modelData
        }
    }

    // Skuff på siden (motsatt av docken): grafer, favoritter, mapper
    DrawerUI.Drawer {}

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
