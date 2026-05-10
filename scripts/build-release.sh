#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT_DIR/Resources/TokenShed-Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
APP_PATH="$("$ROOT_DIR/scripts/build-app.sh" release)"
ARCHIVE="$ROOT_DIR/Build/TokenShed-$VERSION-macos.zip"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE"
"$ROOT_DIR/scripts/build-cli-release.sh" >&2

echo "$ARCHIVE"
