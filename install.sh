#!/usr/bin/env bash
# Mac Rice installer: sets up the whole desktop on a new machine (Arch Linux).
# Safe to run again: it skips what is already done and backs up what it replaces.
#
#   ./install.sh            ask before each step
#   ./install.sh --yes      do everything without asking
#   ./install.sh --no-packages   skip installing packages

set -u

REPO="$(cd "$(dirname "$0")" && pwd)"
HOST="$(cat /etc/hostname 2>/dev/null || hostname)"
YES=0
PACKAGES=1
for arg in "$@"; do
    case "$arg" in
        --yes|-y) YES=1 ;;
        --no-packages) PACKAGES=0 ;;
    esac
done

# ---------- Small helpers ----------
bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32mok\033[0m  %s\n' "$1"; }
skip() { printf '  \033[90m--  %s\033[0m\n' "$1"; }
warn() { printf '  \033[33m!!\033[0m  %s\n' "$1"; }

ask() {
    [ "$YES" = 1 ] && return 0
    read -r -p "  $1 [Y/n] " a
    [ -z "$a" ] || [ "$a" = "y" ] || [ "$a" = "Y" ]
}

# Point $2 at $1. An existing real file or folder is moved to *.bak-<date> first.
link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        skip "$dst already linked"
        return
    fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        local bak="$dst.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$bak"
        warn "moved old $dst to $bak"
    fi
    ln -sfn "$src" "$dst"
    ok "$dst -> $src"
}

echo "Mac Rice installer"
echo "  repo:    $REPO"
echo "  machine: $HOST"

# ---------- 1. Packages ----------
PKGS=(
    # shell and desktop
    hyprland quickshell awww hypridle hyprlock hyprsunset
    # tools the shell uses
    brightnessctl ddcutil playerctl cava grim slurp wl-clipboard libnotify jq curl
    wf-recorder ffmpeg pipewire wireplumber power-profiles-daemon networkmanager
    # apps
    kitty btop thunar
    # look
    ttf-ibm-plex papirus-icon-theme apple_cursor
    # login screen
    sddm qt6-declarative
)

if [ "$PACKAGES" = 1 ]; then
    bold "1. Packages"
    if ask "Install missing packages?"; then
        official=()
        aur=()
        for p in "${PKGS[@]}"; do
            if pacman -Qq "$p" &>/dev/null; then continue; fi
            if pacman -Si "$p" &>/dev/null; then official+=("$p"); else aur+=("$p"); fi
        done

        if [ ${#official[@]} -gt 0 ]; then
            sudo pacman -S --needed "${official[@]}" && ok "installed: ${official[*]}"
        else
            skip "all official packages are installed"
        fi

        if [ ${#aur[@]} -gt 0 ]; then
            helper=""
            command -v yay &>/dev/null && helper=yay
            [ -z "$helper" ] && command -v paru &>/dev/null && helper=paru
            if [ -n "$helper" ]; then
                "$helper" -S --needed "${aur[@]}" && ok "installed from AUR: ${aur[*]}"
            else
                warn "no AUR helper (yay or paru). Install these yourself: ${aur[*]}"
            fi
        else
            skip "all AUR packages are installed"
        fi
    else
        skip "packages"
    fi
fi

# ---------- 2. Hyprland ----------
bold "2. Hyprland config"
if ask "Link ~/.config/hypr to the repo?"; then
    link "$REPO/hypr" "$HOME/.config/hypr"

    # Hyprland reads hyprland.conf before hyprland.lua if both exist
    if [ -f "$REPO/hypr/hyprland.conf" ]; then
        warn "hypr/hyprland.conf exists and would be used instead of hyprland.lua. Delete it."
    fi

    # Machine file (monitors, touchpad)
    machine="$REPO/hypr/machines/$HOST.lua"
    if [ -f "$machine" ]; then
        skip "machines/$HOST.lua already exists"
    elif [ -f "$REPO/hypr/machines/desktop.lua" ] && ask "No machines/$HOST.lua. Use the desktop template (two monitors)?"; then
        cp "$REPO/hypr/machines/desktop.lua" "$machine"
        ok "created machines/$HOST.lua from desktop.lua (check monitor names with: hyprctl monitors)"
    else
        cp "$REPO/hypr/machines/default.lua" "$machine"
        ok "created machines/$HOST.lua from default.lua"
    fi

    # Per-machine overrides, not in git
    [ -f "$REPO/hypr/overrides.lua" ] || { echo "-- Local tweaks for this machine only" > "$REPO/hypr/overrides.lua"; ok "created hypr/overrides.lua"; }
else
    skip "Hyprland"
fi

# ---------- 3. Quickshell service ----------
bold "3. Quickshell"
if ask "Set up Quickshell as a service (starts with Hyprland, restarts if it crashes)?"; then
    link "$REPO/systemd/quickshell.service" "$HOME/.config/systemd/user/quickshell.service"
    systemctl --user daemon-reload && ok "systemd reloaded"
    mkdir -p "$HOME/.config/mac-hypr-rice" "$HOME/Pictures/Wallpapers" "$HOME/Videos/Recordings"
    ok "created ~/.config/mac-hypr-rice, ~/Pictures/Wallpapers, ~/Videos/Recordings"
else
    skip "Quickshell"
fi

# ---------- 4. System services ----------
bold "4. System services"
if ask "Turn on power profiles (Saver / Balanced / Performance)?"; then
    sudo systemctl enable --now power-profiles-daemon && ok "power-profiles-daemon"
else
    skip "power profiles"
fi

# ---------- 5. Login screen ----------
bold "5. Login screen (SDDM)"
if [ -d "$REPO/sddm/mac-rice" ] && ask "Install the Mac Rice login screen?"; then
    sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
    sudo cp -r "$REPO/sddm/mac-rice" /usr/share/sddm/themes/ && ok "theme copied"

    wall="$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) | head -1)"
    if [ -n "$wall" ]; then
        sudo cp "$wall" /usr/share/sddm/themes/mac-rice/background.jpg && ok "background: $(basename "$wall")"
    else
        warn "no wallpaper found in ~/Pictures/Wallpapers, the login screen will be dark"
    fi

    printf '[Theme]\nCurrent=mac-rice\nCursorTheme=macOS\nCursorSize=24\n' | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null
    ok "SDDM uses mac-rice"

    current="$(systemctl show -p Id --value display-manager 2>/dev/null)"
    if [ -z "$current" ]; then
        if ask "No login manager is enabled. Enable SDDM?"; then
            sudo systemctl enable sddm && ok "SDDM enabled (used from next boot)"
        fi
    elif [ "$current" != "sddm.service" ]; then
        warn "you use $current. Switch yourself if you want SDDM: sudo systemctl disable $current && sudo systemctl enable sddm"
    else
        skip "SDDM already enabled"
    fi
else
    skip "login screen"
fi

# ---------- 6. App themes ----------
bold "6. App themes (Firefox, Spotify, Vesktop)"
if [ -x "$REPO/apps/install.sh" ] && ask "Run the app theme installer?"; then
    "$REPO/apps/install.sh"
else
    skip "app themes"
fi

# ---------- Done ----------
bold "Done"
cat <<EOF
  Next:
  - Log out and in again (or reboot) to start everything.
  - Check monitors in hypr/machines/$HOST.lua (names from: hyprctl monitors).
  - Put wallpapers in ~/Pictures/Wallpapers, then pick one with Super+W.
  - Timetable in the notch: Settings > Notch > paste your calendar link.
  - Restart the shell any time with: systemctl --user restart quickshell
EOF
