#!/usr/bin/env bash
# Your own app icons on top of MacTahoe (for example dark Tahoe icons from macosicons.com).
#
#   1. Download the icons as PNG into one folder (default: ~/Downloads/dock-icons).
#   2. Name each file after the app: firefox.png, spotify.png, obsidian.png, vesktop.png ...
#      (the app's name or its .desktop file name; the script finds the right icon name).
#   3. Run:  apps/icons/install.sh            or  apps/icons/install.sh ~/some/folder
#
# The icons go into a small icon theme "Blink" (~/.local/share/icons/Blink) that uses
# MacTahoe-dark for everything else. Blink and GTK apps use that theme.
# Run it again whenever you add or change an icon. Delete a file from
# ~/.local/share/icons/Blink/512x512/apps to go back to the normal icon.
set -euo pipefail

SRC="${1:-$HOME/Downloads/dock-icons}"
THEME="$HOME/.local/share/icons/Blink"
BASE="MacTahoe-dark"
DIR="$THEME/512x512/apps"

mkdir -p "$DIR"
cat > "$THEME/index.theme" <<EOF
[Icon Theme]
Name=Blink
Comment=Your own app icons, on top of $BASE
Inherits=$BASE,hicolor
Directories=512x512/apps

[512x512/apps]
Size=512
MinSize=16
MaxSize=1024
Type=Scalable
Context=Applications
EOF

# The Icon= name an app uses, from its .desktop file (by file name or by Name=)
icon_for() {
    local want="$1" f
    local dirs=("$HOME/.local/share/applications" /usr/share/applications
                /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications")
    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        # By file name: firefox.desktop, org.gnome.Nautilus.desktop, dev.vencord.Vesktop.desktop ...
        for f in "$d"/*.desktop; do
            [ -e "$f" ] || continue
            local base; base="$(basename "$f" .desktop)"
            if [ "${base,,}" = "${want,,}" ] || [ "${base##*.}" = "$want" ] || [ "${base,,##*.}" = "${want,,}" ]; then
                grep -m1 '^Icon=' "$f" | cut -d= -f2- && return
            fi
        done
        # By the app's name: Name=Spotify
        f="$(grep -lix "Name=$want" "$d"/*.desktop 2>/dev/null | head -1 || true)"
        if [ -n "$f" ]; then grep -m1 '^Icon=' "$f" | cut -d= -f2- && return; fi
    done
}

[ -d "$SRC" ] || { echo "No folder $SRC. Put your PNG icons there, or give the folder: $0 <folder>"; exit 1; }

n=0
shopt -s nullglob nocaseglob
for png in "$SRC"/*.png; do
    name="$(basename "$png")"; name="${name%.*}"
    icon="$(icon_for "$name" || true)"
    # An Icon= that is a full path cannot be themed; fall back to the file's own name
    if [ -z "$icon" ] || [[ "$icon" == /* ]]; then icon="$name"; fi
    cp -f "$png" "$DIR/$icon.png"
    echo "  $name -> $icon"
    n=$((n + 1))
done
shopt -u nocaseglob

gtk-update-icon-cache -f -t "$THEME" >/dev/null 2>&1 || true
echo "Installed $n icon(s) into the Blink icon theme."

# Use the theme: GTK apps now, Blink after a restart
gsettings set org.gnome.desktop.interface icon-theme Blink 2>/dev/null || true
ini="$HOME/.config/gtk-3.0/settings.ini"
[ -f "$ini" ] && sed -i 's/^gtk-icon-theme-name=.*/gtk-icon-theme-name=Blink/' "$ini"
systemctl --user set-environment QS_ICON_THEME=Blink 2>/dev/null || true
systemctl --user restart blink 2>/dev/null || true
echo "Blink restarted with the new icons. Apps that are open show them after a restart."
