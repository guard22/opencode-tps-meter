# OpenCode TPS Meter Windows Uninstaller

$ErrorActionPreference = "Stop"

$INSTALL_ROOT = Join-Path $env:LOCALAPPDATA "opencode-tps-meter"
$BIN_DIR = Join-Path $env:LOCALAPPDATA "opencode-tps-meter\bin"
$WRAPPER = Join-Path $BIN_DIR "opencode.cmd"
$STOCK = Join-Path $BIN_DIR "opencode-stock.cmd"

function Write-Status($msg) {
    Write-Host "[opencode-tps-meter] $msg" -ForegroundColor Cyan
}

Write-Status "Uninstalling OpenCode TPS Meter..."

if (Test-Path $BIN_DIR) {
    if (Test-Path $WRAPPER) {
        Remove-Item $WRAPPER -Force
    }
    if (Test-Path $STOCK) {
        Remove-Item $STOCK -Force
    }
    Remove-Item $BIN_DIR -Force
}

if (Test-Path $INSTALL_ROOT) {
    Write-Status "Removing installation directory..."
    Remove-Item -Recurse -Force $INSTALL_ROOT
}

$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -like "*$BIN_DIR*") {
    Write-Status "Removing $BIN_DIR from PATH..."
    $newUserPath = ($userPath -split ';' | Where-Object { $_ -ne $BIN_DIR }) -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
}

Write-Status "Removed OpenCode TPS Meter."
Write-Status "NOTE: You may need to restart your terminal for PATH changes to take effect."
