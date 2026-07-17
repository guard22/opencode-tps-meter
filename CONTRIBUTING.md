# Contributing

Contributions are welcome, especially compatibility fixes for new OpenCode
versions and improvements to installer reliability.

Before opening a pull request:

- open an issue for substantial behavior changes
- keep the change focused
- include the OpenCode version and operating system used for testing
- run `npm run help` and `npm run pack:check`
- verify install and uninstall behavior in a disposable environment

The installer must fail without replacing the user's launcher when an upstream
OpenCode source layout is not recognized.
