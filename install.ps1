# OpenCode TPS Meter Windows Installer
# Requires: git, curl, bun (in PATH or at %USERPROFILE%\.bun\bin\bun.exe)

param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

$REPO_RAW_BASE = "https://raw.githubusercontent.com/guard22/opencode-tps-meter/main"
$UPSTREAM_REPO = "https://github.com/anomalyco/opencode.git"
$INSTALL_ROOT = Join-Path $env:LOCALAPPDATA "opencode-tps-meter"
$RELEASES_DIR = Join-Path $INSTALL_ROOT "releases"
$CURRENT_LINK = Join-Path $INSTALL_ROOT "current"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$MANIFEST_LOCAL = Join-Path $SCRIPT_DIR "manifest.sh"
$MANIFEST_DOWNLOADED = Join-Path $INSTALL_ROOT "manifest.sh"

function Write-Status($msg) {
    Write-Host "[opencode-tps-meter] $msg" -ForegroundColor Cyan
}

function Write-Err($msg) {
    Write-Host "[opencode-tps-meter] ERROR: $msg" -ForegroundColor Red
    exit 1
}

function Test-Command($cmd) {
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Get-BunPath {
    $bunCmd = Get-Command bun -ErrorAction SilentlyContinue
    if ($bunCmd) {
        return $bunCmd.Source
    }
    $defaultBun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path $defaultBun) {
        return $defaultBun
    }
    return $null
}

function Load-Manifest {
    if (Test-Path $MANIFEST_LOCAL) {
        $content = Get-Content $MANIFEST_LOCAL -Raw
        if ($content -match 'LATEST_SUPPORTED="([^"]+)"') {
            $script:LATEST_SUPPORTED = $matches[1]
        }
        return
    }
    $manifestDir = Split-Path -Parent $MANIFEST_DOWNLOADED
    if (-not (Test-Path $manifestDir)) {
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
    }
    Write-Status "Downloading manifest..."
    curl.exe -fsSL "$REPO_RAW_BASE/manifest.sh" -o $MANIFEST_DOWNLOADED
    $content = Get-Content $MANIFEST_DOWNLOADED -Raw
    if ($content -match 'LATEST_SUPPORTED="([^"]+)"') {
        $script:LATEST_SUPPORTED = $matches[1]
    }
}

function Get-UpstreamTag($version) {
    switch ($version) {
        "1.3.14" { return "v1.3.14" }
        "1.3.13" { return "v1.3.13" }
        default { return $null }
    }
}

function Get-PatchPath($version) {
    return "patches/opencode-$version-tps.patch"
}

function Test-SupportedVersion($version) {
    return $null -ne (Get-UpstreamTag $version)
}

function Get-DetectedVersion {
    $stockPath = Join-Path $env:USERPROFILE ".local\bin\opencode-stock"
    if (Test-Path $stockPath) {
        $ver = & $stockPath --version 2>$null
        if ($ver) { return ($ver -split ' ')[0] }
    }
    $opencodeCmd = Get-Command opencode -ErrorAction SilentlyContinue
    if ($opencodeCmd) {
        $ver = & $opencodeCmd.Source --version 2>$null
        if ($ver) { return ($ver -split ' ')[0] }
    }
    return $null
}

Write-Status "OpenCode TPS Meter Installer (Windows)"
Write-Status "========================================"

Write-Status "Checking requirements..."
if (-not (Test-Command git)) {
    Write-Err "git is required but not found. Install Git for Windows."
}
if (-not (Test-Command curl)) {
    Write-Err "curl is required but not found."
}

$BUN_BIN = Get-BunPath
if (-not $BUN_BIN) {
    Write-Err "bun is required but not found. Install bun: https://bun.sh"
}
Write-Status "Using bun: $BUN_BIN"

Load-Manifest
Write-Status "Latest supported version: $LATEST_SUPPORTED"

$DETECTED_VERSION = Get-DetectedVersion
if ($Version) {
    $REQUESTED_VERSION = $Version
} elseif ($DETECTED_VERSION -and (Test-SupportedVersion $DETECTED_VERSION)) {
    $REQUESTED_VERSION = $DETECTED_VERSION
    Write-Status "Detected OpenCode version: $DETECTED_VERSION"
} else {
    $REQUESTED_VERSION = $LATEST_SUPPORTED
    if ($DETECTED_VERSION) {
        Write-Status "Detected version ($DETECTED_VERSION) not supported, using latest: $LATEST_SUPPORTED"
    }
}

if (-not (Test-SupportedVersion $REQUESTED_VERSION)) {
    Write-Err "Unsupported version: $REQUESTED_VERSION. Supported: 1.3.14, 1.3.13"
}

