#!/usr/bin/env bash
# Build "Unconscious Abundance Reveal.app" for macOS 14+ on Apple Silicon, signed locally (no Apple Developer account).
#   ./build.sh            -> app/build/Unconscious Abundance Reveal.app
#   ./build.sh --open     -> build, then launch it
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Unconscious Abundance Reveal.app"
swift build -c release --arch arm64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/UnconsciousReveal "$APP/Contents/MacOS/UnconsciousReveal"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/donate.html "$APP/Contents/Resources/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"   # redraw with: swift make_icon.swift

# Signature, with the sandbox entitlements: the app gets the microphone and files you choose, and no network.
# With a self-signed "Unconscious Reveal Dev" code-signing certificate in your Keychain, every build carries
# the same identity, so firewalls like Little Snitch (and macOS) recognise rebuilds as the same app. Without
# it, an ad-hoc signature is used, which changes on every build, and macOS asks again for the microphone
# after each build.
SIGN_ID="${SIGN_ID:-Unconscious Reveal Dev}"
ENTITLEMENTS=Resources/UnconsciousReveal.entitlements
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$SIGN_ID\""; then
  codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$SIGN_ID" "$APP"
  echo "Signed with: $SIGN_ID"
else
  codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign - "$APP"
  echo "Signed ad-hoc (create a \"$SIGN_ID\" code-signing certificate for a stable identity)"
fi

echo "Built: $(pwd)/$APP"
if [ "${1:-}" = "--open" ]; then open "$APP"; fi
