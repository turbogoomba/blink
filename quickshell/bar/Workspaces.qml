import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import "../theme"

// Workspace indicator. Each workspace shows a small icon for the app on it,
// drawn in the accent color (from the wallpaper).
// The active workspace grows into an accent pill that shows every app on it,
// and slides between workspaces with a "liquid" stretch.
//   - number badge: more than one window (inactive workspaces)
//   - orange dot:   an app wants attention
//   - small dot:    empty workspace
// Set `vertical: true` for a bar on the side of the screen.
Rectangle {
    id: root

    property var targetScreen: null
    property bool vertical: false
    // Always show at least this many slots
    property int minCount: 5
    // Most icons shown in the active pill before it shows "+N"
    property int maxIcons: 4

    readonly property int slot: 26      // one workspace (bar is Tokens.barHeight tall)
    readonly property int iconStep: 21  // each extra icon in the active pill
    readonly property int gap: 5
    readonly property int pad: 2

    // ---------- Data ----------
    readonly property var monitor: Hyprland.monitorFor(targetScreen)
    readonly property var existing: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor?.name === monitor?.name)

    // From the lowest workspace on this monitor, at least minCount long
    readonly property var ids: {
        const have = existing.map(w => w.id)
        const lo = have.length ? Math.min(...have) : 1
        const hi = Math.max(lo + minCount - 1, have.length ? Math.max(...have) : 1)
        const list = []
        for (let i = lo; i <= hi; i++) list.push(i)
        return list
    }

    readonly property int activeIndex: ids.indexOf(monitor?.activeWorkspace?.id ?? -1)

    // Windows on each workspace, in the same order as ids
    readonly property var winLists: ids.map(id => Hyprland.toplevels.values.filter(t => t.workspace?.id === id))

    // Icons shown in the active pill (capped), and how long each slot is
    function shownIcons(i) { return Math.min(winLists[i]?.length ?? 0, maxIcons) }
    function hasMore(i) { return (winLists[i]?.length ?? 0) > maxIcons }
    readonly property var sizes: ids.map((_, i) => {
        if (i !== activeIndex) return slot
        const n = Math.max(1, shownIcons(i)) + (hasMore(i) ? 1 : 0)
        return slot + (n - 1) * iconStep
    })
    // Start of each slot along the bar
    readonly property var offsets: {
        const list = []
        let at = pad
        for (const s of sizes) { list.push(at); at += s + gap }
        return list
    }
    readonly property real length: sizes.reduce((sum, s) => sum + s, 0) + Math.max(0, ids.length - 1) * gap + pad * 2

    width: vertical ? slot + pad * 2 : length
    height: vertical ? length : slot + pad * 2
    radius: slot / 2 + pad
    color: Tokens.fillIdle
    Behavior on width { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }
    Behavior on height { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }

    function appOf(t) {
        return (t?.wayland?.appId ?? t?.lastIpcObject?.class ?? "").toLowerCase()
    }

    // App -> icon. Add your own apps here (match on the start of the app id).
    readonly property var glyphs: ({
        globe:    "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0M3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18",
        terminal: "M5 7l5 5-5 5M12 17h7",
        folder:   "M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",
        chat:     "M4 5h16v11H9l-5 4z",
        music:    "M9 18V5l11-2v13M3 18a3 3 0 1 0 6 0a3 3 0 1 0 -6 0M14 16a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        code:     "M8 7l-5 5 5 5M16 7l5 5-5 5M14 4l-4 16",
        game:     "M6 9h12a4 4 0 0 1 4 4v1a3 3 0 0 1-5.5 1.6L15 14H9l-1.5 1.6A3 3 0 0 1 2 14v-1a4 4 0 0 1 4-4zM7 11v3M5.5 12.5h3",
        video:    "M4 5h16v14H4zM10 9l5 3-5 3z",
        image:    "M4 5h16v14H4zM4 16l5-5 4 4 3-3 4 4",
        doc:      "M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6",
        window:   "M3 6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM3 9h18"
    })
    readonly property var appGlyph: [
        [["firefox", "zen", "librewolf", "chromium", "google-chrome", "brave", "vivaldi", "epiphany"], "globe"],
        [["kitty", "alacritty", "foot", "wezterm", "ghostty", "konsole", "org.gnome.terminal"], "terminal"],
        [["thunar", "nautilus", "org.gnome.nautilus", "dolphin", "org.kde.dolphin", "nemo", "pcmanfm"], "folder"],
        [["discord", "vesktop", "webcord", "signal", "telegram", "org.telegram", "slack", "element", "teams"], "chat"],
        [["spotify", "rhythmbox", "elisa", "tidal", "feishin"], "music"],
        [["code", "code-oss", "vscodium", "cursor", "jetbrains", "zed", "dev.zed", "neovide"], "code"],
        [["steam", "lutris", "heroic", "gamescope", "minecraft", "net.lutris"], "game"],
        [["mpv", "vlc", "celluloid", "io.github.celluloid", "obs", "com.obsproject"], "video"],
        [["gimp", "krita", "inkscape", "imv", "eog", "org.gnome.loupe", "swayimg"], "image"],
        [["obsidian", "zathura", "org.pwmt.zathura", "okular", "libreoffice", "evince", "typora"], "doc"]
    ]
    function glyphFor(app) {
        if (!app) return glyphs.window
        if (app.startsWith("steam_app")) return glyphs.game
        for (const [names, g] of appGlyph)
            if (names.some(n => app === n || app.startsWith(n))) return glyphs[g]
        return glyphs.window
    }



    // ---------- Liquid active pill ----------
    property int lastIndex: 0
    property bool switchingMove: false

    function moveTo(i, switching) {
        if (i < 0 || offsets[i] === undefined) return
        const start = offsets[i]
        const end = start + sizes[i]
        const forward = i > lastIndex
        startAnim.to = start
        endAnim.to = end
        if (switching) {
            // The leading edge moves first, the trailing edge catches up
            startAnim.duration = forward ? 320 : 160
            endAnim.duration = forward ? 160 : 320
        } else {
            // Same workspace, it just grew or shrank (an app opened or closed)
            startAnim.duration = Tokens.durNormal
            endAnim.duration = Tokens.durNormal
        }
        lastIndex = i
        switchingMove = switching
        liquid.restart()
    }
    onActiveIndexChanged: moveTo(activeIndex, true)
    // Sizes change both when you switch (the pill grows) and when apps open or close.
    // Keep the liquid timing if a switch is still running.
    onOffsetsChanged: moveTo(activeIndex, activeIndex !== lastIndex || (liquid.running && switchingMove))
    Component.onCompleted: {
        lastIndex = activeIndex
        if (activeIndex >= 0) {
            pill.a = offsets[activeIndex]
            pill.b = offsets[activeIndex] + sizes[activeIndex]
        }
    }

    Rectangle {
        id: pill
        property real a: 0
        property real b: 0
        visible: root.activeIndex >= 0
        x: root.vertical ? root.pad : a
        y: root.vertical ? a : root.pad
        width: root.vertical ? root.slot : b - a
        height: root.vertical ? b - a : root.slot
        radius: root.slot / 2
        color: Tokens.accent

        ParallelAnimation {
            id: liquid
            NumberAnimation { id: startAnim; target: pill; property: "a"; easing.type: Tokens.easeMove }
            NumberAnimation { id: endAnim;   target: pill; property: "b"; easing.type: Tokens.easeMove }
        }
    }

    // ---------- Icon drawn with the accent color ----------
    component Glyph: Item {
        id: g
        property string d: ""
        property color tint: Tokens.accent
        property real size: 15
        width: size
        height: size

        Shape {
            width: 24
            height: 24
            scale: g.size / 24
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: g.tint
                strokeWidth: 2.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: g.d }
            }
        }
    }

    // ---------- Slots ----------
    Repeater {
        model: root.ids

        delegate: Item {
            id: ws
            required property int modelData
            required property int index

            readonly property var wins: root.winLists[index] ?? []
            readonly property var main: wins.find(t => t.activated) ?? wins[0] ?? null
            readonly property bool active: index === root.activeIndex
            readonly property bool urgent: (root.existing.find(w => w.id === modelData)?.urgent ?? false)
                || wins.some(t => t.urgent ?? false)
            readonly property real size: root.sizes[index] ?? root.slot

            x: root.vertical ? root.pad : (root.offsets[index] ?? 0)
            y: root.vertical ? (root.offsets[index] ?? 0) : root.pad
            width: root.vertical ? root.slot : size
            height: root.vertical ? size : root.slot
            Behavior on x { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }
            Behavior on y { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }
            Behavior on width { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }
            Behavior on height { NumberAnimation { duration: Tokens.durNormal; easing.type: Tokens.easeMove } }

            scale: wsMouse.pressed ? Tokens.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Tokens.easeMove } }

            // Hover
            Rectangle {
                anchors.fill: parent
                radius: Math.min(width, height) / 2
                color: Tokens.fillHover
                opacity: wsMouse.containsMouse && !ws.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            }

            // Empty
            Rectangle {
                visible: ws.wins.length === 0
                anchors.centerIn: parent
                width: 5
                height: 5
                radius: 2.5
                color: ws.active ? Tokens.onAccent : Tokens.textSecondary
                opacity: ws.active ? 1 : 0.6
            }

            // Inactive: one icon for the main app
            Glyph {
                visible: ws.wins.length > 0 && !ws.active
                anchors.centerIn: parent
                d: root.glyphFor(root.appOf(ws.main))
                tint: Tokens.accent
            }

            // Active: every app on the workspace, side by side
            Grid {
                visible: ws.wins.length > 0 && ws.active
                anchors.centerIn: parent
                rows: root.vertical ? -1 : 1
                columns: root.vertical ? 1 : -1
                spacing: root.iconStep - 15
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.durNormal } }

                Repeater {
                    model: ws.wins.slice(0, root.maxIcons)
                    delegate: Glyph {
                        required property var modelData
                        d: root.glyphFor(root.appOf(modelData))
                        tint: Tokens.onAccent
                    }
                }

                Text {
                    visible: ws.wins.length > root.maxIcons
                    width: 15
                    height: 15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "+" + (ws.wins.length - root.maxIcons)
                    color: Tokens.onAccent
                    font.family: Tokens.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }

            // More than one window (inactive only, the active pill shows them all)
            Rectangle {
                visible: ws.wins.length > 1 && !ws.active
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -2
                width: 12
                height: 12
                radius: 6
                color: Tokens.textPrimary
                border.color: Tokens.barBg
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: ws.wins.length > 9 ? "+" : ws.wins.length
                    color: Tokens.barBg
                    font.family: Tokens.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }
            }

            // Wants attention
            Rectangle {
                visible: ws.urgent && !ws.active
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 0
                width: 8
                height: 8
                radius: 4
                color: Tokens.orange
                border.color: Tokens.barBg
                border.width: 1

                SequentialAnimation on opacity {
                    running: parent.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws.modelData}" })`)
            }
        }
    }

    // Scroll to move between workspaces
    WheelHandler {
        onWheel: event => {
            const dir = event.angleDelta.y > 0 ? "e-1" : "e+1"
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${dir}" })`)
        }
    }
}
