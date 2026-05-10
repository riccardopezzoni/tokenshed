#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT_DIR/Resources/TokenShed-Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
ARCH="$(uname -m)"
STAGING_DIR="$ROOT_DIR/Build/CLI/tokenshed-$VERSION-macos-$ARCH"
ARCHIVE="$ROOT_DIR/Build/tokenshed-$VERSION-macos-$ARCH.tar.gz"
CHECKSUM="$ARCHIVE.sha256"

cd "$ROOT_DIR"

swift build -c release --product tokenshed >&2
BUILD_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp "$BUILD_DIR/tokenshed" "$STAGING_DIR/tokenshed"
chmod 755 "$STAGING_DIR/tokenshed"
touch -t 202605090000 "$STAGING_DIR/tokenshed"

tar -C "$STAGING_DIR" -cf - tokenshed | gzip -n > "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "$CHECKSUM"

echo "$ARCHIVE"
echo "$CHECKSUM"
