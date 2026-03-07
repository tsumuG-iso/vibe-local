# uninstall.ps1
# vibe-localをアンインストールするスクリプト (PowerShell)
#
# 使い方:
#   .\uninstall.ps1
#   .\uninstall.ps1 -Yes
#
# 警告: このスクリプトはvibe-localのインストール済みファイルを削除します

param(
    [Alias("y")]
    [switch]$Yes
)

$ErrorActionPreference = "Continue"

$ConfigDir = Join-Path $env:USERPROFILE ".config\vibe-local"
$StateDir = Join-Path $env:LOCALAPPDATA "vibe-local"
$LibDir = Join-Path $env:USERPROFILE ".local\lib\vibe-local"
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$Targets = @(
    $ConfigDir,
    $StateDir,
    $LibDir,
    (Join-Path $BinDir "vibe-local.cmd"),
    (Join-Path $BinDir "vibe-local.ps1"),
    (Join-Path $BinDir "vibe-local-uninstall.cmd"),
    (Join-Path $BinDir "vibe-local-uninstall.ps1")
)

Write-Host ""
Write-Host "============================================"
Write-Host " Uninstall vibe-local"
Write-Host "============================================"
Write-Host ""
Write-Host "Targets:"
foreach ($path in $Targets) { Write-Host "  - $path" }
Write-Host ""

if (-not $Yes) {
    $Confirm = Read-Host "Continue? [y/N]"
    if ($Confirm -notmatch '^[yY]') {
        Write-Host "Canceled."
        exit 0
    }
}

$removed = 0
foreach ($path in $Targets) {
    if (Test-Path -LiteralPath $path) {
        try {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ $path"
            $removed++
        } catch {
            Write-Host "  ! Failed to remove: $path"
        }
    }
}

Write-Host ""
if ($removed -gt 0) {
    Write-Host "Uninstall complete."
} else {
    Write-Host "No installed files were found."
}
Write-Host "Note: LM Studio / Ollama are not removed."
