#!/usr/bin/env bash
# A website as an app in the dock and launcher, in its own window (like a Mac web app).
# Clicking it in the dock goes to the window when it is open, or opens it.
#
#   apps/webapp.sh "Gmail" https://mail.google.com/            add it (and pin it to the dock)
#   apps/webapp.sh "Canvas" https://oslomet.instructure.com/ --no-pin
#   apps/webapp.sh --remove "Gmail"
#
# Opens in Firefox by default: each web app gets its own small Firefox profile with the
# tabs and address bar hidden, so it looks like an app (sign in once in each).
# Back / forward: Alt+Left / Alt+Right, reload: F5. Add --chrome for a Chrome app window.
# The icon is the app's own name: put a .icns named after it in ~/Downloads (gmail.icns,
# canvas.icns) and run apps/icons/install.sh, or it shows a generic icon.
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
    rm -rf "$HOME/.local/share/blink-webapps/$id"
    unpin "$id"
    echo "Removed $2"
    exit 0
fi

NAME="${1:?usage: $0 \"Name\" https://url [--no-pin] [--chrome]}"
URL="${2:?usage: $0 \"Name\" https://url [--no-pin] [--chrome]}"
shift 2
NOPIN=""; BROWSER=firefox
for a in "$@"; do
    case "$a" in --no-pin) NOPIN=--no-pin ;; --chrome) BROWSER=chrome ;; esac
done

ID="blink-$(slug "$NAME")"

if [ "$BROWSER" = chrome ]; then
    CHROME="$(command -v google-chrome-stable || command -v google-chrome || command -v chromium || true)"
    [ -n "$CHROME" ] || { echo "Needs Chrome or Chromium for --chrome"; exit 1; }
    # Chrome names an app window after its address: chrome-<host>__<path>-Default
    HOSTPATH="$(echo "$URL" | sed -E 's#^https?://##')"
    HOST="${HOSTPATH%%/*}"
    PATHPART="${HOSTPATH#"$HOST"}"; PATHPART="${PATHPART#/}"
    CLASS="chrome-${HOST}__$(echo "$PATHPART" | tr '/' '_')-Default"
    case "$(basename "$CHROME")" in chromium*) CLASS="${CLASS/chrome-/chromium-}" ;; esac
    EXEC="$CHROME --app=$URL"
else
    command -v firefox >/dev/null || { echo "Needs Firefox (or use --chrome)"; exit 1; }
    PROFILE="$HOME/.local/share/blink-webapps/$ID"
    mkdir -p "$PROFILE/chrome"
    # Quiet first start, and our own stylesheet
    cat > "$PROFILE/user.js" <<EOF
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("startup.homepage_welcome_url", "");
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("sidebar.revamp", false);
user_pref("browser.tabs.warnOnClose", false);
EOF
    # No tabs, no address bar: just the page (Blink's title bar is above it)
    cat > "$PROFILE/chrome/userChrome.css" <<'EOF'
#TabsToolbar, #nav-bar, #PersonalToolbar, #titlebar, #sidebar-main, #sidebar-box {
  visibility: collapse !important;
}
EOF
    CLASS="$ID"
    # Own profile and window name, so it is its own app in the dock
    EXEC="firefox --no-remote --profile $PROFILE --name $ID --class $ID $URL"
fi

mkdir -p "$APPS_DIR"
cat > "$APPS_DIR/$ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
Comment=$URL in its own window
Exec=$EXEC
Icon=$ID
StartupWMClass=$CLASS
Terminal=false
Categories=Network;WebBrowser;
EOF
echo "  ok: $NAME ($ID) -> $URL in $BROWSER"
[ "$NOPIN" = "--no-pin" ] || { pin "$ID" && echo "  pinned to the dock"; }
