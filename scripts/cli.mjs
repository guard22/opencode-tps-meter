#!/usr/bin/env node

import { spawnSync } from "node:child_process"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const packageRoot = path.resolve(__dirname, "..")

const command = process.argv[2]
const extraArgs = process.argv.slice(3)

function runScript(scriptName) {
  const scriptPath = path.join(packageRoot, scriptName)
  const result = spawnSync("bash", [scriptPath, ...extraArgs], {
    stdio: "inherit",
    env: process.env,
  })

  if (result.error) {
    console.error(result.error.message)
    process.exit(1)
  }

  process.exit(result.status ?? 1)
}

function help() {
  console.log(`opencode-tps-meter

Commands:
  install     Patch and install OpenCode TPS Meter
  uninstall   Remove the patched OpenCode TPS Meter install
  help        Show this help

Examples:
  npx @guard22/opencode-tps-meter install
  npx @guard22/opencode-tps-meter uninstall
  OPENCODE_TPS_VERSION=1.4.1 npx @guard22/opencode-tps-meter install
`)
}

switch (command) {
  case "install":
    runScript("install.sh")
    break
  case "uninstall":
    runScript("uninstall.sh")
    break
  case "help":
  case "--help":
  case "-h":
  case undefined:
    help()
    break
  default:
    console.error(`Unknown command: ${command}`)
    help()
    process.exit(1)
}
