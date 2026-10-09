#!/usr/bin/env bash
#
# make-dmg.sh — Package an exported, notarized QRBar.app into a signed,
# notarized, stapled DMG.
#
# Usage:
#   scripts/make-dmg.sh [path/to/QRBar.app]
#
# Requirements:
#   - create-dmg            (brew install create-dmg)
#   - Developer ID Application certificate in your keychain
#   - notarytool credentials saved once with:
#       xcrun notarytool store-credentials "notary" \
#         --apple-id you@example.com --team-id TEAMID
#
# Optional environment variables:
#   SIGN_IDENTITY   codesign identity (default: "Developer ID Application")
#   NOTARY_PROFILE  notarytool keychain profile (default: "notary")
#   SKIP_NOTARIZE=1 build and sign only, skip notarization/stapling

set -euo pipefail

APP="${1:-QRBar.app}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"

if [[ ! -d "$APP" ]]; then
  echo "error: app not found at '$APP'" >&2
  exit 1
fi

command -v create-dmg >/dev/null || {
  echo "error: create-dmg not installed (brew install create-dmg)" >&2
  exit 1
}

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="QRBar-${VERSION}.dmg"

echo "==> Building $DMG from $APP"
rm -f "$DMG"
create-dmg --volname "QRBar" --window-size 500 300 \
  --icon "$(basename "$APP")" 125 100 --app-drop-link 375 100 \
  "$DMG" "$APP"

echo "==> Signing $DMG"
codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  echo "==> Skipping notarization (SKIP_NOTARIZE=1)"
  exit 0
fi

echo "==> Notarizing $DMG (this can take a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$DMG"

echo "==> Verifying"
spctl -a -t open --context context:primary-signature -v "$DMG"

echo "==> Done: $DMG"
