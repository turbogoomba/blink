#!/usr/bin/env bash
# Kobler Blink-temaene for Firefox, Vesktop og Spotify til riktige steder.
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
