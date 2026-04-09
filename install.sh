#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/guard22/opencode-tps-meter/main"
UPSTREAM_REPO="https://github.com/anomalyco/opencode.git"
INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-tps-meter"
RELEASES_DIR="$INSTALL_ROOT/releases"
CURRENT_LINK="$INSTALL_ROOT/current"
BIN_DIR="$HOME/.local/bin"
WRAPPER="$BIN_DIR/opencode"
STOCK="$BIN_DIR/opencode-stock"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_LOCAL="$SCRIPT_DIR/manifest.sh"
MANIFEST_DOWNLOADED="$INSTALL_ROOT/manifest.sh"
PATCHER_LOCAL="$SCRIPT_DIR/scripts/apply-opencode-tps-patch.mjs"
PATCHER_DOWNLOADED="$INSTALL_ROOT/apply-opencode-tps-patch.mjs"
TMP_DIR=""

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

load_manifest() {
  if [ -f "$MANIFEST_LOCAL" ]; then
    # shellcheck disable=SC1090
    . "$MANIFEST_LOCAL"
    return
  fi

  mkdir -p "$INSTALL_ROOT"
  curl -fsSL "$REPO_RAW_BASE/manifest.sh" -o "$MANIFEST_DOWNLOADED"
  # shellcheck disable=SC1090
  . "$MANIFEST_DOWNLOADED"
}

load_patcher() {
  if [ -f "$PATCHER_LOCAL" ]; then
    printf '%s' "$PATCHER_LOCAL"
    return
  fi

  mkdir -p "$INSTALL_ROOT"
  curl -fsSL "$REPO_RAW_BASE/scripts/apply-opencode-tps-patch.mjs" -o "$PATCHER_DOWNLOADED"
  printf '%s' "$PATCHER_DOWNLOADED"
}

latest_upstream_tag() {
  git ls-remote --tags --refs "$UPSTREAM_REPO" 'v*' \
    | awk -F/ '{print $3}' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -n 1
}

need git
need curl
need bun

load_manifest
PATCHER_SCRIPT="$(load_patcher)"

detect_installed_version() {
  local candidate=""

  if [ -x "$STOCK" ]; then
    candidate="$("$STOCK" --version 2>/dev/null || true)"
  elif [ -n "${EXISTING_OPENCODE:-}" ] && [ "$EXISTING_OPENCODE" != "$WRAPPER" ]; then
    candidate="$("$EXISTING_OPENCODE" --version 2>/dev/null || true)"
  fi

  printf '%s' "${candidate%% *}"
}

EXISTING_OPENCODE="$(command -v opencode || true)"
BUN_BIN="$(command -v bun)"
DETECTED_VERSION="$(detect_installed_version)"

if [ -n "${OPENCODE_TPS_VERSION:-}" ]; then
  REQUESTED_VERSION="${OPENCODE_TPS_VERSION#v}"
elif [ -n "$DETECTED_VERSION" ] && is_semver_version "$DETECTED_VERSION"; then
  REQUESTED_VERSION="$DETECTED_VERSION"
else
  REQUESTED_VERSION="$(latest_upstream_tag)"
  REQUESTED_VERSION="${REQUESTED_VERSION#v}"
fi

is_semver_version "$REQUESTED_VERSION" || fail \
  "Could not resolve a valid OpenCode version. Got '$REQUESTED_VERSION'."

UPSTREAM_TAG="$(resolve_upstream_tag "$REQUESTED_VERSION")"
RELEASE_DIR="$RELEASES_DIR/$REQUESTED_VERSION"

mkdir -p "$INSTALL_ROOT" "$RELEASES_DIR" "$BIN_DIR"
TMP_DIR="$(mktemp -d "$INSTALL_ROOT/.install.XXXXXX")"
TMP_SRC="$TMP_DIR/opencode-src"

git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" "$TMP_SRC"
"$BUN_BIN" "$PATCHER_SCRIPT" "$TMP_SRC" "$REQUESTED_VERSION" || fail \
  "Auto-patcher could not patch $UPSTREAM_TAG cleanly. This OpenCode release changed the TUI structure and needs a patcher update."
(cd "$TMP_SRC" && bun install --frozen-lockfile)

if [ -d "$RELEASE_DIR" ]; then
  rm -rf "$RELEASE_DIR"
fi
mv "$TMP_SRC" "$RELEASE_DIR"
ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"

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
SOURCE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-tps-meter/current/packages/opencode"
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

echo "Installed OpenCode TPS Meter for OpenCode $REQUESTED_VERSION."
if [ -n "$DETECTED_VERSION" ] && [ "$REQUESTED_VERSION" != "$DETECTED_VERSION" ]; then
  echo "Detected installed OpenCode version: $DETECTED_VERSION"
  echo "Using patched version instead: $REQUESTED_VERSION"
fi
if ! is_tested_version "$REQUESTED_VERSION"; then
  echo "Warning: $REQUESTED_VERSION is not in the tested list yet. The auto-patcher matched this release successfully, but it is still an unverified upstream version."
else
  echo "Tested upstream versions: $(print_tested_versions | paste -sd ',' - | sed 's/,/, /g')"
fi
echo "Run: opencode"
echo "Fallback: opencode-stock"
