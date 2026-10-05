import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../theme"

Scope {
    id: root
    property bool open: false

    function toggle() {
        if (!open) Hyprland.refreshToplevels()   // ferske posisjoner og størrelser
        open = !open
    }
    function close() { open = false }

    function addr(t) {
        const a = t.address
        return a.startsWith("0x") ? a : "0x" + a
    }
    function iconFor(appId) {
        const e = DesktopEntries.heuristicLookup(appId ?? "")
        return Quickshell.iconPath(e?.icon ?? (appId ?? "").toLowerCase(), "application-x-executable")
    }

    IpcHandler {
        target: "mission"
        function toggle(): void { root.toggle() }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "missioncontrol"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // 0 = lukket, 1 = åpen. Alt animeres fra denne.
            property real progress: root.open ? 1 : 0
            Behavior on progress { NumberAnimation { duration: Tokens.durSlow; easing.type: Tokens.easeMove } }
            visible: root.open || progress > 0

            readonly property var monitor: Hyprland.monitorFor(modelData)
            readonly property var activeWs: monitor?.activeWorkspace ?? null

            // Vinduer på arbeidsflaten du står på
            readonly property var windows: Hyprland.toplevels.values.filter(
                t => t.workspace && activeWs && t.workspace.id === activeWs.id)

            // Arbeidsflater på denne skjermen
            readonly property var workspaces: Hyprland.workspaces.values
                .filter(w => w.id > 0 && w.monitor?.name === monitor?.name)
                .sort((a, b) => a.id - b.id)

            // Dra et vindu til en arbeidsflate
            property var dragWindow: null
            property point dragPoint: Qt.point(-1, -1)

            onVisibleChanged: if (visible) keys.forceActiveFocus()

            // ---------- Rutenett-utregning ----------
            function layout(wins, areaW, areaH) {
                const n = wins.length
                if (n === 0) return []
                const cols = Math.ceil(Math.sqrt(n))
                const rows = Math.ceil(n / cols)
                const gap = 36
                const cellW = (areaW - gap * (cols - 1)) / cols
                const cellH = (areaH - gap * (rows - 1)) / rows
                return wins.map((t, i) => {
                    const r = Math.floor(i / cols)
                    const c = i % cols
                    const inRow = r === rows - 1 ? n - cols * (rows - 1) : cols
                    const rowOffset = (cols - inRow) * (cellW + gap) / 2
                    const s = t.lastIpcObject?.size ?? [16, 9]
                    const aspect = s[0] / s[1]
                    let w = Math.min(cellW, s[0] * 0.9)
                    let h = w / aspect
                    if (h > cellH) { h = cellH; w = h * aspect }
                    return {
                        x: rowOffset + c * (cellW + gap) + (cellW - w) / 2,
                        y: r * (cellH + gap) + (cellH - h) / 2,
                        w: w,
                        h: h
                    }
                })
            }

            // ---------- Bakgrunn ----------
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.6 * win.progress)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: root.close()
            }

            // ---------- Arbeidsflater øverst ----------
            Row {
                id: wsRow
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24 - 30 * (1 - win.progress)
                opacity: win.progress
                spacing: 14

                Repeater {
                    id: wsRepeater
                    model: win.workspaces

                    delegate: Rectangle {
                        id: pill
                        required property var modelData
                        readonly property bool active: modelData.id === win.activeWs?.id
                        readonly property bool dropHover: win.dragWindow !== null
                            && pill.contains(pill.mapFromItem(null, win.dragPoint.x, win.dragPoint.y))
                        readonly property var wsWindows: Hyprland.toplevels.values.filter(
                            t => t.workspace?.id === modelData.id)

                        width: 150
                        height: 84
                        radius: Tokens.radiusMd
                        color: dropHover ? Qt.rgba(0.37, 0.66, 0.83, 0.35)
                             : pillMouse.containsMouse ? Tokens.fillHover
                             : Tokens.fillIdle
                        border.color: active || dropHover ? Tokens.accent : Qt.rgba(1, 1, 1, 0.1)
                        border.width: active || dropHover ? 2 : 1

                        Row {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -8
                            spacing: 4

                            Repeater {
                                model: pill.wsWindows.slice(0, 4)
                                Image {
                                    required property var modelData
                                    width: 24
                                    height: 24
                                    sourceSize: Qt.size(48, 48)
                                    source: root.iconFor(modelData.wayland?.appId)
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            text: "Desktop " + pill.modelData.id
                            color: pill.active ? Tokens.textPrimary : Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSmall
                            font.weight: pill.active ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = "${pill.modelData.id}" })`)
                        }
                    }
                }

                // Ny arbeidsflate
                Rectangle {
                    width: 84
                    height: 84
                    radius: Tokens.radiusMd
                    color: plusMouse.containsMouse ? Tokens.fillHover : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Light
                    }

                    MouseArea {
                        id: plusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const next = Math.max(0, ...win.workspaces.map(w => w.id)) + 1
                            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${next}" })`)
                        }
                    }
                }
            }

            // ---------- Vinduene ----------
            Item {
                id: grid
                x: 80
                y: 160
                width: win.width - 160
                height: win.height - 220

                readonly property var rects: win.layout(win.windows, width, height)

                Text {
                    anchors.centerIn: parent
                    visible: win.windows.length === 0
                    opacity: win.progress
                    text: "No windows"
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontTitle
                }

                Repeater {
                    model: win.windows

                    delegate: Item {
                        id: tile
                        required property var modelData
                        required property int index

                        readonly property var target: grid.rects[index] ?? { x: 0, y: 0, w: 100, h: 60 }
                        readonly property var ipc: modelData.lastIpcObject

                        // Der vinduet faktisk ligger på skjermen
                        readonly property real realX: (ipc?.at?.[0] ?? 0) - (win.monitor?.x ?? 0) - grid.x
                        readonly property real realY: (ipc?.at?.[1] ?? 0) - (win.monitor?.y ?? 0) - grid.y
                        readonly property real realW: ipc?.size?.[0] ?? target.w
                        readonly property real realH: ipc?.size?.[1] ?? target.h

                        // Glid mellom ekte posisjon og rutenettet
                        x: realX + (target.x - realX) * win.progress
                        y: realY + (target.y - realY) * win.progress
                        width: realW + (target.w - realW) * win.progress
                        height: realH + (target.h - realH) * win.progress

                        readonly property bool hovered: tileMouse.containsMouse && win.dragWindow === null

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: Tokens.radiusMd
                            color: Tokens.surface
                            border.color: tile.hovered ? Tokens.accent : "transparent"
                            border.width: 3

                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: tile.modelData.wayland
                                live: root.open
                            }
                        }

                        // Navn under vinduet ved hover
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 8
                            width: Math.min(titleText.implicitWidth + 20, tile.width)
                            height: 26
                            radius: Tokens.radiusMd
                            color: Qt.rgba(0, 0, 0, 0.7)
                            visible: tile.hovered && win.progress === 1

                            Text {
                                id: titleText
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.title
                                color: "white"
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            property point start
                            property bool moved: false

                            onPressed: mouse => {
                                start = Qt.point(mouse.x, mouse.y)
                                moved = false
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return
                                if (!moved && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 8) {
                                    moved = true
                                    win.dragWindow = tile.modelData
                                }
                                if (moved) win.dragPoint = mapToItem(null, mouse.x, mouse.y)
                            }
                            onReleased: {
                                if (!moved) {
                                    // Klikk: hopp til vinduet
                                    Hyprland.dispatch(`hl.dsp.focus({ window = "address:${root.addr(tile.modelData)}" })`)
                                    root.close()
                                    return
                                }
                                // Slipp: flytt til arbeidsflaten under musen
                                for (let i = 0; i < wsRepeater.count; i++) {
                                    const p = wsRepeater.itemAt(i)
                                    if (p && p.dropHover) {
                                        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${p.modelData.id}", follow = false, window = "address:${root.addr(tile.modelData)}" })`)
                                        break
                                    }
                                }
                                win.dragWindow = null
                                win.dragPoint = Qt.point(-1, -1)
                            }
                        }
                    }
                }
            }

            // Lite bilde som følger musen mens du drar
            ClippingRectangle {
                visible: win.dragWindow !== null
                x: win.dragPoint.x - width / 2
                y: win.dragPoint.y - height / 2
                width: 200
                height: 120
                radius: Tokens.radiusMd
                opacity: 0.85
                color: Tokens.surface

                ScreencopyView {
                    anchors.fill: parent
                    captureSource: win.dragWindow?.wayland ?? null
                    live: false
                }
            }
        }
    }
}
