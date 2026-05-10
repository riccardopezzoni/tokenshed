#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/Build/Release/TokenShed.app}"
CLI_SOURCE="$APP_PATH/Contents/Resources/tokenshed"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/tokenshed"

if [[ ! -x "$CLI_SOURCE" ]]; then
  echo "Missing bundled CLI: $CLI_SOURCE" >&2
  echo "Build a release app first with scripts/build-release.sh, or pass the path to TokenShed.app." >&2
  exit 66
fi

mkdir -p "$INSTALL_DIR"
cp "$CLI_SOURCE" "$INSTALL_PATH"
chmod 755 "$INSTALL_PATH"

echo "$INSTALL_PATH"
