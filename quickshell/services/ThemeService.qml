pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Gives the shell's theme to other apps, from the templates in blink/apps:
//   Kitty            ~/.config/kitty/blink-theme.conf (kitty.conf includes it last)
//   GTK (Nautilus ...) ~/.config/gtk-3.0 and gtk-4.0/gtk.css, plus light/dark preference
//   Title bars       ~/.config/blink/hyprbars-colors.lua (hypr/hyprbars.lua reads it)
//   Discord          ~/.config/vesktop/themes/MacRice.theme.css (Vesktop)
//   Spotify          a "Blink" Spicetify theme. Applied fully once; after that the colors
//                    are swapped without closing Spotify (Ctrl+Shift+R in Spotify shows them)
// Runs a moment after the theme or the accent changes, and once at startup.
Singleton {
    id: root

    readonly property string appsDir: Quickshell.shellDir + "/../apps"

    // What is installed, for Settings
    property bool hasSpicetify: false
    property bool hasVesktop: false

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v spicetify >/dev/null && echo spicetify; [ -d \"$HOME/.config/vesktop\" ] && echo vesktop"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasSpicetify = text.indexOf("spicetify") >= 0
                root.hasVesktop = text.indexOf("vesktop") >= 0
            }
        }
    }

    function hex(c) {
        const v = (Math.round(c.r * 255) << 16) | (Math.round(c.g * 255) << 8) | Math.round(c.b * 255)
        return "#" + (0x1000000 + v).toString(16).slice(1)
    }

    // Wait for things to settle (the accent changes a few times when the wallpaper does)
    Timer {
        id: soon
        interval: 900
        onTriggered: root.apply()
    }
    function schedule() { soon.restart() }

    Connections {
        target: Tokens
        function onThemeNameChanged() { root.schedule() }
        function onAccentChanged() { root.schedule() }
    }
    Connections {
        target: SettingsService
        function onThemeKittyChanged() { root.schedule() }
        function onThemeGtkChanged() { root.schedule() }
        function onThemeVesktopChanged() { root.schedule() }
        function onThemeSpotifyChanged() { root.schedule() }
        function onThemeFirefoxChanged() { root.schedule() }
    }
    Component.onCompleted: schedule()

    function apply() {
        if (writer.running) { schedule(); return }
        const t = Tokens.t
        writer.command = ["sh", "-c", script, "sh",
            root.appsDir,
            SettingsService.themeKitty ? "1" : "0",
            SettingsService.themeGtk ? "1" : "0",
            SettingsService.themeVesktop ? "1" : "0",
            SettingsService.themeSpotify ? "1" : "0",
            SettingsService.themeFirefox ? "1" : "0",
            Tokens.themeName,
            t.window, t.sidebar, t.surface, t.surfaceAlt, t.border, t.text, t.text2,
            hex(Tokens.accent), hex(Qt.lighter(Tokens.accent, 1.18)), hex(Tokens.onAccent),
            t.light ? "1" : "0",
            t.frame]
        writer.running = true
    }

    Process { id: writer }

    readonly property string script: `
A=$1; K=$2; G=$3; V=$4; S=$5; F=$6; NAME=$7; WIN=$8; SIDE=$9; shift 9
SURF=$1; SURF2=$2; BORD=$3; TXT=$4; TXT2=$5; ACC=$6; ACCL=$7; ONACC=$8; LIGHT=$9; shift 9
FRAME=$1

# ---------- Kitty ----------
if [ "$K" = 1 ]; then
    f="$HOME/.config/kitty/blink-theme.conf"
    mkdir -p "$(dirname "$f")"
    if [ "$NAME" = blink ]; then
        echo "# Blink theme: pywal decides the colors" > "$f"
    else
        cat > "$f" <<EOF
# Written by Blink (Settings > Appearance). Changes when you pick another theme.
background $WIN
foreground $TXT
cursor $ACC
cursor_text_color $WIN
selection_background $ACC
selection_foreground $ONACC
url_color $ACC
active_border_color $ACC
inactive_border_color $BORD
active_tab_background $ACC
active_tab_foreground $ONACC
inactive_tab_background $SURF2
inactive_tab_foreground $TXT2
tab_bar_background $SIDE
color0 $SURF2
color8 $BORD
color7 $TXT2
color15 $TXT
color4 $ACC
color12 $ACCL
EOF
    fi
    pkill -USR1 -x kitty 2>/dev/null
fi

# ---------- GTK ----------
if [ "$G" = 1 ] && [ -f "$A/gtk/gtk.css" ]; then
    for v in gtk-3.0 gtk-4.0; do
        d="$HOME/.config/$v"; mkdir -p "$d"
        sed -e "s|^@define-color accent_color .*|@define-color accent_color $ACCL;|" \\
            -e "s|^@define-color accent_bg_color .*|@define-color accent_bg_color $ACC;|" \\
            -e "s|^@define-color accent_fg_color .*|@define-color accent_fg_color $ONACC;|" \\
            -e "s|^@define-color \\(window\\|view\\)_bg_color .*|@define-color \\1_bg_color $WIN;|" \\
            -e "s|^@define-color \\(window\\|view\\|headerbar\\|sidebar\\|card\\|popover\\|dialog\\)_fg_color .*|@define-color \\1_fg_color $TXT;|" \\
            -e "s|^@define-color \\(headerbar\\|sidebar\\)_\\(bg\\|backdrop\\)_color .*|@define-color \\1_\\2_color $SURF2;|" \\
            -e "s|^@define-color \\(card\\|popover\\|dialog\\)_bg_color .*|@define-color \\1_bg_color $SURF;|" \\
            -e "s|^@define-color \\(headerbar_border_color\\|borders\\) .*|@define-color \\1 $BORD;|" \\
            "$A/gtk/gtk.css" > "$d/gtk.css.blink" && mv -f "$d/gtk.css.blink" "$d/gtk.css"
    done
    if [ "$LIGHT" = 1 ]; then scheme=prefer-light; else scheme=prefer-dark; fi
    gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null
fi

# ---------- Window title bars (hyprbars) ----------
# hypr/hyprbars.lua reads this file; BlinkBars.apply() shows the new colors right away
h() { echo "$1" | tr -d '#'; }
mkdir -p "$HOME/.config/blink"
cat > "$HOME/.config/blink/hyprbars-colors.lua" <<EOF
-- Written by Blink (Settings > Appearance). Changes when you pick another theme.
return { bar = "rgb($(h $SURF2))", text = "rgb($(h $TXT))", inactive = "rgb($(h $BORD))", win = "rgb($(h $WIN))" }
EOF
command -v hyprctl >/dev/null 2>&1 && hyprctl eval 'if BlinkBars then BlinkBars.apply() end' >/dev/null 2>&1

# ---------- Discord (Vesktop) ----------
if [ "$V" = 1 ] && [ -d "$HOME/.config/vesktop" ] && [ -f "$A/vesktop/MacRice.theme.css" ]; then
    d="$HOME/.config/vesktop/themes"; mkdir -p "$d"
    sed -e "s|--mr-bg: #[0-9a-fA-F]*;|--mr-bg: $WIN;|" \\
        -e "s|--mr-bg-deep: #[0-9a-fA-F]*;|--mr-bg-deep: $SIDE;|" \\
        -e "s|--mr-surface: #[0-9a-fA-F]*;|--mr-surface: $SURF2;|" \\
        -e "s|--mr-surface-high: #[0-9a-fA-F]*;|--mr-surface-high: $SURF;|" \\
        -e "s|--mr-border: #[0-9a-fA-F]*;|--mr-border: $BORD;|" \\
        -e "s|--mr-text: #[0-9a-fA-F]*;|--mr-text: $TXT;|" \\
        -e "s|--mr-text-dim: #[0-9a-fA-F]*;|--mr-text-dim: $TXT2;|" \\
        -e "s|--mr-accent: #[0-9a-fA-F]*;|--mr-accent: $ACC;|" \\
        "$A/vesktop/MacRice.theme.css" > "$d/MacRice.theme.css.blink" && mv -f "$d/MacRice.theme.css.blink" "$d/MacRice.theme.css"
fi

# ---------- Firefox ----------
# The profile used last; Firefox shows a new theme after a restart
if [ "$F" = 1 ] && [ -f "$A/firefox/userChrome.css" ]; then
    P=""
    for base in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
        [ -d "$base" ] || continue
        for d in $(ls -td "$base"/*/ 2>/dev/null); do
            if [ -f "$d/prefs.js" ]; then P="\${d%/}"; break; fi
        done
        [ -n "$P" ] && break
    done
    if [ -n "$P" ]; then
        mkdir -p "$P/chrome"
        # Light themes: white tabs and address bar on the grey frame, so they stand out
        if [ "$LIGHT" = 1 ]; then FTAB=$SURF; FFIELD=$SURF; FSCHEME=light
        else FTAB=$SURF2; FFIELD=$SIDE; FSCHEME=dark; fi
        sed -e "s|--mr-bg: #[0-9a-fA-F]*;|--mr-bg: $FRAME;|" \\
            -e "s|--mr-surface: #[0-9a-fA-F]*;|--mr-surface: $FTAB;|" \\
            -e "s|--mr-surface-alt: #[0-9a-fA-F]*;|--mr-surface-alt: $FFIELD;|" \\
            -e "s|color-scheme: dark|color-scheme: $FSCHEME|" \\
            -e "s|--mr-border: #[0-9a-fA-F]*;|--mr-border: $BORD;|" \\
            -e "s|--mr-text: #[0-9a-fA-F]*;|--mr-text: $TXT;|" \\
            -e "s|--mr-text-dim: #[0-9a-fA-F]*;|--mr-text-dim: $TXT2;|" \\
            -e "s|--mr-accent: #[0-9a-fA-F]*;|--mr-accent: $ACC;|" \\
            -e "s|--mr-bar: #[0-9a-fA-F]*;|--mr-bar: $SURF2;|" \\
            "$A/firefox/userChrome.css" > "$P/chrome/userChrome.css.blink" && mv -f "$P/chrome/userChrome.css.blink" "$P/chrome/userChrome.css"
        sed -e "s|#1c1c1e|$WIN|gI" -e "s|#000000|$FRAME|gI" -e "s|#2c2c2e|$SURF|gI" -e "s|#3a3a3c|$BORD|gI" -e "s|#e5e5e7|$TXT|gI" \\
            "$A/firefox/userContent.css" > "$P/chrome/userContent.css.blink" && mv -f "$P/chrome/userContent.css.blink" "$P/chrome/userContent.css"
        # Firefox keeps a compiled copy of the old CSS; drop it so a restart shows the new theme
        rm -rf "$HOME/.cache/mozilla/firefox/$(basename "$P")/startupCache" "$P/startupCache" 2>/dev/null
    fi
fi

# ---------- Spotify (Spicetify) ----------
if [ "$S" = 1 ] && command -v spicetify >/dev/null 2>&1; then
    T="$(dirname "$(spicetify -c)")/Themes/Blink"
    mkdir -p "$T"
    cp -f "$A/spicetify/MacRice/user.css" "$T/user.css" 2>/dev/null
    n() { echo "$1" | tr -d '#'; }
    cat > "$T/color.ini" <<EOF
[Blink]
text               = $(n $TXT)
subtext            = $(n $TXT2)
main               = $(n $WIN)
main-elevated      = $(n $SURF)
highlight          = $(n $SURF)
highlight-elevated = $(n $BORD)
sidebar            = $(n $WIN)
player             = $(n $WIN)
card               = $(n $SURF2)
shadow             = 000000
selected-row       = $(n $TXT)
button             = $(n $ACC)
button-active      = $(n $ACCL)
button-disabled    = $(n $BORD)
tab-active         = $(n $SURF)
notification       = $(n $ACC)
notification-error = ff453a
misc               = $(n $BORD)
EOF
    stamp="$HOME/.cache/blink/spotify-theme"
    now="$NAME $ACC"
    if [ ! -f "$stamp" ]; then
        # First time: a full apply (Spotify restarts this once)
        spicetify config current_theme Blink color_scheme Blink >/dev/null 2>&1
        spicetify apply >/dev/null 2>&1
    elif [ "$(cat "$stamp" 2>/dev/null)" != "$now" ]; then
        # After that: swap the colors in place, Spotify keeps playing.
        # It shows them after a reload (Ctrl+Shift+R in Spotify) or the next start.
        spicetify update >/dev/null 2>&1 || spicetify apply --no-restart >/dev/null 2>&1
    fi
    mkdir -p "$(dirname "$stamp")"
    echo "$now" > "$stamp"
fi
`
}
