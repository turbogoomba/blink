import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: dock
    anchors.bottom: true
    margins.bottom: 8
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 64
    color: "transparent"

    // Festede apper (navnet på .desktop-filen, uten .desktop)
    property list<string> apps: ["kitty", "firefox", "org.gnome.Nautilus"]

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Tokens.surface
        border.color: Tokens.border
        border.width: 1

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: dock.apps

                Item {
                    id: app
                    required property string modelData
                    readonly property var entry:
                        DesktopEntries.applications.values.find(e => e.id === modelData) ?? null
                    readonly property bool running:
                        ToplevelManager.toplevels.values.some(t => t.appId === modelData)

                    width: 48
                    height: 48

                    Image {
                        anchors.centerIn: parent
                        width: 40
                        height: 40
                        sourceSize: Qt.size(80, 80)
                        source: Quickshell.iconPath(app.entry?.icon ?? "", "application-x-executable")
                        scale: mouse.containsMouse ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    // Prikk når appen kjører
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -4
                        width: 4
                        height: 4
                        radius: 2
                        color: Tokens.textPrimary
                        visible: app.running
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const win = ToplevelManager.toplevels.values
                                .find(t => t.appId === app.modelData)
                            if (win) win.activate()
                            else app.entry?.execute()
                        }
                    }
                }
            }
        }
    }
}
