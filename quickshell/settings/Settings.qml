import QtQuick
import Quickshell
import "../theme" as Theme

FloatingWindow {
    id: settingsWindow
    title: "Settings"
    implicitWidth: 960
    implicitHeight: 640
    color: Theme.Tokens.bg

    property string activePanel: "wifi"

    // Alle panelene. ready = false viser "Coming soon".
    readonly property var panels: [
        { id: "wifi",          label: "Wi-Fi",         icon: "network-wireless-symbolic",       source: "panels/WifiPanel.qml",      ready: true },
        { id: "bluetooth",     label: "Bluetooth",     icon: "bluetooth-active-symbolic",       source: "panels/BluetoothPanel.qml", ready: true },
        { id: "sound",         label: "Sound",         icon: "audio-volume-high-symbolic",      source: "panels/SoundPanel.qml",     ready: true },
        { id: "notifications", label: "Notifications", icon: "preferences-system-notifications", source: "panels/ShellPanel.qml",    ready: true, page: "notifications" },
        { id: "desktop",       label: "Desktop & Dock", icon: "preferences-desktop-wallpaper",  source: "panels/ShellPanel.qml",     ready: true, page: "desktop" },
        { id: "corners",       label: "Hot Corners",   icon: "input-mouse",                     source: "panels/ShellPanel.qml",     ready: true, page: "corners" },
        { id: "notch",         label: "Notch",         icon: "x-office-calendar",               source: "panels/ShellPanel.qml",     ready: true, page: "notch" },
        { id: "hyprland",      label: "Hyprland",      icon: "preferences-system-windows",      source: "panels/HyprlandPanel.qml",  ready: true }
    ]
    readonly property var current: panels.find(p => p.id === activePanel)

    // ---------- Sidepanel ----------
    Rectangle {
        id: sidebar
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: 220
        color: Theme.Tokens.surfaceAlt

        // Skillelinje mot innholdet
        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: 1
            color: Theme.Tokens.border
        }

        Column {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 20
            anchors.leftMargin: 10
            anchors.rightMargin: 11
            spacing: 2

            Repeater {
                model: settingsWindow.panels

                delegate: Rectangle {
                    id: item
                    required property var modelData
                    readonly property bool selected: modelData.id === settingsWindow.activePanel

                    width: parent.width
                    height: 32
                    radius: 7
                    color: selected ? Theme.Tokens.accent
                         : itemMouse.containsMouse ? Theme.Tokens.surface
                         : "transparent"

                    Image {
                        id: itemIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        sourceSize: Qt.size(32, 32)
                        source: Quickshell.iconPath(item.modelData.icon, "application-x-executable")
                    }

                    Text {
                        anchors.left: itemIcon.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.modelData.label
                        color: Theme.Tokens.textPrimary
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: 13
                        font.weight: item.selected ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: settingsWindow.activePanel = item.modelData.id
                    }
                }
            }
        }
    }

    // ---------- Innhold ----------
    Item {
        anchors { top: parent.top; bottom: parent.bottom; left: sidebar.right; right: parent.right }

        Loader {
            id: panelLoader
            anchors.fill: parent
            source: settingsWindow.current?.ready ? settingsWindow.current.source : ""
        }

        // Tells ShellPanel which page to show
        Binding {
            target: panelLoader.item
            property: "page"
            value: settingsWindow.current?.page ?? ""
            when: panelLoader.item !== null && (settingsWindow.current?.page ?? "") !== ""
        }

        Text {
            anchors.centerIn: parent
            visible: !(settingsWindow.current?.ready ?? false)
            text: (settingsWindow.current?.label ?? "") + "\nComing soon"
            horizontalAlignment: Text.AlignHCenter
            color: Theme.Tokens.textSecondary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: 15
        }
    }
}
