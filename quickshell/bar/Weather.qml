import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Weather sheet that grows out of the bar under the weather item.
PanelWindow {
    id: wx
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Open on the monitor you are using (matters with two screens)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "weather"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool open: ShellState.weatherOpen
    // The content waits until the sheet is mostly out, then fades and rises in.
    // Closing: it goes first, quickly, before the sheet slides back.
    property real contentIn: wx.open ? 1 : 0
    Behavior on contentIn {
        id: contentBehavior
        SequentialAnimation {
            PauseAnimation { duration: contentBehavior.targetValue > 0.5 ? Tokens.contentDelay : 0 }
            NumberAnimation {
                duration: contentBehavior.targetValue > 0.5 ? Tokens.contentIn : Tokens.contentOut
                easing.type: Tokens.easeMove
            }
        }
    }

    // With the side bar the sheet slides out of the bar next to the button
    readonly property bool side: SettingsService.sideBar
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        id: openBehavior   // targetValue = where it is going, read before the animation starts
        NumberAnimation {
            duration: openBehavior.targetValue > 0.5 ? Tokens.durOpen : Tokens.durClose
            easing.type: openBehavior.targetValue > 0.5 ? Tokens.easeGrow : Tokens.easeShrink
            easing.overshoot: Tokens.bounce
        }
    }
    visible: open || reveal > 0.01

    function close() { ShellState.weatherOpen = false }

    // Only one sheet from the bar at a time
    Connections {
        target: ShellState
        function onWeatherOpenChanged() {
            if (ShellState.weatherOpen) {
                ShellState.controlCenterOpen = false
                ShellState.calendarOpen = false
                WeatherService.refresh()
                sheet.forceActiveFocus()
            }
        }
        function onControlCenterOpenChanged() { if (ShellState.controlCenterOpen) wx.close() }
        function onCalendarOpenChanged() { if (ShellState.calendarOpen) wx.close() }
    }

    function round(t) { return isNaN(t) ? "–" : Math.round(t) + "°" }

    // Range across the 5 days, for the temperature bars
    readonly property real weekMin: Math.min(...WeatherService.days.map(d => d.min))
    readonly property real weekMax: Math.max(...WeatherService.days.map(d => d.max))

    MouseArea {
        anchors.fill: parent
        onClicked: wx.close()
    }

    component Fillet: Canvas {
        readonly property string paintKey: Tokens.themeName + Tokens.accent
        onPaintKeyChanged: requestPaint()
        // Centre of the round hole (top bar: under the bar; side bar: above/below the sheet)
        property real cx: 0
        property real cy: 14
        onCxChanged: requestPaint()
        onCyChanged: requestPaint()
        width: 14
        height: 14
        visible: sheet.width > 1 && sheet.height > 1
        opacity: Math.min(1, wx.reveal * 4)
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Tokens.barBg
            c.fillRect(0, 0, 14, 14)
            c.globalCompositeOperation = "destination-out"
            c.beginPath()
            c.arc(cx, cy, 14, 0, Math.PI * 2)
            c.fill()
        }
    }
    // Top bar: left and right of the sheet, under the bar.
    // Side bar: above and below the sheet, next to the bar.
    Fillet {
        visible: Tokens.attached
        x: wx.side ? SettingsService.sideWidth : sheet.x - 14
        y: wx.side ? sheet.y - 14 : SettingsService.topInset
        cx: wx.side ? 14 : 0; cy: wx.side ? 0 : 14
    }
    Fillet {
        visible: Tokens.attached
        x: wx.side ? SettingsService.sideWidth : sheet.x + sheet.width
        y: wx.side ? sheet.y + sheet.height : SettingsService.topInset
        cx: 14; cy: 14
    }

    component Detail: Column {
        property string label: ""
        property string value: ""
        spacing: 1
        Text {
            text: parent.label
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSmall
        }
        Text {
            text: parent.value
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontBody
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }

    Item {
        id: sheet
        // Soft shadow, so it floats over what is under it
        layer.enabled: Tokens.menuShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Tokens.shadowColor
            shadowBlur: Tokens.shadowBlur
            blurMax: 32
            shadowVerticalOffset: 2
        }
        readonly property real fullWidth: 340
        readonly property real fullHeight: body.implicitHeight + 28
        // Top bar: grows down under its button. Side bar: slides out to the right next to its button.
        width: wx.side ? fullWidth * Math.max(0, wx.reveal) : fullWidth
        height: wx.side ? fullHeight : fullHeight * Math.max(0, wx.reveal)
        x: wx.side ? SettingsService.sideWidth
            : Math.max(6, Math.min(wx.width - width - 6, ShellState.weatherAnchorX - width / 2))
        y: wx.side
            ? Math.max(Tokens.frameT + 14, Math.min(wx.height - Tokens.frameT - 14 - fullHeight, ShellState.weatherAnchorY - fullHeight / 2))
            : SettingsService.topInset + Tokens.gap
        clip: true
        focus: true
        Keys.onEscapePressed: wx.close()

        // Square where it joins the bar, round at the free corners
        Rectangle {
            anchors.fill: parent
            topLeftRadius: Tokens.glass ? Tokens.radiusXl : 0
            topRightRadius: wx.side || Tokens.glass ? Tokens.radiusXl : 0
            bottomLeftRadius: wx.side && !Tokens.glass ? 0 : Tokens.radiusXl
            bottomRightRadius: Tokens.radiusXl
            color: Tokens.barBg
        }
        GlassEdge { radius: Tokens.radiusXl; z: 10 }

        MouseArea { anchors.fill: parent }

        Column {
            id: body
            // Stays in place inside the sheet (it does not ride on the edge
            // out of the bar); it only drifts the last bit as it fades in
            x: 16
            y: 14
            width: sheet.fullWidth - 32
            spacing: Tokens.spaceLg
            opacity: wx.contentIn
            transform: Translate {
                x: wx.side ? -(1 - wx.contentIn) * 14 : 0
                y: wx.side ? 0 : (1 - wx.contentIn) * 8
            }

            // ---------- Now ----------
            Item {
                width: parent.width
                height: 56

                LineIcon {
                    id: bigIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    size: 44
                    d: WeatherService.glyph

                    tint: Tokens.textPrimary
                }

                Text {
                    id: bigTemp
                    anchors.left: bigIcon.right
                    anchors.leftMargin: Tokens.spaceMd
                    anchors.verticalCenter: parent.verticalCenter
                    text: wx.round(WeatherService.temperature)
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 40
                    font.weight: Font.Light
                }

                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        anchors.right: parent.right
                        text: "Oslo"
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontBody
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        text: WeatherService.description
                        color: Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontBody
                    }
                    Text {
                        anchors.right: parent.right
                        visible: WeatherService.days.length > 0
                        text: "H " + wx.round(WeatherService.days[0]?.max ?? NaN)
                            + "  L " + wx.round(WeatherService.days[0]?.min ?? NaN)
                        color: Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSmall
                    }
                }
            }

            // ---------- Details ----------
            Row {
                spacing: 28
                Detail { label: "Feels like"; value: wx.round(WeatherService.feelsLike) }
                Detail { label: "Wind"; value: isNaN(WeatherService.wind) ? "–" : Math.round(WeatherService.wind) + " m/s" }
                Detail { label: "Humidity"; value: isNaN(WeatherService.humidity) ? "–" : Math.round(WeatherService.humidity) + "%" }
            }

            // ---------- Hourly ----------
            Rectangle {
                width: parent.width
                height: 86
                radius: Tokens.radiusLg
                color: Tokens.fillIdle
                border.color: Tokens.ink(0.06)
                border.width: 1

                Row {
                    anchors.centerIn: parent

                    Repeater {
                        model: WeatherService.hours.slice(0, 8)

                        Column {
                            required property var modelData
                            required property int index
                            width: (sheet.width - 32 - 16) / 8
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.index === 0 ? "Now" : Qt.formatTime(parent.modelData.time, "HH")
                                color: Tokens.textSecondary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSmall
                                font.features: { "tnum": 1 }
                            }
                            LineIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 20
                                d: WeatherService.glyphFor(parent.modelData.symbol)
                                tint: Tokens.textPrimary
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: wx.round(parent.modelData.temp)
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontBody
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            // ---------- Next days ----------
            Column {
                width: parent.width
                spacing: Tokens.spaceXs

                Repeater {
                    model: WeatherService.days

                    Item {
                        id: dayRow
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 26

                        readonly property real span: Math.max(1, wx.weekMax - wx.weekMin)

                        Text {
                            id: dayName
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 56
                            text: dayRow.index === 0 ? "Today" : Qt.formatDate(dayRow.modelData.date, "ddd")
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontBody
                            font.weight: dayRow.index === 0 ? Font.DemiBold : Font.Normal
                        }

                        LineIcon {
                            id: dayIcon
                            anchors.left: dayName.right
                            anchors.verticalCenter: parent.verticalCenter
                            size: 18
                            d: WeatherService.glyphFor(dayRow.modelData.symbol)

                            tint: Tokens.textPrimary
                        }

                        Text {
                            id: minText
                            anchors.left: dayIcon.right
                            anchors.leftMargin: Tokens.spaceLg
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            horizontalAlignment: Text.AlignRight
                            text: wx.round(dayRow.modelData.min)
                            color: Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontBody
                        }

                        // Temperature range bar
                        Rectangle {
                            id: rangeTrack
                            anchors.left: minText.right
                            anchors.leftMargin: Tokens.spaceMd
                            anchors.right: maxText.left
                            anchors.rightMargin: Tokens.spaceMd
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4
                            radius: 2
                            color: Tokens.ink(0.1)

                            Rectangle {
                                x: rangeTrack.width * (dayRow.modelData.min - wx.weekMin) / dayRow.span
                                width: Math.max(6, rangeTrack.width * (dayRow.modelData.max - dayRow.modelData.min) / dayRow.span)
                                height: parent.height
                                radius: 2
                                color: Tokens.accent
                            }
                        }

                        Text {
                            id: maxText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            horizontalAlignment: Text.AlignRight
                            text: wx.round(dayRow.modelData.max)
                            color: Tokens.textPrimary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontBody
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            // ---------- Footer ----------
            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: WeatherService.updated !== "" ? "Updated " + WeatherService.updated + "  ·  MET Norway" : "MET Norway"
                    color: Tokens.textSecondary
                    opacity: 0.7
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall
                }

                Text {
                    scale: yrMouse.pressed ? Tokens.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open Yr ›"
                    color: yrMouse.containsMouse ? Tokens.textPrimary : Tokens.accent
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSmall

                    MouseArea {
                        id: yrMouse
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", "https://www.yr.no/nb/v%C3%A6rvarsel/daglig-tabell/1-72837/Norge/Oslo/Oslo/Oslo"])
                            wx.close()
                        }
                    }
                }
            }
        }
    }
}
