# OpenCode TPS Meter

Adds a live TPS meter to the OpenCode TUI footer.

It shows:
- live rolling TPS over the last 15 seconds while a response is streaming
- exact output TPS after the response completes

## Demo

![OpenCode TPS Meter demo](assets/tps-meter-demo.gif)

Full video: [assets/tps-meter-demo.mp4](assets/tps-meter-demo.mp4)

This is a **TUI/CLI patch**, not a Desktop extension and not a normal OpenCode plugin. OpenCode does not expose a plugin hook for the TUI footer, so this project patches the OpenCode source during install.

## Install

Preferred npm install command:

```bash
npx @guard22/opencode-tps-meter install
```

Fallback raw installer:

```bash
curl -fsSL https://raw.githubusercontent.com/guard22/opencode-tps-meter/main/install.sh | bash
```

Default behavior:
- if `OPENCODE_TPS_VERSION` is set, install that exact OpenCode version
- else if your installed `opencode-stock` or non-wrapper `opencode` version is detectable, patch that version
- else fall back to the latest upstream stable OpenCode release

To force a specific version:

```bash
OPENCODE_TPS_VERSION=1.4.1 npx @guard22/opencode-tps-meter install
```

## How the installer works

- downloads the exact OpenCode tag for the requested version
- runs a content-based auto-patcher against the OpenCode source
- installs the patched source into `~/.local/share/opencode-tps-meter/releases/<version>`
- points `~/.local/share/opencode-tps-meter/current` at the active release
- installs a wrapper next to your detected `opencode` binary
- preserves your original launcher as `opencode-stock` in that same directory

If the requested OpenCode version changed the TUI structure too much, the installer exits without replacing your launcher.

## Compatibility

The installer now tries to patch **newer OpenCode releases automatically**. It is no longer hardcoded to a short manual allowlist.

Known tested versions are listed in [`manifest.sh`](manifest.sh).

Right now the tested set is:

- `1.3.13`
- `1.3.14`
- `1.3.15`
- `1.3.16`
- `1.3.17`
- `1.4.0`
- `1.4.1`
- `1.14.20`

If you install a newer OpenCode release and the source layout still matches the expected TUI anchors, the installer should work without needing a new repo release.

## Uninstall

```bash
npx @guard22/opencode-tps-meter uninstall
```

## Notes

- This patches **OpenCode TUI/CLI**, not Desktop.
- It preserves your launch directory, so `opencode` opens the project you launched it from.
- Live TPS is an estimate based on stream deltas.
- Final TPS uses exact **output-token** usage from the completed assistant message.
- Requires `bun`, `git`, and `curl`.
- If upstream rewrites the TUI footer structure, the auto-patcher will fail cleanly instead of half-installing.

## Tested

- OpenCode `1.4.1`
- OpenCode `1.4.0`
- OpenCode `1.14.20`
- OpenCode `1.3.17`
- OpenCode `1.3.16`
- OpenCode `1.3.15`
- OpenCode `1.3.14`
- OpenCode `1.3.13`
- Bun `1.3.5`
