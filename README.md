# OpenCode TPS Meter

Adds a live TPS meter to the OpenCode TUI footer.

It shows:
- live rolling TPS estimate over the last 15 seconds while a response is streaming
- exact output TPS for the last completed assistant response after completion

## Demo

![OpenCode TPS Meter demo](assets/tps-meter-demo.gif)

Full video: [assets/tps-meter-demo.mp4](assets/tps-meter-demo.mp4)

This patch targets `opencode 1.3.13` TUI/CLI, not Desktop.

## Install

One command:

```bash
curl -fsSL https://raw.githubusercontent.com/guard22/opencode-tps-meter/main/install.sh | bash
```

What it does:
- downloads OpenCode `v1.3.13` source into `~/.local/share/opencode-tps-meter/opencode-src`
- applies the TPS patch
- installs a wrapper at `~/.local/bin/opencode`
- keeps a fallback launcher as `~/.local/bin/opencode-stock`

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/guard22/opencode-tps-meter/main/uninstall.sh | bash
```

## Notes

- This is a TUI patch. It does not modify OpenCode Desktop.
- It preserves your current working directory when launching `opencode`.
- The live TPS is an estimate based on stream deltas. The final displayed TPS uses exact output-token usage from the completed assistant message.
- Requires `bun` and `git`.

## Tested

- OpenCode `1.3.13`
- Bun `1.3.5`
