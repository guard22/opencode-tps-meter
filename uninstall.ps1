# OpenCode TPS Meter Windows Uninstaller

$ErrorActionPreference = "Stop"

$INSTALL_ROOT = Join-Path $env:LOCALAPPDATA "opencode-tps-meter"
$BIN_DIR = Join-Path $INSTALL_ROOT "bin"
$WRAPPER = Join-Path $BIN_DIR "opencode.cmd"
$STOCK = Join-Path $BIN_DIR "opencode-stock.cmd"

function Write-Status($msg) {
    Write-Host "[opencode-tps-meter] $msg" -ForegroundColor Cyan
}

function Write-Err($msg) {
    Write-Host "[opencode-tps-meter] ERROR: $msg" -ForegroundColor Red
    exit 1
}

Write-Status "OpenCode TPS Meter Uninstaller (Windows)"
Write-Status "=========================================="

if (-not (Test-Path $INSTALL_ROOT)) {
    Write-Status "OpenCode TPS Meter is not installed."
    exit 0
}

Write-Status "Removing OpenCode TPS Meter from $INSTALL_ROOT..."

if (Test-Path $WRAPPER) {
    Remove-Item $WRAPPER -Force
}
if (Test-Path $STOCK) {
    Remove-Item $STOCK -Force
}

if (Test-Path $BIN_DIR) {
    Remove-Item $BIN_DIR -Recurse -Force
}

$PATH_ADD = $BIN_DIR
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -like "*$PATH_ADD*") {
    $newPath = ($userPath -split ';' | Where-Object { $_ -ne $PATH_ADD }) -join ';'
    Write-Status "Removing $BIN_DIR from PATH..."
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
}

Remove-Item -Recurse -Force $INSTALL_ROOT

Write-Status ""
Write-Status "OpenCode TPS Meter has been uninstalled."
Write-Status ""
Write-Status "Note: Your original opencode launcher has been preserved."
