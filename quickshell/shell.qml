import QtQuick
import Quickshell
import "./bar" as BarUI
import "./settings" as SettingsUI
import "./theme" as Theme

ShellRoot {
    Component.onCompleted: {
        console.log("Shell started")
        console.log("accent color:", Theme.Tokens.accent)
    }

    // Én bar per skjerm
    Variants {
        model: Quickshell.screens
        BarUI.Bar {
            required property var modelData
            screen: modelData
        }
    }

    SettingsUI.Settings {
        visible: true
    }
}
