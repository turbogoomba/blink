#!/usr/bin/env bash
# Nautilus laid out like Finder: window buttons on the left, list view with
# Name / Date Modified / Size / Kind, compact rows, Desktop / Documents / Downloads in the sidebar.
# The colors and the round buttons come from apps/gtk/gtk.css (ThemeService writes it).
# Safe to run again. Close Nautilus first (nautilus -q) so it picks up the changes.

if ! gsettings list-schemas 2>/dev/null | grep -qx org.gnome.nautilus.preferences; then
    echo "  Nautilus is not installed. Skipping Nautilus layout."
    exit 0
fi

gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gsettings set org.gnome.nautilus.preferences date-time-format 'detailed'
gsettings set org.gnome.nautilus.list-view default-zoom-level 'small'
gsettings set org.gnome.nautilus.list-view default-visible-columns "['name', 'date_modified', 'size', 'type']"
gsettings set org.gnome.nautilus.list-view default-column-order "['name', 'date_modified', 'size', 'type']"

# Sidebar shortcuts (GTK bookmarks)
bm="$HOME/.config/gtk-3.0/bookmarks"
mkdir -p "$(dirname "$bm")"
touch "$bm"
for d in Desktop Documents Downloads; do
    [ -d "$HOME/$d" ] || continue
    grep -q "^file://$HOME/$d " "$bm" || echo "file://$HOME/$d $d" >> "$bm"
done

echo "  ok: Nautilus layout (Finder style)"
