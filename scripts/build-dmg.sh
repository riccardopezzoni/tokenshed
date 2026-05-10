#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT_DIR/Resources/TokenShed-Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
APP_PATH="${1:-$ROOT_DIR/Build/Release/TokenShed.app}"
DMG_PATH="$ROOT_DIR/Build/TokenShed-$VERSION.dmg"
STAGING_DIR="$ROOT_DIR/Build/DMG"
DMGMAKER_DIR="${DMGMAKER_DIR:-$ROOT_DIR/../DMGMaker}"
DMGMAKER_OUTPUT="$ROOT_DIR/Build/Release/TokenShed $VERSION.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  "$ROOT_DIR/scripts/build-app.sh" release >/dev/null
fi

if [[ -f "$DMGMAKER_DIR/Package.swift" ]]; then
  rm -f "$DMGMAKER_OUTPUT" "$DMG_PATH"
  swift run -c release --package-path "$DMGMAKER_DIR" "DMG Maker" \
    --app "$APP_PATH" \
    --name "TokenShed $VERSION" >&2
  cp "$DMGMAKER_OUTPUT" "$DMG_PATH"
  echo "$DMG_PATH"
  exit 0
fi

echo "DMGMaker checkout not found at $DMGMAKER_DIR; falling back to hdiutil." >&2

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/TokenShed.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "TokenShed $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
