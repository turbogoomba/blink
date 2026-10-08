#!/usr/bin/env bash
# Kobler Blink-temaene for Firefox, Vesktop, Spotify, GTK og Thunar til riktige steder.
# Filene blir liggende i repoet; programmene får bare snarveier til dem.
# Trygt å kjøre flere ganger.

APPS="$(cd "$(dirname "$0")" && pwd)"

link() {
    mkdir -p "$(dirname "$2")"
    ln -sfn "$1" "$2"
    echo "  ok: $2"
}

# ---------- Firefox ----------
echo "Firefox"
PROFILE=""
for base in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
    [ -d "$base" ] || continue
    # Profilen som er brukt sist
    for d in $(ls -td "$base"/*/ 2>/dev/null); do
        if [ -f "$d/prefs.js" ]; then
            PROFILE="${d%/}"
            break
        fi
    done
    [ -n "$PROFILE" ] && break
done

if [ -n "$PROFILE" ]; then
    link "$APPS/firefox/userChrome.css" "$PROFILE/chrome/userChrome.css"
    link "$APPS/firefox/userContent.css" "$PROFILE/chrome/userContent.css"
    if ! grep -q "legacyUserProfileCustomizations" "$PROFILE/user.js" 2>/dev/null; then
        echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$PROFILE/user.js"
        echo "  ok: slo på egen CSS i user.js"
    fi
    echo "  -> Start Firefox på nytt"
else
    echo "  Fant ingen Firefox-profil. Start Firefox én gang og kjør skriptet igjen."
fi
echo

# ---------- Vesktop ----------
echo "Vesktop"
link "$APPS/vesktop/MacRice.theme.css" "$HOME/.config/vesktop/themes/MacRice.theme.css"
echo "  -> Slå på i Vesktop: Settings > Vencord > Themes > Blink"
echo

# ---------- Spotify (Spicetify) ----------
echo "Spotify"
if command -v spicetify >/dev/null 2>&1; then
    SPDIR="$(dirname "$(spicetify -c)")/Themes"
    link "$APPS/spicetify/MacRice" "$SPDIR/MacRice"
    spicetify config current_theme MacRice color_scheme MacRice >/dev/null
    if spicetify backup apply >/dev/null 2>&1 || spicetify apply >/dev/null 2>&1; then
        echo "  ok: tema aktivert"
    else
        echo "  Klarte ikke å aktivere. Kjør 'spicetify backup apply' selv og se feilmeldingen."
    fi
else
    echo "  spicetify er ikke installert. Installer med: yay -S spicetify-cli"
fi

echo

# ---------- GTK and Thunar ----------
# A real gtk.css you made yourself is moved aside first, never lost
echo "GTK and Thunar"
for v in gtk-3.0 gtk-4.0; do
    dst="$HOME/.config/$v/gtk.css"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak-$(date +%Y%m%d-%H%M%S)"
        echo "  moved your old $v/gtk.css aside (.bak)"
    fi
    link "$APPS/gtk/gtk.css" "$dst"
done
"$APPS/thunar/setup.sh"

# Font and icons for GTK apps: IBM Plex Sans like Blink, WhiteSur (macOS style) icons
if [ ! -d "$HOME/.local/share/icons/WhiteSur-dark" ] && [ ! -d /usr/share/icons/WhiteSur-dark ]; then
    git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme /tmp/whitesur-icons >/dev/null 2>&1 \
        && /tmp/whitesur-icons/install.sh -a >/dev/null && echo "  ok: WhiteSur icons installed"
    rm -rf /tmp/whitesur-icons
fi
ini="$HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$(dirname "$ini")"
[ -f "$ini" ] || printf '[Settings]\n' > "$ini"
set_ini() {
    if grep -q "^$1=" "$ini"; then sed -i "s|^$1=.*|$1=$2|" "$ini"; else echo "$1=$2" >> "$ini"; fi
}
set_ini gtk-icon-theme-name WhiteSur-dark
set_ini gtk-font-name "IBM Plex Sans 10"
gsettings set org.gnome.desktop.interface icon-theme WhiteSur-dark 2>/dev/null
gsettings set org.gnome.desktop.interface font-name "IBM Plex Sans 10" 2>/dev/null
echo "  ok: GTK font IBM Plex Sans, icons WhiteSur-dark"

# Thunar opens folders everywhere: xdg-open, and "Show in folder" from apps.
# A copy in ~/.local wins over other file managers (Dolphin, Nautilus) installed system wide.
xdg-mime default thunar.desktop inode/directory && echo "  ok: Thunar is the default for folders"
if [ -f /usr/share/dbus-1/services/org.xfce.Thunar.FileManager1.service ]; then
    link /usr/share/dbus-1/services/org.xfce.Thunar.FileManager1.service \
        "$HOME/.local/share/dbus-1/services/org.freedesktop.FileManager1.service"
fi
echo "  -> Restart Thunar: thunar -q"
