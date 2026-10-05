import QtQuick
import Quickshell
import "../../services"
import "../../theme" as Theme
import ".."

// Settings > Hyprland. Every option comes from HyprSettingsService, grouped in sections.
// The sidebar calls scrollTo(sectionId) to jump to a section.
Flickable {
    id: panel
    contentHeight: col.implicitHeight + 2 * Theme.Tokens.spaceXl + 8
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Section the sidebar should highlight (the one at the top of the view)
    readonly property string currentSection: {
        let cur = HyprSettingsService.sections[0].id
        for (let i = 0; i < sectionRepeater.count; i++) {
            const it = sectionRepeater.itemAt(i)
            if (it && it.y + col.y <= contentY + 40) cur = it.sectionId
        }
        return cur
    }

    function scrollTo(id) {
        for (let i = 0; i < sectionRepeater.count; i++) {
            const it = sectionRepeater.itemAt(i)
            if (it && it.sectionId === id) {
                scrollAnim.to = Math.max(0, Math.min(contentHeight - height, it.y + col.y - Theme.Tokens.spaceXl))
                scrollAnim.restart()
                return
            }
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: panel
        property: "contentY"
        duration: Theme.Tokens.durSlow
        easing.type: Theme.Tokens.easeMove
    }

    Component.onCompleted: {
        HyprSettingsService.refresh()
        StyleService.refresh()
    }

    component SectionTitle: Text {
        leftPadding: Theme.Tokens.spaceXs
        color: Theme.Tokens.textSecondary
        font.family: Theme.Tokens.fontFamily
        font.pixelSize: Theme.Tokens.fontSmall
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }

    Column {
        id: col
        x: Theme.Tokens.spaceXl + 8
        y: Theme.Tokens.spaceXl + 8
        width: panel.width - 2 * x
        spacing: Theme.Tokens.spaceMd

        Column {
            width: parent.width
            spacing: Theme.Tokens.spaceXs
            Text {
                text: "Hyprland"
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontLarge
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Changes apply right away. A dot means the setting is changed from the normal config."
                color: Theme.Tokens.textSecondary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
            }
        }

        Repeater {
            id: sectionRepeater
            model: HyprSettingsService.sections

            delegate: Column {
                id: section
                required property var modelData
                readonly property string sectionId: modelData.id
                readonly property var opts: HyprSettingsService.options.filter(o => o.section === modelData.id)
                width: col.width
                spacing: Theme.Tokens.spaceSm
                topPadding: Theme.Tokens.spaceSm

                SectionTitle { text: section.modelData.label }

                Rectangle {
                    width: parent.width
                    height: cardCol.implicitHeight
                    radius: Theme.Tokens.radiusLg
                    color: Theme.Tokens.fillIdle
                    clip: true

                    Column {
                        id: cardCol
                        width: parent.width

                        // Tiling / floating lives with the window options
                        Item {
                            visible: section.sectionId === "windows"
                            width: parent.width
                            height: visible ? 56 : 0

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.Tokens.spaceLg
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: "Window mode"
                                    color: Theme.Tokens.textPrimary
                                    font.family: Theme.Tokens.fontFamily
                                    font.pixelSize: Theme.Tokens.fontBody
                                    font.weight: Font.Medium
                                }
                                Text {
                                    text: "Tiling places windows side by side. Also Super+T"
                                    color: Theme.Tokens.textSecondary
                                    font.family: Theme.Tokens.fontFamily
                                    font.pixelSize: Theme.Tokens.fontSmall
                                }
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.Tokens.spaceLg
                                anchors.verticalCenter: parent.verticalCenter
                                width: modeRow.implicitWidth + 4
                                height: 28
                                radius: Theme.Tokens.radiusSm
                                color: Theme.Tokens.fillIdle

                                Row {
                                    id: modeRow
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Repeater {
                                        model: [{ id: "tiling", label: "Tiling" }, { id: "floating", label: "Floating" }]
                                        delegate: Rectangle {
                                            id: modeSeg
                                            required property var modelData
                                            readonly property bool selected: StyleService.mode === modelData.id
                                            width: modeText.implicitWidth + 2 * Theme.Tokens.spaceMd
                                            height: 24
                                            radius: Theme.Tokens.radiusSm
                                            color: selected ? Theme.Tokens.accent : modeMouse.containsMouse ? Theme.Tokens.fillHover : "transparent"
                                            scale: modeMouse.pressed ? Theme.Tokens.pressScale : 1
                                            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
                                            Text {
                                                id: modeText
                                                anchors.centerIn: parent
                                                text: modeSeg.modelData.label
                                                color: modeSeg.selected ? Theme.Tokens.onAccent : Theme.Tokens.textSecondary
                                                font.family: Theme.Tokens.fontFamily
                                                font.pixelSize: Theme.Tokens.fontSmall
                                                font.weight: modeSeg.selected ? Font.Medium : Font.Normal
                                            }
                                            MouseArea {
                                                id: modeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (!modeSeg.selected) StyleService.toggle()
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.Tokens.spaceLg
                                anchors.right: parent.right
                                height: 1
                                color: Theme.Tokens.divider
                            }
                        }

                        Repeater {
                            model: section.opts
                            delegate: HyprRow {
                                required property var modelData
                                required property int index
                                opt: modelData
                                divider: index < section.opts.length - 1
                            }
                        }
                    }
                }
            }
        }

        // Undo everything set here
        Rectangle {
            id: resetAll
            visible: Object.keys(HyprSettingsService.saved).length > 0
            width: resetText.implicitWidth + 2 * Theme.Tokens.spaceLg
            height: 30
            radius: Theme.Tokens.radiusSm
            color: resetAllMouse.containsMouse ? Theme.Tokens.fillStrong : Theme.Tokens.fillIdle
            scale: resetAllMouse.pressed ? Theme.Tokens.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.Tokens.durFast; easing.type: Theme.Tokens.easeMove } }
            Text {
                id: resetText
                anchors.centerIn: parent
                text: "Reset all Hyprland settings"
                color: Theme.Tokens.textPrimary
                font.family: Theme.Tokens.fontFamily
                font.pixelSize: Theme.Tokens.fontBody
            }
            MouseArea {
                id: resetAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HyprSettingsService.resetAll()
            }
        }
    }
}
