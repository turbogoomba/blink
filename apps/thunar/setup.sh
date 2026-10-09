#!/usr/bin/env bash
# Thunar laid out like Finder: no menu bar, sidebar with places, path as pills, icon view.
# Safe to run again. Close Thunar first (thunar -q) so it picks up the changes.

set_opt() {
    xfconf-query -c thunar -p "$1" -s "$3" 2>/dev/null \
        || xfconf-query -c thunar -p "$1" -n -t "$2" -s "$3"
}

if ! command -v xfconf-query >/dev/null 2>&1; then
    echo "  xfconf-query is missing (package xfconf). Skipping Thunar layout."
    exit 0
fi

set_opt /last-menubar-visible bool false
set_opt /last-statusbar-visible bool false
set_opt /last-location-bar string ThunarLocationButtons
set_opt /last-side-pane string ThunarShortcutsPane
set_opt /last-view string ThunarIconView
set_opt /last-icon-view-zoom-level string THUNAR_ZOOM_LEVEL_100_PERCENT
set_opt /shortcuts-icon-size string THUNAR_ICON_SIZE_16
set_opt /misc-folders-first bool true
echo "  ok: Thunar layout (Finder style)"
