import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Notification cards that grow out of the frame in a top corner.
// Used when Settings > Notifications > Show in is "Corner cards".
// Click a card to open the app. Drag it down (or use the arrow) to expand it,
// swipe it toward the frame to dismiss it.
// Hovering the cards pauses their timers.
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    // Keys only while you type a reply
    WlrLayershell.keyboardFocus: typingUid >= 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    property int typingUid: -1
    onTypingUidChanged: NotificationService.pausePopups(typingUid >= 0 || sheetHover.hovered)

    readonly property bool active: SettingsService.notifStyle === "corner"
    readonly property bool onLeft: SettingsService.notifCorner === "left"
    readonly property int frameT: 6
    readonly property int pad: Tokens.spaceMd

    readonly property var shown: active ? NotificationService.popups.slice(0, Math.max(1, SettingsService.notifMax)) : []
    readonly property int hiddenCount: active ? Math.max(0, NotificationService.popups.length - shown.length) : 0
    readonly property real targetH: shown.length > 0
        ? cardsCol.implicitHeight + Tokens.spaceSm + pad + (hiddenCount > 0 ? 10 : 0) : 0

    visible: shown.length > 0 || sheet.height > 0.5

    // Only the sheet takes clicks; the rest of the screen stays usable
    mask: Region { x: sheet.x; y: sheet.y; width: sheet.width; height: sheet.height }

    // Grow with a small bounce, shrink smoothly
    onTargetHChanged: {
        heightAnim.stop()
        const growing = targetH > sheet.height
        heightAnim.to = targetH
        heightAnim.duration = growing ? Tokens.durSlow : Tokens.durNormal
        heightAnim.easing.type = growing ? Tokens.easeGrow : Tokens.easeMove
        heightAnim.start()
    }
    NumberAnimation {
        id: heightAnim
        target: sheet
        property: "height"
        easing.overshoot: 0.7
    }

    // Keep delegates alive while the list changes, so cards can animate
    ListModel { id: cardModel }
    onShownChanged: {
        const want = shown.map(c => c.uid)
        for (let i = cardModel.count - 1; i >= 0; i--)
            if (want.indexOf(cardModel.get(i).uid) < 0) cardModel.remove(i)
        want.forEach((uid, i) => {
            let at = -1
            for (let j = 0; j < cardModel.count; j++) if (cardModel.get(j).uid === uid) { at = j; break }
            if (at < 0) cardModel.insert(i, { uid: uid })
            else if (at !== i) cardModel.move(at, i, 1)
        })
    }

    // "now", "5 min" ... refresh now and then
    property int tick: 0
    Timer {
        interval: 30000
        repeat: true
        running: win.visible
        onTriggered: win.tick++
    }

    // Concave corners where the sheet meets the bar and the frame
    component Fillet: Canvas {
        property bool mirrored: false
        width: 14
        height: 14
        visible: sheet.height > 1
        onMirroredChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(mirrored ? 14 : 0, 14, 14, 0, Math.PI * 2)
            c.fill()
        }
    }
    Fillet { mirrored: win.onLeft; x: win.onLeft ? sheet.x + sheet.width : sheet.x - 14; y: sheet.y }
    Fillet { mirrored: win.onLeft; x: win.onLeft ? sheet.x : sheet.x + sheet.width - 14; y: sheet.y + sheet.height }

    Item {
        id: sheet
        x: win.onLeft ? win.frameT : win.width - win.frameT - width
        y: Tokens.barHeight
        width: 372
        height: 0
        clip: true

        // Black like the bar, square where it joins the frame, round at the free corner
        Rectangle {
            x: win.onLeft ? -20 : 0
            y: -20
            width: parent.width + 20
            height: parent.height + 20
            radius: Tokens.radiusXl
            color: Tokens.barBg
        }

        HoverHandler {
            id: sheetHover
            onHoveredChanged: NotificationService.pausePopups(hovered || win.typingUid >= 0)
        }

        Column {
            id: cardsCol
            x: win.pad
            y: Tokens.spaceSm
            width: parent.width - 2 * win.pad
            spacing: Tokens.spaceSm

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.durNormal; easing.type: Tokens.easeMove }
            }
            move: Transition {
                NumberAnimation { property: "y"; duration: Tokens.durNormal; easing.type: Tokens.easeMove }
            }

            Repeater {
                model: cardModel

                delegate: Item {
                    id: slot
                    required property int uid
                    readonly property var card: NotificationService.popups.find(c => c.uid === uid) ?? null
                    property bool expanded: false
                    readonly property var actions: card?.actions ?? []

                    width: cardsCol.width
                    height: face.height

                    Component.onDestruction: if (win.typingUid === uid) win.typingUid = -1

                    function dismiss() {
                        face.x = win.onLeft ? -face.width : face.width
                        dismissTimer.start()
                    }
                    Timer {
                        id: dismissTimer
                        interval: Tokens.durNormal
                        onTriggered: NotificationService.dismissPopup(slot.uid)
                    }

                    Rectangle {
                        id: face
                        width: parent.width
                        height: content.implicitHeight + 2 * Tokens.spaceMd
                        radius: Tokens.radiusLg
                        color: faceMouse.containsMouse ? Tokens.fillHover : Tokens.fillIdle
                        opacity: 1 - Math.min(1, Math.abs(x) / (width * 0.7))
                        Behavior on x {
                            enabled: !faceMouse.drag.active
                            NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove }
                        }
                        Behavior on color { ColorAnimation { duration: Tokens.durFast } }

                        // Click: expand. Drag down: expand. Drag toward the frame: dismiss.
                        MouseArea {
                            id: faceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            drag.target: face
                            drag.axis: Drag.XAxis
                            drag.minimumX: win.onLeft ? -face.width : 0
                            drag.maximumX: win.onLeft ? 0 : face.width
                            drag.threshold: 6
                            property real pressY: 0
                            onPressed: mouse => pressY = mouse.y
                            onPositionChanged: mouse => {
                                if (pressed && !slot.expanded && mouse.y - pressY > 24 && Math.abs(face.x) < 6)
                                    slot.expanded = true
                            }
                            onReleased: {
                                if (Math.abs(face.x) > 80) slot.dismiss()
                                else face.x = 0
                            }
                            onClicked: if (Math.abs(face.x) < 6) NotificationService.openPopup(slot.uid)
                        }

                        Column {
                            id: content
                            x: Tokens.spaceMd + 2
                            y: Tokens.spaceMd
                            width: parent.width - 2 * x
                            spacing: 2

                            // App, time, close
                            Item {
                                width: parent.width
                                height: 20

                                Image {
                                    id: appIcon
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18
                                    sourceSize: Qt.size(36, 36)
                                    source: slot.card?.icon ?? ""
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    anchors.left: appIcon.right
                                    anchors.leftMargin: Tokens.spaceSm
                                    anchors.right: timeText.left
                                    anchors.rightMargin: Tokens.spaceSm
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: slot.card?.appName || "Notification"
                                    elide: Text.ElideRight
                                    color: Tokens.textSecondary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: Tokens.fontSmall
                                }
                                Text {
                                    id: timeText
                                    anchors.right: expandBtn.left
                                    anchors.rightMargin: Tokens.spaceSm
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: { win.tick; return slot.card ? NotificationService.ago(slot.card.time) : "" }
                                    color: Tokens.textSecondary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: Tokens.fontSmall
                                }
                                Rectangle {
                                    id: expandBtn
                                    readonly property bool useful: bodyText.truncated || slot.expanded || slot.actions.length > 0 || (slot.card?.canReply ?? false)
                                    anchors.right: closeBtn.left
                                    anchors.rightMargin: Tokens.spaceXs
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: useful ? 20 : 0
                                    height: 20
                                    radius: 10
                                    color: expandMouse.containsMouse ? Tokens.fillStrong : Tokens.fillHover
                                    opacity: useful && (faceMouse.containsMouse || expandMouse.containsMouse || closeMouse.containsMouse) ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                                    scale: expandMouse.pressed ? Tokens.pressScaleIcon : 1
                                    Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "›"
                                        rotation: slot.expanded ? -90 : 90
                                        Behavior on rotation { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                                        color: Tokens.textSecondary
                                        font.pixelSize: Tokens.fontBody
                                    }
                                    MouseArea {
                                        id: expandMouse
                                        anchors.fill: parent
                                        enabled: expandBtn.useful
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: slot.expanded = !slot.expanded
                                    }
                                }
                                Rectangle {
                                    id: closeBtn
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: closeMouse.containsMouse ? Tokens.fillStrong : Tokens.fillHover
                                    opacity: faceMouse.containsMouse || closeMouse.containsMouse ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                                    scale: closeMouse.pressed ? Tokens.pressScaleIcon : 1
                                    Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: Tokens.textSecondary
                                        font.pixelSize: 9
                                    }
                                    MouseArea {
                                        id: closeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: slot.dismiss()
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                topPadding: 4
                                text: slot.card?.summary ?? ""
                                visible: text !== ""
                                elide: Text.ElideRight
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                                font.weight: Font.DemiBold
                            }

                            Text {
                                id: bodyText
                                width: parent.width
                                text: slot.card?.body ?? ""
                                visible: SettingsService.notifShowBody && text !== ""
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: slot.expanded ? 12 : 2
                                elide: Text.ElideRight
                                lineHeight: 1.15
                                color: Qt.rgba(1, 1, 1, 0.78)
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                            }

                            // App buttons, like Reply
                            Row {
                                visible: slot.expanded && slot.actions.length > 0
                                width: parent.width
                                topPadding: Tokens.spaceSm
                                spacing: Tokens.spaceSm

                                Repeater {
                                    model: slot.actions
                                    delegate: Rectangle {
                                        id: actBtn
                                        required property var modelData
                                        required property int index
                                        width: (content.width - Tokens.spaceSm * (slot.actions.length - 1)) / slot.actions.length
                                        height: 30
                                        radius: Tokens.radiusSm
                                        color: index === 0 ? Tokens.accent
                                             : actMouse.containsMouse ? Tokens.fillStrong : Tokens.fillHover
                                        scale: actMouse.pressed ? Tokens.pressScale : 1
                                        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                                        Text {
                                            anchors.centerIn: parent
                                            width: parent.width - 2 * Tokens.spaceSm
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            text: actBtn.modelData.text
                                            color: actBtn.index === 0 ? Tokens.onAccent : Tokens.textPrimary
                                            font.family: Tokens.fontFamily
                                            font.pixelSize: Tokens.fontBody
                                            font.weight: Font.Medium
                                        }
                                        MouseArea {
                                            id: actMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: NotificationService.invokeAction(slot.uid, actBtn.modelData.id)
                                        }
                                    }
                                }
                            }

                            // Answer right here, for apps that allow it
                            Item {
                                visible: slot.expanded && (slot.card?.canReply ?? false)
                                width: parent.width
                                height: visible ? 30 + Tokens.spaceSm : 0

                                Rectangle {
                                    y: Tokens.spaceSm
                                    anchors.left: parent.left
                                    anchors.right: sendBtn.left
                                    anchors.rightMargin: Tokens.spaceSm
                                    height: 30
                                    radius: Tokens.radiusSm
                                    color: Tokens.fillHover
                                    border.width: replyInput.activeFocus ? 1 : 0
                                    border.color: Tokens.accent

                                    TextInput {
                                        id: replyInput
                                        anchors.fill: parent
                                        anchors.leftMargin: Tokens.spaceMd
                                        anchors.rightMargin: Tokens.spaceMd
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Tokens.textPrimary
                                        selectionColor: Tokens.accent
                                        font.family: Tokens.fontFamily
                                        font.pixelSize: Tokens.fontBody
                                        clip: true
                                        onActiveFocusChanged: if (activeFocus) win.typingUid = slot.uid
                                        onAccepted: if (text.trim() !== "") NotificationService.reply(slot.uid, text)
                                        Keys.onEscapePressed: { text = ""; focus = false; win.typingUid = -1 }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: replyInput.text === ""
                                            text: slot.card?.replyHint ?? "Reply"
                                            color: Tokens.textSecondary
                                            font: replyInput.font
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.IBeamCursor
                                        onClicked: {
                                            win.typingUid = slot.uid
                                            replyInput.forceActiveFocus()
                                        }
                                    }
                                }
                                Rectangle {
                                    id: sendBtn
                                    y: Tokens.spaceSm
                                    anchors.right: parent.right
                                    width: 56
                                    height: 30
                                    radius: Tokens.radiusSm
                                    color: Tokens.accent
                                    opacity: replyInput.text.trim() !== "" ? 1 : 0.5
                                    scale: sendMouse.pressed ? Tokens.pressScale : 1
                                    Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Send"
                                        color: Tokens.onAccent
                                        font.family: Tokens.fontFamily
                                        font.pixelSize: Tokens.fontBody
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        id: sendMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (replyInput.text.trim() !== "") NotificationService.reply(slot.uid, replyInput.text)
                                    }
                                }
                            }

                            // Handle: there is more to see
                            Rectangle {
                                visible: !slot.expanded && (bodyText.truncated || slot.actions.length > 0 || (slot.card?.canReply ?? false))
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 32
                                height: 4
                                radius: 2
                                color: Tokens.fillStrong
                            }
                        }
                    }
                }
            }
        }

        // More waiting than fit: thin edges stacked under the last card
        Column {
            visible: win.hiddenCount > 0
            anchors.top: cardsCol.bottom
            anchors.topMargin: 2
            anchors.horizontalCenter: cardsCol.horizontalCenter
            spacing: 2
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: cardsCol.width - 20; height: 4; radius: 2; color: Tokens.fillIdle }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: cardsCol.width - 40; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.04) }
        }
    }
}
