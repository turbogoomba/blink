#!/usr/bin/env bash
# ~/scripts/wal-reload.sh
# Runs after wal: pushes new pywal colors to every open Kitty window,
# then forces white text back on.

for sock in /tmp/kitty-*; do
    [ -S "$sock" ] || continue
    kitty @ --to "unix:$sock" set-colors --all --configured \
        ~/.cache/wal/colors-kitty.conf
    kitty @ --to "unix:$sock" set-colors --all --configured \
        foreground=#ffffff selection_foreground=#ffffff background=#1c1c1e selection_background=#3a3a3c
done