$UPSTREAM_TAG = Get-UpstreamTag $REQUESTED_VERSION
$PATCH_RELATIVE = Get-PatchPath $REQUESTED_VERSION
$PATCH_URL = "$REPO_RAW_BASE/$PATCH_RELATIVE"
$PATCH_LOCAL = Join-Path $SCRIPT_DIR $PATCH_RELATIVE
$RELEASE_DIR = Join-Path $RELEASES_DIR $REQUESTED_VERSION
$PATCH_FILE = Join-Path $INSTALL_ROOT "opencode-$REQUESTED_VERSION.patch"

Write-Status "Installing OpenCode $REQUESTED_VERSION with TPS meter..."

if (-not (Test-Path $INSTALL_ROOT)) {
    New-Item -ItemType Directory -Path $INSTALL_ROOT -Force | Out-Null
}
if (-not (Test-Path $RELEASES_DIR)) {
    New-Item -ItemType Directory -Path $RELEASES_DIR -Force | Out-Null
}

if (Test-Path $PATCH_LOCAL) {
    Write-Status "Using local patch: $PATCH_LOCAL"
    Copy-Item $PATCH_LOCAL $PATCH_FILE -Force
} else {
    Write-Status "Downloading patch..."
    curl.exe -fsSL $PATCH_URL -o $PATCH_FILE
}

$TEMP_DIR = Join-Path $INSTALL_ROOT ".install.tmp"
$TEMP_SRC = Join-Path $TEMP_DIR "opencode-src"

if (Test-Path $TEMP_DIR) {
    Remove-Item -Recurse -Force $TEMP_DIR
}

Write-Status "Cloning OpenCode $UPSTREAM_TAG..."
git clone --depth 1 --branch $UPSTREAM_TAG $UPSTREAM_REPO $TEMP_SRC

Write-Status "Applying patch..."
$patchResult = git -C $TEMP_SRC apply --check $PATCH_FILE 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Patch does not apply cleanly to $UPSTREAM_TAG. This version is not safe to install."
}

git -C $TEMP_SRC apply $PATCH_FILE

Write-Status "Installing dependencies with bun..."
$bunInstallResult = & $BUN_BIN install --cwd $TEMP_SRC 2>&1
$bunInstallFailed = $LASTEXITCODE -ne 0
if ($bunInstallFailed) {
    Write-Status "Warning: bun install had issues (non-fatal on Windows)"
    Write-Status $bunInstallResult
}

if (Test-Path $RELEASE_DIR) {
    Remove-Item -Recurse -Force $RELEASE_DIR
}
Move-Item $TEMP_SRC $RELEASE_DIR

if (Test-Path $CURRENT_LINK) {
    cmd /c "rmdir `"$CURRENT_LINK`" 2>nul"
}
cmd /c "mklink /J `"$CURRENT_LINK`" `"$RELEASE_DIR`" 2>nul" | Out-Null

$BIN_DIR = Join-Path $env:LOCALAPPDATA "opencode-tps-meter\bin"
if (-not (Test-Path $BIN_DIR)) {
    New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null
}

$WRAPPER = Join-Path $BIN_DIR "opencode.cmd"
$STOCK = Join-Path $BIN_DIR "opencode-stock.cmd"

$existingOpencode = Get-Command opencode -ErrorAction SilentlyContinue
if ($existingOpencode -and -not (Test-Path $STOCK)) {
    $existingPath = $existingOpencode.Source
    Write-Status "Backing up existing opencode to stock..."
    $stockContent = "@echo off`n`"$existingPath`" %*`n"
    Set-Content -Path $STOCK -Value $stockContent -Encoding ASCII
}

$SOURCE_DIR = Join-Path $RELEASE_DIR "packages\opencode"
Write-Status "Creating wrapper: $WRAPPER"
$wrapperContent = "@echo off`nset `"OPENCODE_LAUNCH_CWD=%CD%`"`n`"$BUN_BIN`" --cwd `"$SOURCE_DIR`" --conditions=browser ./src/index.ts %*`n"
Set-Content -Path $WRAPPER -Value $wrapperContent -Encoding ASCII

$PATH_ADD = $BIN_DIR
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$PATH_ADD*") {
    Write-Status "Adding $BIN_DIR to PATH..."
    [Environment]::SetEnvironmentVariable("PATH", "$PATH_ADD;$userPath", "User")
    $env:PATH = "$PATH_ADD;$userPath"
}

Write-Status ""
Write-Status "========================================"
Write-Status "Installed OpenCode TPS Meter for OpenCode $REQUESTED_VERSION"
Write-Status ""
Write-Status "Run: opencode"
Write-Status "Fallback: opencode-stock"
Write-Status ""
Write-Status "NOTE: You may need to restart your terminal for 'opencode' to work."
