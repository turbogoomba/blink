#!/usr/bin/env bash
# One-time move from mac-hypr-rice to Blink. Run it from the renamed repo folder:
#   mv ~/Documents/GitHub/mac-hypr-rice ~/Documents/GitHub/blink
#   ~/Documents/GitHub/blink/migrate-to-blink.sh
# Safe to run again. Delete this file once both machines are moved.

set -u

REPO="$(cd "$(dirname "$0")" && pwd)"
OLD="$HOME/Documents/GitHub/mac-hypr-rice"

ok()   { printf '  \033[32mok\033[0m  %s\n' "$1"; }
skip() { printf '  \033[90m--  %s\033[0m\n' "$1"; }
warn() { printf '  \033[33m!!\033[0m  %s\n' "$1"; }

echo "Blink migration"
echo "  repo: $REPO"

if [ -d "$OLD" ] && [ "$OLD" != "$REPO" ]; then
    warn "$OLD still exists. Move it first: mv $OLD $REPO"
    exit 1
fi

# 1. Stop the old shell service
if [ -e "$HOME/.config/systemd/user/quickshell.service" ] || [ -L "$HOME/.config/systemd/user/quickshell.service" ]; then
    systemctl --user disable --now quickshell.service 2>/dev/null
    rm -f "$HOME/.config/systemd/user/quickshell.service"
    ok "removed quickshell.service"
else
    skip "quickshell.service already gone"
fi

# 2. Settings folder
if [ -d "$HOME/.config/mac-hypr-rice" ] && [ ! -e "$HOME/.config/blink" ]; then
    mv "$HOME/.config/mac-hypr-rice" "$HOME/.config/blink"
    ok "moved ~/.config/mac-hypr-rice to ~/.config/blink"
elif [ -d "$HOME/.config/mac-hypr-rice" ]; then
    warn "both ~/.config/mac-hypr-rice and ~/.config/blink exist, left them alone"
else
    mkdir -p "$HOME/.config/blink"
    skip "settings folder already moved"
fi

# 3. Point every symlink that used the old repo path at the new one
#    (hypr config, Firefox/Spotify/Vesktop themes, ...)
n=0
while IFS= read -r l; do
    t="$(readlink "$l")"
    case "$t" in
        "$OLD"|"$OLD"/*)
            ln -sfn "$REPO${t#"$OLD"}" "$l"
            n=$((n + 1))
            ;;
    esac
done < <(find "$HOME/.config" "$HOME/.mozilla" "$HOME/.local" -maxdepth 6 -type l 2>/dev/null)
ok "relinked $n symlink(s) to the new repo path"

# 4. New links: shell config name and service
mkdir -p "$HOME/.config/quickshell" "$HOME/.config/systemd/user"
ln -sfn "$REPO/quickshell" "$HOME/.config/quickshell/blink" && ok "~/.config/quickshell/blink -> repo"
ln -sfn "$REPO/systemd/blink.service" "$HOME/.config/systemd/user/blink.service" && ok "blink.service linked"
systemctl --user daemon-reload

# 5. Git remote (only after the GitHub repo is renamed; GitHub redirects the old name anyway)
url="$(git -C "$REPO" remote get-url origin 2>/dev/null)"
case "$url" in
    *mac-hypr-rice*)
        git -C "$REPO" remote set-url origin "${url/mac-hypr-rice/blink}"
        ok "origin -> ${url/mac-hypr-rice/blink}"
        ;;
    *) skip "origin already updated" ;;
esac

# 6. Login screen (needs sudo)
if [ -d /usr/share/sddm/themes/mac-rice ]; then
    read -r -p "  Move the SDDM theme to blink (sudo)? [Y/n] " a
    if [ -z "$a" ] || [ "$a" = "y" ] || [ "$a" = "Y" ]; then
        sudo cp -r "$REPO/sddm/blink" /usr/share/sddm/themes/
        if [ -f /usr/share/sddm/themes/mac-rice/background.jpg ]; then
            sudo cp /usr/share/sddm/themes/mac-rice/background.jpg /usr/share/sddm/themes/blink/background.jpg
        fi
        if [ -f /etc/sddm.conf.d/theme.conf ]; then
            sudo sed -i 's/^Current=mac-rice$/Current=blink/' /etc/sddm.conf.d/theme.conf
        fi
        sudo rm -rf /usr/share/sddm/themes/mac-rice
        ok "SDDM uses blink"
    else
        skip "SDDM theme"
    fi
else
    skip "no old SDDM theme"
fi

# 7. Start Blink
hyprctl reload >/dev/null 2>&1
systemctl --user restart blink.service && ok "blink.service running"

echo
echo "Done. Restart the shell from now on with: systemctl --user restart blink"
