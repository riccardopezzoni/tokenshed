#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT_DIR/Resources/TokenShed-Info.plist"
ENTITLEMENTS="$ROOT_DIR/Resources/TokenShed.entitlements"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
APP_PATH="$ROOT_DIR/Build/Release/TokenShed.app"
DMG_PATH="$ROOT_DIR/Build/TokenShed-$VERSION.dmg"
ZIP_PATH="$ROOT_DIR/Build/TokenShed-$VERSION-macos.zip"
SIGN_IDENTITY="${TOKSHED_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${TOKSHED_NOTARY_PROFILE:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "Missing TOKSHED_SIGN_IDENTITY." >&2
  echo "Set it to your Developer ID Application identity, for example:" >&2
  echo "export TOKSHED_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'" >&2
  exit 64
fi

if ! security find-identity -v -p codesigning | grep -F "$SIGN_IDENTITY" >/dev/null; then
  echo "Code signing identity was not found in this keychain: $SIGN_IDENTITY" >&2
  echo "Available identities:" >&2
  security find-identity -v -p codesigning >&2
  exit 65
fi

"$ROOT_DIR/scripts/build-app.sh" release >/dev/null

codesign --force --timestamp --options runtime \
  --sign "$SIGN_IDENTITY" \
  "$APP_PATH/Contents/Resources/tokenshed"

codesign --force --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH" || true

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
"$ROOT_DIR/scripts/build-dmg.sh" "$APP_PATH" >/dev/null

codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
else
  echo "Skipping notarization because TOKSHED_NOTARY_PROFILE is not set." >&2
  echo "Create one with xcrun notarytool store-credentials, then rerun this script." >&2
fi

"$ROOT_DIR/scripts/build-cli-release.sh" >&2

echo "$DMG_PATH"
echo "$ZIP_PATH"
