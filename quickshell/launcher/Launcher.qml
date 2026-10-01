import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

PanelWindow {
    id: launcher
    visible: ShellState.launcherOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "launcher"

    property int selected: 0

    // Søkeresultater: navn som starter med søket først
    readonly property var results: {
        const q = search.text.trim().toLowerCase()
        if (q === "") return []
        const scored = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            const name = (e.name ?? "").toLowerCase()
            const generic = (e.genericName ?? "").toLowerCase()
            const keywords = (e.keywords ?? []).join(" ").toLowerCase()
            let score = -1
            if (name.startsWith(q)) score = 3
            else if (name.includes(q)) score = 2
            else if (generic.includes(q) || keywords.includes(q)) score = 1
            if (score >= 0) scored.push({ entry: e, score: score })
        }
        scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name))
        return scored.slice(0, 8).map(s => s.entry)
    }
    onResultsChanged: selected = 0

    function close() {
        ShellState.launcherOpen = false
    }
    function launch(entry) {
        if (!entry) return
        entry.execute()
        close()
    }

    onVisibleChanged: {
        if (visible) {
            search.text = ""
            selected = 0
            search.forceActiveFocus()
            openAnim.restart()
        }
    }

    // Klikk utenfor lukker
    MouseArea {
        anchors.fill: parent
        onClicked: launcher.close()
    }

    Rectangle {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        width: 640
        height: content.implicitHeight
        radius: 16
        color: Tokens.bg
        border.color: Tokens.border
        border.width: 1
        clip: true

        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        // Popin + fade når den åpnes
        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: box; property: "opacity"; from: 0; to: 1; duration: 150 }
            NumberAnimation { target: box; property: "scale"; from: 0.96; to: 1; duration: 150; easing.type: Easing.OutCubic }
        }

        // Klikk inni boksen skal ikke lukke
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            width: parent.width

            // ---------- Søkefelt ----------
            Item {
                width: parent.width
                height: 56

                Image {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    sourceSize: Qt.size(40, 40)
                    source: Quickshell.iconPath("system-search-symbolic", "system-search")
                    opacity: 0.7
                }

                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.textPrimary
                    selectionColor: Tokens.accent
                    font.family: Tokens.fontFamily
                    font.pixelSize: 20

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            launcher.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            launcher.selected = Math.min(launcher.selected + 1, launcher.results.length - 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            launcher.selected = Math.max(launcher.selected - 1, 0)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            launcher.launch(launcher.results[launcher.selected])
                            event.accepted = true
                        }
                    }

                    // Plassholdertekst
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search apps"
                        color: Tokens.textSecondary
                        font: search.font
                        visible: search.text === ""
                    }
                }
            }

            // ---------- Skillelinje ----------
            Rectangle {
                width: parent.width
                height: 1
                color: Tokens.border
                visible: launcher.results.length > 0
            }

            // ---------- Resultater ----------
            Column {
                width: parent.width
                padding: 6
                spacing: 2
                visible: launcher.results.length > 0

                Repeater {
                    model: launcher.results

                    Rectangle {
                        id: resultRow
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: index === launcher.selected

                        width: parent.width - 12
                        height: 44
                        radius: 10
                        color: isSelected ? Tokens.accent : "transparent"

                        Image {
                            id: appIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            sourceSize: Qt.size(56, 56)
                            source: Quickshell.iconPath(resultRow.modelData.icon ?? "", "application-x-executable")
                        }

                        Column {
                            anchors.left: appIcon.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                width: parent.width
                                text: resultRow.modelData.name ?? ""
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: resultRow.modelData.genericName ?? ""
                                visible: text !== ""
                                color: resultRow.isSelected ? Tokens.textPrimary : Tokens.textSecondary
                                opacity: resultRow.isSelected ? 0.8 : 1
                                font.family: Tokens.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: launcher.selected = resultRow.index
                            onClicked: launcher.launch(resultRow.modelData)
                        }
                    }
                }
            }
        }
    }
}
