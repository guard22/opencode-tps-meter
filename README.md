# OpenCode TPS Meter

Adds live streaming and final output-token throughput to the OpenCode TUI
footer. The installer uses a fail-closed source patcher: if an upstream layout
is not recognized, it stops before replacing the user's launcher.

[![npm version](https://img.shields.io/npm/v/@guard22/opencode-tps-meter)](https://www.npmjs.com/package/@guard22/opencode-tps-meter)
[![license](https://img.shields.io/github/license/floze-the-genius/opencode-tps-meter)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/floze-the-genius/opencode-tps-meter)](https://github.com/floze-the-genius/opencode-tps-meter/stargazers)

## Why this exists

Coding-agent throughput is operational data: it helps distinguish model
latency, transport stalls, rendering delays, and regressions between releases.
OpenCode does not currently expose a normal plugin hook for its TUI footer, so
this project owns the compatibility work required to keep that signal visible.

It provides:

- live rolling TPS over the last 15 seconds while a response is streaming
- exact output TPS after the response completes
- compatibility validation against legacy and current OpenCode layouts
- launcher preservation and a clean uninstall path

## Demo

![OpenCode TPS Meter demo](assets/tps-meter-demo.gif)

Full video: [assets/tps-meter-demo.mp4](assets/tps-meter-demo.mp4)

This is a **TUI/CLI patch**, not a Desktop extension and not a normal OpenCode
plugin. It patches the exact requested OpenCode source release during install.

## Maintenance contract

- Current compatibility target: OpenCode `1.18.4`
- Tested releases are patch-applied and typechecked in the GitHub Actions matrix
- Split-TUI releases validate both `packages/opencode` and `packages/tui`
- Unknown source layouts fail before the launcher is replaced
- Security reports use [private vulnerability reporting](SECURITY.md)
- Contributions follow the focused compatibility workflow in
  [CONTRIBUTING.md](CONTRIBUTING.md)

Primary maintainer: [Floze](https://github.com/floze-the-genius)

## Install

Install the published package:

```bash
npx @guard22/opencode-tps-meter install
```

Install the latest repository version:

```bash
curl -fsSL https://raw.githubusercontent.com/floze-the-genius/opencode-tps-meter/main/install.sh | bash
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
- `1.18.4`

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

- OpenCode `1.18.4`
- OpenCode `1.14.20`
- OpenCode `1.4.1`
- OpenCode `1.4.0`
- OpenCode `1.3.17`
- OpenCode `1.3.16`
- OpenCode `1.3.15`
- OpenCode `1.3.14`
- OpenCode `1.3.13`
- Bun `1.3.13`
