#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "Usage: scripts/build-app.sh [debug|release]" >&2
  exit 64
fi

if [[ "$CONFIGURATION" == "release" ]]; then
  APP_DIR="$ROOT_DIR/Build/Release/TokenShed.app"
else
  APP_DIR="$ROOT_DIR/Build/TokenShed.app"
fi

CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION" --product TokenShedApp >&2
swift build -c "$CONFIGURATION" --product tokenshed >&2
BUILD_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/Resources/TokenShed-Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/TokenShedApp" "$MACOS_DIR/TokenShed"
cp "$BUILD_DIR/tokenshed" "$RESOURCES_DIR/tokenshed"
cp "$ROOT_DIR/Assets/TokenShed.icns" "$RESOURCES_DIR/TokenShed.icns"
cp "$ROOT_DIR/README.md" "$RESOURCES_DIR/README.md"
chmod 755 "$MACOS_DIR/TokenShed" "$RESOURCES_DIR/tokenshed"

echo "$APP_DIR"
