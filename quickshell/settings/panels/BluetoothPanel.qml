import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../theme" as Theme

Flickable {
    id: panel
    contentHeight: col.implicitHeight + 56
    clip: true

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var myDevices: devices.filter(d => d.paired)
    readonly property var nearby: devices.filter(d =>
        !d.paired && (d.name ?? "") !== "" && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(d.name))

    // Let etter enheter mens panelet er åpent
    Component.onCompleted: if (adapter?.enabled) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false

    // ---------- Seksjonsoverskrift ----------
    component SectionTitle: Text {
        leftPadding: Theme.Tokens.spaceXs
        color: Theme.Tokens.textSecondary
        font.family: Theme.Tokens.fontFamily
        font.pixelSize: Theme.Tokens.fontBody
        font.weight: Font.Medium
    }

    // ---------- Liste over enheter ----------
    component DeviceList: Rectangle {
        id: dl
        property var devices: []
        property bool paired: false

        width: col.width
        height: dlCol.implicitHeight
        radius: Theme.Tokens.radiusMd
        color: Theme.Tokens.surface
        border.color: Theme.Tokens.border
        border.width: 1
        visible: devices.length > 0

        Column {
            id: dlCol
            width: parent.width

            Repeater {
                model: dl.devices

                delegate: Item {
                    id: dev
                    scale: devMouse.pressed ? Theme.Tokens.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                    required property var modelData
                    required property int index

                    width: dlCol.width
                    height: 52

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.Tokens.spaceXs
                        radius: Theme.Tokens.radiusSm
                        color: Theme.Tokens.surfaceAlt
                        visible: devMouse.containsMouse
                    }

                    // Klikk: koble til/fra (paret) eller pare (ny)
                    MouseArea {
                        id: devMouse
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !dev.modelData.pairing
                        onClicked: {
                            if (!dl.paired) dev.modelData.pair()
                            else if (dev.modelData.connected) dev.modelData.disconnect()
                            else dev.modelData.connect()
                        }
                    }

                    Image {
                        id: devIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.Tokens.spaceLg
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        sourceSize: Qt.size(40, 40)
                        source: Quickshell.iconPath(dev.modelData.icon || "bluetooth", "bluetooth")
                    }

                    Column {
                        anchors.left: devIcon.right
                        anchors.leftMargin: Theme.Tokens.spaceMd
                        anchors.right: action.left
                        anchors.rightMargin: Theme.Tokens.spaceMd
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: dev.modelData.name
                            color: Theme.Tokens.textPrimary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: Theme.Tokens.fontBody
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: dev.modelData.pairing ? "Pairing..."
                                : !dl.paired ? ""
                                : dev.modelData.connected
                                    ? "Connected" + (dev.modelData.batteryAvailable
                                        ? "  ·  " + Math.round(dev.modelData.battery * 100) + "%" : "")
                                : "Not connected"
                            visible: text !== ""
                            color: Theme.Tokens.textSecondary
                            font.family: Theme.Tokens.fontFamily
                            font.pixelSize: Theme.Tokens.fontSmall
                        }
                    }

                    // Høyre side: "Forget" for parede, "Connect" for nye
                    Text {
                        id: action
                        scale: forgetMouse.pressed ? Theme.Tokens.pressScale : 1
                        Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.Tokens.spaceLg
                        anchors.verticalCenter: parent.verticalCenter
                        text: dl.paired ? "Forget" : "Connect"
                        color: dl.paired
                            ? (forgetMouse.containsMouse ? Theme.Tokens.textPrimary : Theme.Tokens.textSecondary)
                            : Theme.Tokens.accent
                        font.family: Theme.Tokens.fontFamily
                        font.pixelSize: Theme.Tokens.fontBody

                        MouseArea {
                            id: forgetMouse
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            enabled: dl.paired
                            onClicked: dev.modelData.forget()
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.Tokens.spaceLg
                        anchors.right: parent.right
                        height: 1
                        color: Theme.Tokens.border
                        visible: dev.index < dl.devices.length - 1
                    }
                }
            }
        }
    }

    // ---------- Innholdet ----------
    Column {
        id: col
        x: 28
        y: 28
        width: panel.width - 56
        spacing: Theme.Tokens.spaceLg

        Text {
            text: "Bluetooth"
            color: Theme.Tokens.textPrimary
            font.family: Theme.Tokens.fontFamily
            font.pixelSize: Theme.Tokens.fontLarge
            font.weight: Font.DemiBold
        }

        // Av/på
        Rectangle {
            width: parent.width
            height: 48
            radius: Theme.Tokens.radiusMd
            color: Theme.Tokens.surface
            border.color: Theme.Tokens.border
            border.width: 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.Tokens.spaceLg
                anchors.verticalCenter: parent.verticalCenter
                text: panel.adapter ? "Bluetooth" : "Bluetooth  ·  No adapter found"
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
            }

            Rectangle {
                id: toggle
                scale: toggleMouse.pressed ? Theme.Tokens.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                readonly property bool on: panel.adapter?.enabled ?? false
                anchors.right: parent.right
                anchors.rightMargin: Theme.Tokens.spaceLg
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 22
                radius: 11
                color: on ? Theme.Tokens.accent : Theme.Tokens.border
                Behavior on color { ColorAnimation { duration: Theme.Tokens.durFast } }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    y: 2
                    x: toggle.on ? toggle.width - width - 2 : 2
                    color: "white"
                    Behavior on x { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                }

                MouseArea {
                    id: toggleMouse
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: {
                        if (!panel.adapter) return
                        panel.adapter.enabled = !panel.adapter.enabled
                        if (panel.adapter.enabled) panel.adapter.discovering = true
                    }
                }
            }
        }

        // Mine enheter
        SectionTitle {
            visible: panel.myDevices.length > 0
            text: "My Devices"
        }

        DeviceList {
            devices: panel.myDevices
            paired: true
        }

        // Enheter i nærheten
        SectionTitle {
            visible: panel.adapter?.enabled ?? false
            text: panel.adapter?.discovering ? "Nearby Devices  ·  searching..." : "Nearby Devices"
        }

        DeviceList {
            devices: panel.nearby
            paired: false
            visible: (panel.adapter?.enabled ?? false) && panel.nearby.length > 0
        }
    }
}
