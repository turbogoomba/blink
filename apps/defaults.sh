#!/usr/bin/env bash
# Which app opens which file (double-click in Nautilus, xdg-open, "Open" in apps).
# Like a Mac: Papers is Preview for PDFs, Loupe (or Gwenview) for pictures, mpv for
# video and music, Neovim for text, Nautilus for folders.
# Run it again any time:  apps/defaults.sh
set -u

has() { [ -e "/usr/share/applications/$1" ] || [ -e "$HOME/.local/share/applications/$1" ] \
        || [ -e "/var/lib/flatpak/exports/share/applications/$1" ]; }
first() { for a in "$@"; do has "$a" && { echo "$a"; return; }; done; }
set_for() {
    local app="$1"; shift
    [ -n "$app" ] || return
    xdg-mime default "$app" "$@" && echo "  ok: $app"
}

PDF=$(first org.gnome.Papers.desktop org.pwmt.zathura-pdf-mupdf.desktop org.pwmt.zathura.desktop)
IMG=$(first org.gnome.Loupe.desktop org.kde.gwenview.desktop)
VID=$(first mpv.desktop org.kde.haruna.desktop)
TXT=$(first blink-nvim.desktop nvim.desktop org.kde.kate.desktop)

set_for "$PDF" application/pdf application/x-pdf application/epub+zip
set_for "$IMG" image/png image/jpeg image/gif image/webp image/bmp image/tiff image/svg+xml image/avif image/heic
set_for "$VID" video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo \
    audio/mpeg audio/flac audio/ogg audio/wav audio/x-wav audio/mp4 audio/opus
set_for "$TXT" text/plain text/markdown text/x-markdown text/x-python text/x-csrc text/x-chdr \
    text/x-c++src text/x-tex application/x-shellscript application/json application/toml \
    application/x-yaml text/x-lua
set_for org.gnome.Nautilus.desktop inode/directory

[ -z "$IMG" ] || [ "$IMG" = org.gnome.Loupe.desktop ] \
    || echo "  tip: sudo pacman -S loupe   (GNOME's picture viewer, closest to macOS Preview), then run this again"
