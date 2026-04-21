#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-tps-meter"
LAUNCHER_STATE="$INSTALL_ROOT/launcher.env"
BIN_DIR="$HOME/.local/bin"
WRAPPER="$BIN_DIR/opencode"
STOCK="$BIN_DIR/opencode-stock"

if [ -f "$LAUNCHER_STATE" ]; then
  # shellcheck disable=SC1090
  . "$LAUNCHER_STATE"
elif [ -e "$HOME/.opencode/bin/opencode-stock" ]; then
  BIN_DIR="$HOME/.opencode/bin"
  WRAPPER="$BIN_DIR/opencode"
  STOCK="$BIN_DIR/opencode-stock"
fi

if [ -e "$STOCK" ]; then
  mv "$STOCK" "$WRAPPER"
else
  rm -f "$WRAPPER"
fi

rm -rf "$INSTALL_ROOT"

echo "Removed OpenCode TPS Meter."
