#!/usr/bin/env bash
# Builds the downloadable disk image. Nothing needs bundling: recording, reversing and speech recognition
# all come with macOS, so the app already works with no internet connection.
#   ./build.sh && ./make_offline_dmg.sh     -> build/Unconscious Abundance Reveal (offline).dmg
set -euo pipefail
cd "$(dirname "$0")"

NAME="Unconscious Abundance Reveal"
APP="build/$NAME.app"
[ -d "$APP" ] || { echo "Build the app first: ./build.sh"; exit 1; }
codesign --verify --strict "$APP"   # signed by build.sh, with the sandbox entitlements (no network)

# The disk image: the app, an Applications shortcut to drag it onto, and how to open it.
DMG="build/$NAME (offline).dmg"
STAGE="build/dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/How to open.txt" <<NOTE
$NAME

1. Drag "$NAME" onto the Applications folder.
2. Open it from Applications.

The first time, macOS may say it can't check the app for malicious software. That's because
this free app isn't registered with Apple. To open it anyway:

   System Settings > Privacy and Security > scroll down > "Open Anyway"

You only need to do this once.

Speech recognition uses the speech model built into macOS. If the app says it isn't installed,
turn on Dictation in System Settings > Keyboard and macOS downloads it (once).

Fully offline and private: the app has no network access at all (macOS's App Sandbox blocks it),
sends no telemetry, and your recordings never leave your Mac. They're deleted when the app quits
unless you choose to keep them in Settings.

Needs macOS 14 Sonoma or newer, on a Mac with Apple Silicon (M1 or later).
NOTE
hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" > /dev/null
rm -rf "$STAGE"
echo "Built: $(pwd)/$DMG ($(du -h "$DMG" | cut -f1))"
