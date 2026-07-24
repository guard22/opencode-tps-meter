#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/opencode-tps-meter-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="$TMP_ROOT/home"
export XDG_DATA_HOME="$TMP_ROOT/data"
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$FAKE_BIN"

cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  ls-remote)
    printf 'deadbeef\trefs/tags/v1.18.4\n'
    ;;
  clone)
    target="${@: -1}"
    mkdir -p "$target/packages/opencode/src"
    printf 'export {}\n' > "$target/packages/opencode/src/index.ts"
    ;;
  *)
    echo "unexpected fake git command: $*" >&2
    exit 1
    ;;
esac
EOF

cat > "$FAKE_BIN/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -o)
      output="\$2"
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      url="\$1"
      shift
      ;;
  esac
done
case "\$url" in
  */manifest.sh)
    cp "$REPO_ROOT/manifest.sh" "\$output"
    ;;
  */apply-opencode-tps-patch.mjs)
    cp "$REPO_ROOT/scripts/apply-opencode-tps-patch.mjs" "\$output"
    ;;
  *)
    echo "unexpected fake curl URL: \$url" >&2
    exit 1
    ;;
esac
EOF

cat > "$FAKE_BIN/bun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "install" ]; then
  exit 0
fi
if [[ "${1:-}" == *apply-opencode-tps-patch.mjs ]]; then
  exit 0
fi
echo "unexpected fake bun command: $*" >&2
exit 1
EOF

cat > "$FAKE_BIN/opencode" <<'EOF'
#!/usr/bin/env bash
printf '1.18.4\n'
EOF

chmod +x "$FAKE_BIN/git" "$FAKE_BIN/curl" "$FAKE_BIN/bun" "$FAKE_BIN/opencode"
export PATH="$FAKE_BIN:$PATH"

bash -s < "$REPO_ROOT/install.sh"

test -x "$FAKE_BIN/opencode"
test -x "$FAKE_BIN/opencode-stock"
test -f "$XDG_DATA_HOME/opencode-tps-meter/launcher.env"
test -L "$XDG_DATA_HOME/opencode-tps-meter/current"
grep -q 'opencode-tps-meter/current/packages/opencode' "$FAKE_BIN/opencode"
grep -q "STOCK='$FAKE_BIN/opencode-stock'" "$XDG_DATA_HOME/opencode-tps-meter/launcher.env"

bash "$REPO_ROOT/uninstall.sh"

test -x "$FAKE_BIN/opencode"
test ! -e "$FAKE_BIN/opencode-stock"
test ! -e "$XDG_DATA_HOME/opencode-tps-meter"
test "$("$FAKE_BIN/opencode" --version)" = "1.18.4"

echo "installer lifecycle: OK"
