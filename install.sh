#!/bin/bash
# AppSweep installer — downloads the latest release and installs it into /Applications.
# Usage: curl -fsSL https://raw.githubusercontent.com/AliRazaviDeveloper/AppSweep/main/install.sh | bash
set -euo pipefail

APP_NAME="AppSweep"
DMG_URL="https://github.com/AliRazaviDeveloper/AppSweep/releases/latest/download/AppSweep.dmg"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "AppSweep currently supports macOS only. Windows and Linux versions are coming soon." >&2
  exit 1
fi

TMP=$(mktemp -d)
MOUNT=""
cleanup() {
  [[ -n "$MOUNT" ]] && hdiutil detach -quiet "$MOUNT" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

bold "▸ Downloading ${APP_NAME}…"
curl -fL --progress-bar -o "$TMP/$APP_NAME.dmg" "$DMG_URL"

bold "▸ Installing…"
MOUNT=$(hdiutil attach -nobrowse -readonly -mountrandom "$TMP" "$TMP/$APP_NAME.dmg" | tail -1 | awk -F'\t' '{print $NF}')

# Quit a running copy before replacing it.
osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true

DEST="/Applications"
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

rm -rf "$DEST/$APP_NAME.app"
cp -R "$MOUNT/$APP_NAME.app" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME.app" 2>/dev/null || true

bold "✓ ${APP_NAME} installed to ${DEST}"
open "$DEST/$APP_NAME.app"
