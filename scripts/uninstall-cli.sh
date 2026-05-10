#!/usr/bin/env bash
set -euo pipefail

INSTALL_PATH="$HOME/.local/bin/tokenshed"

if [[ ! -e "$INSTALL_PATH" ]]; then
  echo "tokenshed is not installed at $INSTALL_PATH"
  exit 0
fi

rm "$INSTALL_PATH"

echo "Removed $INSTALL_PATH"
