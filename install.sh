#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="https://github.com/anomalyco/opencode.git"
UPSTREAM_TAG="v1.3.13"
PATCH_URL="https://raw.githubusercontent.com/guard22/opencode-tps-meter/main/patches/opencode-1.3.13-tps.patch"
INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-tps-meter"
SRC_DIR="$INSTALL_ROOT/opencode-src"
PATCH_FILE="$INSTALL_ROOT/opencode-1.3.13-tps.patch"
BIN_DIR="$HOME/.local/bin"
WRAPPER="$BIN_DIR/opencode"
STOCK="$BIN_DIR/opencode-stock"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

need git
need curl
need bun

EXISTING_OPENCODE="$(command -v opencode || true)"
BUN_BIN="$(command -v bun)"

mkdir -p "$INSTALL_ROOT" "$BIN_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  rm -rf "$SRC_DIR"
  git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin "$UPSTREAM_TAG"
  git -C "$SRC_DIR" checkout -f "$UPSTREAM_TAG"
  git -C "$SRC_DIR" reset --hard
  git -C "$SRC_DIR" clean -fd
fi

curl -fsSL "$PATCH_URL" -o "$PATCH_FILE"

if ! grep -q "~\${liveTps()}" "$SRC_DIR/packages/opencode/src/cli/cmd/tui/component/prompt/index.tsx"; then
  git -C "$SRC_DIR" apply "$PATCH_FILE"
fi

if [ -e "$WRAPPER" ] && [ ! -e "$STOCK" ]; then
  cp "$WRAPPER" "$STOCK"
elif [ ! -e "$STOCK" ] && [ -n "$EXISTING_OPENCODE" ] && [ "$EXISTING_OPENCODE" != "$WRAPPER" ]; then
  cat > "$STOCK" <<'STOCKEOF'
#!/bin/zsh
exec "__EXISTING_OPENCODE__" "$@"
STOCKEOF
  perl -0pi -e 's|__EXISTING_OPENCODE__|'"$EXISTING_OPENCODE"'|g' "$STOCK"
  chmod +x "$STOCK"
fi

cat > "$WRAPPER" <<'WRAPEOF'
#!/bin/zsh
set -euo pipefail
SOURCE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-tps-meter/opencode-src/packages/opencode"
FALLBACK="$HOME/.local/bin/opencode-stock"
if [ ! -d "$SOURCE_DIR" ]; then
  if [ -x "$FALLBACK" ]; then
    exec "$FALLBACK" "$@"
  fi
  echo "opencode-tps-meter source install is missing: $SOURCE_DIR" >&2
  exit 1
fi
ORIG_PWD="${PWD:-$(pwd)}"
export OPENCODE_LAUNCH_CWD="$ORIG_PWD"
exec "__BUN_BIN__" --cwd "$SOURCE_DIR" --conditions=browser ./src/index.ts "$@"
WRAPEOF
perl -0pi -e 's|__BUN_BIN__|'"$BUN_BIN"'|g' "$WRAPPER"
chmod +x "$WRAPPER"

echo "Installed OpenCode TPS Meter."
echo "Run: opencode"
echo "Fallback: opencode-stock"
