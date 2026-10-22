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
    # Blink's settings (apps/firefox/user.js) between markers in the profile's user.js,
    # replaced each time, so your own lines in user.js stay
    uj="$PROFILE/user.js"
    touch "$uj"
    sed -i '/^\/\/ >>> Blink >>>$/,/^\/\/ <<< Blink <<<$/d' "$uj"
    { echo "// >>> Blink >>>"; cat "$APPS/firefox/user.js"; echo "// <<< Blink <<<"; } >> "$uj"
    echo "  ok: Blink settings in user.js (custom CSS, new tab with favorites)"
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

# ---------- GTK and Nautilus ----------
# A real gtk.css you made yourself is moved aside first, never lost
echo "GTK and Nautilus"
for v in gtk-3.0 gtk-4.0; do
    dst="$HOME/.config/$v/gtk.css"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak-$(date +%Y%m%d-%H%M%S)"
        echo "  moved your old $v/gtk.css aside (.bak)"
    fi
    link "$APPS/gtk/gtk.css" "$dst"
done
"$APPS/nautilus/setup.sh"
command -v thunar >/dev/null && "$APPS/thunar/setup.sh"

# Font and icons for GTK apps: Inter (close to the macOS font) like Blink, WhiteSur (macOS style) icons
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
set_ini gtk-font-name "Inter 10"
set_ini gtk-cursor-theme-name macOS
set_ini gtk-cursor-theme-size 24
gsettings set org.gnome.desktop.interface icon-theme WhiteSur-dark 2>/dev/null
gsettings set org.gnome.desktop.interface font-name "Inter 10" 2>/dev/null
gsettings set org.gnome.desktop.interface cursor-theme macOS 2>/dev/null
gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null
# Older X11 apps (Steam, games through XWayland) read the default cursor from here
mkdir -p "$HOME/.icons/default"
printf '[Icon Theme]\nInherits=macOS\n' > "$HOME/.icons/default/index.theme"
echo "  ok: GTK font Inter, icons WhiteSur-dark, cursor macOS"

# Nautilus opens folders everywhere: xdg-open, and "Show in folder" from apps.
# Nautilus answers "Show in folder" itself. Older Blink installs pointed that at Thunar
# with a link in ~/.local, which would win, so that link is removed.
xdg-mime default org.gnome.Nautilus.desktop inode/directory && echo "  ok: Nautilus is the default for folders"
fm1="$HOME/.local/share/dbus-1/services/org.freedesktop.FileManager1.service"
if [ -L "$fm1" ] && readlink "$fm1" | grep -qi thunar; then
    rm -f "$fm1" && echo "  ok: \"Show in folder\" no longer goes to Thunar"
fi
echo "  -> Restart Nautilus: nautilus -q"
