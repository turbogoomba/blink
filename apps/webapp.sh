#!/usr/bin/env bash
# A website as an app in the dock and launcher, in its own window (like a Mac web app).
# Clicking it in the dock goes to the window when it is open, or opens it.
#
#   apps/webapp.sh "Gmail" https://mail.google.com/            add it (and pin it to the dock)
#   apps/webapp.sh "Canvas" https://oslomet.instructure.com/ --no-pin
#   apps/webapp.sh --remove "Gmail"
#
# Uses Chrome's app windows (Firefox has no separate app windows). The icon is the
# app's own name: put a .icns named after it in ~/Downloads (gmail.icns, canvas.icns)
# and run apps/icons/install.sh, or it shows the website's generic icon.
set -euo pipefail

APPS_DIR="$HOME/.local/share/applications"
SETTINGS="$HOME/.config/blink/settings.json"

slug() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//'; }

pin() {    # add to the end of the dock's pinned apps
    [ -f "$SETTINGS" ] && command -v jq >/dev/null || return 0
    jq --arg id "$1" '.dockApps = ((.dockApps // []) | if index($id) then . else . + [$id] end)' \
        "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
}
unpin() {
    [ -f "$SETTINGS" ] && command -v jq >/dev/null || return 0
    jq --arg id "$1" '.dockApps = ((.dockApps // []) - [$id])' "$SETTINGS" > "$SETTINGS.tmp" \
        && mv "$SETTINGS.tmp" "$SETTINGS"
}

if [ "${1:-}" = "--remove" ]; then
    id="blink-$(slug "${2:?name}")"
    rm -f "$APPS_DIR/$id.desktop"
    unpin "$id"
    echo "Removed $2"
    exit 0
fi

NAME="${1:?usage: $0 \"Name\" https://url [--no-pin]}"
URL="${2:?usage: $0 \"Name\" https://url [--no-pin]}"
NOPIN="${3:-}"

CHROME="$(command -v google-chrome-stable || command -v google-chrome || command -v chromium || true)"
[ -n "$CHROME" ] || { echo "Needs Chrome or Chromium for app windows (yay -S google-chrome)"; exit 1; }

ID="blink-$(slug "$NAME")"
# Chrome names an app window after its address: chrome-<host>__<path>-Default
HOSTPATH="$(echo "$URL" | sed -E 's#^https?://##')"
HOST="${HOSTPATH%%/*}"
PATHPART="${HOSTPATH#"$HOST"}"; PATHPART="${PATHPART#/}"
CLASS="chrome-${HOST}__$(echo "$PATHPART" | tr '/' '_')-Default"
case "$(basename "$CHROME")" in chromium*) CLASS="${CLASS/chrome-/chromium-}" ;; esac

mkdir -p "$APPS_DIR"
cat > "$APPS_DIR/$ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
Comment=$URL in its own window
Exec=$CHROME --app=$URL
Icon=$ID
StartupWMClass=$CLASS
Terminal=false
Categories=Network;WebBrowser;
EOF
echo "  ok: $NAME ($ID) -> $URL"
[ "$NOPIN" = "--no-pin" ] || { pin "$ID" && echo "  pinned to the dock"; }
