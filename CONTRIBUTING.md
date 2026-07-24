# Contributing

Contributions are welcome, especially compatibility fixes for new OpenCode
versions and improvements to installer reliability.

Before opening a pull request:

- open an issue for substantial behavior changes
- keep the change focused
- include the OpenCode version and operating system used for testing
- run `bash -n install.sh uninstall.sh manifest.sh`
- run `npm run help`, `npm run pack:check`, and
  `bash ./tests/installer-smoke.sh`
- apply the patcher to the affected OpenCode release
- run `bun run typecheck` in every patched package (`packages/opencode` and,
  for split-TUI releases, `packages/tui`)
- verify install and uninstall behavior in a disposable environment

The installer must fail without replacing the user's launcher when an upstream
OpenCode source layout is not recognized.
