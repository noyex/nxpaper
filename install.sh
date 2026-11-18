#!/bin/bash
# Installs the latest nxpaper release into /Applications and launches it.
#   curl -fsSL https://raw.githubusercontent.com/noyex/nxpaper/main/install.sh | bash
set -euo pipefail

URL="${NXPAPER_URL:-https://github.com/noyex/nxpaper/releases/latest/download/nxpaper.zip}"

fail() { echo "nxpaper: $*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail "nxpaper is a macOS app."
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 14 )) || fail "nxpaper needs macOS 14 or later (this Mac runs $(sw_vers -productVersion))."

# /Applications when we can write to it, otherwise ~/Applications, no sudo needed.
DEST=/Applications
if [[ -e "$DEST/nxpaper.app" && ! -w "$DEST/nxpaper.app" ]] || [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading nxpaper…"
curl -fsSL "$URL" -o "$TMP/nxpaper.zip" || fail "download failed: $URL"
ditto -x -k "$TMP/nxpaper.zip" "$TMP"
[[ -d "$TMP/nxpaper.app" ]] || fail "the download doesn't contain nxpaper.app"

# Quit a running copy so it can be replaced.
if pgrep -x nxpaper >/dev/null; then
  osascript -e 'quit app "nxpaper"' 2>/dev/null || pkill -x nxpaper || true
  for _ in {1..30}; do pgrep -x nxpaper >/dev/null || break; sleep 0.1; done
fi

# An older build in the other folder would start at login and confuse Launch Services.
if [[ "$DEST" == /Applications ]]; then rm -rf "$HOME/Applications/nxpaper.app"; fi
rm -rf "$DEST/nxpaper.app"
ditto "$TMP/nxpaper.app" "$DEST/nxpaper.app"
# The app isn't notarized; downloaded with curl it has no quarantine flag, but clear it to be sure.
find "$DEST/nxpaper.app" -exec xattr -d com.apple.quarantine {} + &>/dev/null || true

open "$DEST/nxpaper.app"
echo "Installed $DEST/nxpaper.app. Look for the waves icon in the menu bar."
