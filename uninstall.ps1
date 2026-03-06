# uninstall.ps1
# vibe-localをアンインストールするスクリプト (PowerShell)
#
# 使い方:
#   .\uninstall.ps1
#
# 警告: このスクリプトはvibe-localのファイルを削除します

$ErrorActionPreference = "Stop"

# Colors
$RED = "`e[38;5;196m"
$GREEN = "`e[38;5;46m"
$YELLOW = "`e[38;5;226m"
$CYAN = "`e[38;5;51m"
$NC = "`e[0m"

# Directories to remove (installed by install.ps1)
$ConfigDir = "$env:LOCALAPPDATA\vibe-local"
$StateDir = "$env:LOCALAPPDATA\vibe-local"
$LibDir = "$env:LOCALAPPDATA\vibe-local"
$BinDir = "$env:USERPROFILE\.local\bin"

# Current directory (for clone directory removal)
$CurrentDir = Get-Location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "============================================"
Write-Host " 🗑️  vibe-local アンインストール"
Write-Host "============================================"
Write-Host ""
Write-Host "${YELLOW}⚠️  以下のファイルが削除されます:${NC}"
Write-Host "  - $ConfigDir"
Write-Host "  - $StateDir"
Write-Host "  - $LibDir"
Write-Host "  - $BinDir\vibe-local.cmd"
Write-Host "  - $BinDir\vibe-local.ps1"

# Check if current directory is a vibe-local clone
if ($null -ne $ScriptDir -and (Test-Path "$ScriptDir\.git")) {
    if ($CurrentDir.Path -eq $ScriptDir -or $CurrentDir.Path.StartsWith($ScriptDir.Path + [IO.Path]::DirectorySeparatorChar)) {
        Write-Host "  - $ScriptDir (クローンディレクトリ)"
    }
}
Write-Host ""

$Confirm = Read-Host "本当に削除しますか？ [y/N]"
Write-Host ""

if ($Confirm -ne "y" -and $Confirm -ne "Y") {
    Write-Host "${YELLOW}キャンセルしました${NC}"
    exit 0
}

Write-Host "${CYAN}削除中...${NC}"

# Remove config
if (Test-Path $ConfigDir) {
    Remove-Item -Path $ConfigDir -Recurse -Force
    Write-Host "  ✓ $ConfigDir"
}

# Remove state
if (Test-Path $StateDir) {
    Remove-Item -Path $StateDir -Recurse -Force
    Write-Host "  ✓ $StateDir"
}

# Remove lib
if (Test-Path $LibDir) {
    Remove-Item -Path $LibDir -Recurse -Force
    Write-Host "  ✓ $LibDir"
}

# Remove binaries
foreach ($BinFile in @("$BinDir\vibe-local.cmd", "$BinDir\vibe-local.ps1")) {
    if (Test-Path $BinFile) {
        Remove-Item -Path $BinFile -Force
        Write-Host "  ✓ $BinFile"
    }
}

# Remove clone directory if script is run from within it
if ($null -ne $ScriptDir -and (Test-Path "$ScriptDir\.git")) {
    if ($CurrentDir.Path -eq $ScriptDir -or $CurrentDir.Path.StartsWith($ScriptDir.Path + [IO.Path]::DirectorySeparatorChar)) {
        Write-Host "${CYAN}クローンディレクトリを検出しました${NC}"
        # Move up one directory first
        $ParentDir = Split-Path -Parent $ScriptDir
        Set-Location $ParentDir -ErrorAction SilentlyContinue
        Remove-Item -Path $ScriptDir -Recurse -Force
        Write-Host "  ✓ $ScriptDir"
    }
}

Write-Host ""
Write-Host "${GREEN}✅ アンインストール完了${NC}"
Write-Host ""
Write-Host "注: LM Studioは削除されません。LM Studioを削除する場合は:"
Write-Host "  コントロールパネルからアンインストール"
