import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../theme"
import "../services"

Rectangle {
    id: notch
    property int baseHeight: 36

    // ---------- Tilstand ----------
    readonly property var player:
        Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property var notif: NotificationService.current
    readonly property bool showNotif: notif !== null
    readonly property bool hasMusic: player !== null && (player.trackTitle ?? "") !== ""
    readonly property bool hasShelf: ShelfService.files.length > 0
    readonly property bool dragging: dropArea.containsDrag
    readonly property bool expanded:
        !showNotif && (dragging || (hover.hovered && (hasMusic || hasShelf)))
    readonly property bool compact: !showNotif && !expanded && (hasMusic || hasShelf)

    width: showNotif ? 400 : expanded ? 420 : compact ? 280 : 200
    height: showNotif ? 84 : expanded ? expandedContent.implicitHeight + 32 : baseHeight
    radius: showNotif || expanded ? 24 : 10
    color: Tokens.barBg
    clip: true

    Behavior on width  { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    HoverHandler {
        id: hover
        // Pause varselet mens musen er over det
        onHoveredChanged: {
            if (hovered) NotificationService.pause()
            else NotificationService.resume()
        }
    }

    // Ta imot filer som dras inn
    DropArea {
        id: dropArea
        anchors.fill: parent
        onEntered: drag => drag.accepted = drag.hasUrls
        onDropped: drop => {
            if (drop.hasUrls) ShelfService.add(drop.urls)
            drop.accept(Qt.CopyAction)
        }
    }

    // ---------- Små byggeklosser ----------
    component CtrlButton: Item {
        id: btn
        property string icon: ""
        signal clicked()
        width: 32
        height: 32

        Image {
            anchors.centerIn: parent
            width: 20
            height: 20
            sourceSize: Qt.size(40, 40)
            source: Quickshell.iconPath(btn.icon)
            opacity: btnMouse.pressed ? 0.6 : 1
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            onClicked: btn.clicked()
        }
    }

    component FileTile: Item {
        id: tile
        required property string modelData
        width: 64
        height: 76

        ClippingRectangle {
            id: thumb
            anchors.horizontalCenter: parent.horizontalCenter
            width: 52
            height: 52
            radius: 10
            color: Tokens.surface

            // Forhåndsvisning for bilder
            Image {
                anchors.fill: parent
                visible: ShelfService.isImage(tile.modelData)
                source: visible ? tile.modelData : ""
                sourceSize: Qt.size(104, 104)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            // Vanlig ikon for andre filer
            Image {
                anchors.centerIn: parent
                width: 32
                height: 32
                visible: !ShelfService.isImage(tile.modelData)
                sourceSize: Qt.size(64, 64)
                source: Quickshell.iconPath("text-x-generic")
            }
        }

        Text {
            anchors.top: thumb.bottom
            anchors.topMargin: 4
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: ShelfService.nameOf(tile.modelData)
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }

        // Usynlig element som bærer filen når du drar den ut
        Item {
            id: dragProxy
            Drag.active: tileMouse.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.mimeData: { "text/uri-list": tile.modelData }
            Drag.onDragFinished: action => {
                if (action === Qt.MoveAction) ShelfService.remove(tile.modelData)
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: dragProxy
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) ShelfService.remove(tile.modelData)
            }
            onDoubleClicked: Quickshell.execDetached(["xdg-open", tile.modelData])
        }
    }

    // ---------- Kompakt ----------
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: notch.baseHeight
        opacity: notch.compact ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Venstre: cover, eller mappeikon hvis bare hylle
        ClippingRectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 5
            color: notch.hasMusic ? Tokens.surface : "transparent"

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(40, 40)
                fillMode: Image.PreserveAspectCrop
                source: notch.hasMusic
                    ? (notch.player?.trackArtUrl ?? "")
                    : Quickshell.iconPath("folder-symbolic", "folder")
            }
        }

        // Høyre: lydstolper, eller antall filer
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: notch.hasMusic

            Repeater {
                model: CavaService.bars

                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 3 + (CavaService.values[index] ?? 0)
                    radius: 1.5
                    color: Tokens.accent
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: !notch.hasMusic
            text: ShelfService.files.length
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    // ---------- Utvidet: musikk og/eller hylle ----------
    Column {
        id: expandedContent
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
        spacing: 12
        opacity: notch.expanded ? 1 : 0
        enabled: notch.expanded
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Musikk
        Item {
            width: parent.width
            height: 64
            visible: notch.hasMusic && !notch.dragging

            ClippingRectangle {
                id: bigArt
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: 64
                radius: 12
                color: Tokens.surface

                Image {
                    anchors.fill: parent
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectCrop
                    source: notch.player?.trackArtUrl ?? ""
                }
            }

            Column {
                anchors.left: bigArt.right
                anchors.leftMargin: 14
                anchors.right: controls.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: notch.player?.trackTitle ?? ""
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: notch.player?.trackArtist ?? ""
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                CtrlButton {
                    icon: "media-skip-backward-symbolic"
                    onClicked: notch.player?.previous()
                }
                CtrlButton {
                    icon: notch.player?.isPlaying ? "media-playback-pause-symbolic"
                                                  : "media-playback-start-symbolic"
                    onClicked: notch.player?.togglePlaying()
                }
                CtrlButton {
                    icon: "media-skip-forward-symbolic"
                    onClicked: notch.player?.next()
                }
            }
        }

        // Slipp-sone mens du drar en fil inn
        Rectangle {
            width: parent.width
            height: 56
            visible: notch.dragging
            radius: 12
            color: "transparent"
            border.color: Tokens.accent
            border.width: 1.5

            Text {
                anchors.centerIn: parent
                text: "Drop files here"
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        // Hylla
        Item {
            width: parent.width
            height: 76
            visible: notch.hasShelf && !notch.dragging

            Row {
                anchors.left: parent.left
                anchors.right: clearBtn.left
                anchors.rightMargin: 8
                spacing: 8
                clip: true

                Repeater {
                    model: ShelfService.files
                    FileTile {}
                }
            }

            Text {
                id: clearBtn
                anchors.right: parent.right
                anchors.top: parent.top
                text: "Clear"
                color: clearMouse.containsMouse ? Tokens.textPrimary : Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 11

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: ShelfService.clear()
                }
            }
        }
    }

    // ---------- Varsel ----------
    Item {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        opacity: notch.showNotif ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ClippingRectangle {
            id: notifIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            color: Tokens.surface

            Image {
                anchors.centerIn: parent
                width: 28
                height: 28
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectFit
                source: NotificationService.iconFor(notch.notif)
            }
        }

        Column {
            anchors.left: notifIcon.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: notch.notif?.appName ?? ""
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: notch.notif?.summary ?? ""
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: notch.notif?.body ?? ""
                textFormat: Text.PlainText
                color: Tokens.textPrimary
                opacity: 0.8
                font.family: Tokens.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Klikk for å lukke varselet
        MouseArea {
            anchors.fill: parent
            onClicked: NotificationService.hide()
        }
    }
}
