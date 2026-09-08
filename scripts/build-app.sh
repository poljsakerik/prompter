#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/Prompter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Prompter" "$APP/Contents/MacOS/Prompter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Ad-hoc signing is sufficient for a locally built app. Distribution requires
# a Developer ID signature and notarization instead.
codesign --force --deep --sign - "$APP"
printf '\nBuilt %s\nLaunch with: open "%s"\n' "$APP" "$APP"
