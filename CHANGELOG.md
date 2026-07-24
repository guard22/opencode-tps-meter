# Changelog

## 1.1.0 - 2026-07-24

- support the split TUI and core installation layout in OpenCode `1.18.4`
- typecheck both patched packages on split-TUI releases
- preserve launchers installed outside `~/.local/bin` (contributed by
  [@kbdevs](https://github.com/kbdevs))
- improve live TPS accounting for streamed visible output (contributed by
  [@kbdevs](https://github.com/kbdevs))
- pin CI to Bun `1.3.13` and validate the package and shell entrypoints

## 1.0.0 - 2026-04-09

- publish the npm CLI installer
- add content-based auto-patching for newer OpenCode releases
- preserve the original launcher and launch directory
