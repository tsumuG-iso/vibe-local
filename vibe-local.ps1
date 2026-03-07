# vibe-local.ps1
# Windows launcher for vibe-local
# Uses vibe-coder.py directly — no proxy, no Node.js, no Claude Code needed
#
# NOTE: This project is NOT affiliated with, endorsed by, or associated with Anthropic.
#
# Usage:
#   vibe-local                       # Interactive mode
#   vibe-local -p "question"         # One-shot
#   vibe-local uninstall             # Uninstall
#   vibe-local --auto                # Auto-detect network
#   vibe-local --model qwen3:8b      # Manual model
#   vibe-local -y                    # Skip permission check
#   vibe-local -DebugMode             # Debug mode

# Manual parameter parsing to prevent PowerShell common parameter conflicts (e.g., -p vs -ProgressAction)
$Auto = $false
$Yes = $false
$DebugMode = $false
$UninstallMode = $false
$Model = ""
$Prompt = ""
$ExtraArgs = @()

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    if ($arg -match '^(?i)(-Auto|--auto|-a)$') { $Auto = $true }
    elseif ($arg -match '^(?i)(-y|-Yes|--yes)$') { $Yes = $true }
    elseif ($arg -match '^(?i)(uninstall|remove|--uninstall)$') { $UninstallMode = $true }
    elseif ($arg -match '^(?i)(-DebugMode|--debug|-d)$') { $DebugMode = $true }
    elseif ($arg -match '^(?i)(-Model|--model|-m)$') { 
        if ($i + 1 -lt $args.Count) { $Model = $args[$i+1]; $i++ }
    }
    elseif ($arg -match '^(?i)(-Prompt|--prompt|-p)$') {
        if ($i + 1 -lt $args.Count) { $Prompt = $args[$i+1]; $i++ }
    }
    else { $ExtraArgs += $arg }
}

$ErrorActionPreference = "Continue"
$Script:LauncherPath = $PSCommandPath

# --- UTF-8 encoding fix (PowerShell 文字化け対策) ---
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    $null = & cmd /c "chcp 65001 >nul 2>&1"
} catch {}

# --- Directory init ---
$StateDir = Join-Path $env:LOCALAPPDATA "vibe-local"
if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }

# --- Config loading ---
$ConfigDir = Join-Path $env:USERPROFILE ".config\vibe-local"
$ConfigFile = Join-Path $ConfigDir "config"
$LibDir = Join-Path $env:USERPROFILE ".local\lib\vibe-local"
$VibeCoderScript = Join-Path $LibDir "vibe-coder.py"

# Defaults
$CfgModel = ""
$SidecarModel = ""
$OllamaHost = "http://localhost:11434"
$LLMEngine = "lmstudio"
$LMStudioHost = "http://localhost:1234"
$VibeLocalDebug = 0

function Invoke-VibeLocalUninstall {
    param(
        [bool]$SkipConfirm = $false
    )

    $configDir = Join-Path $env:USERPROFILE ".config\vibe-local"
    $stateDir = Join-Path $env:LOCALAPPDATA "vibe-local"
    $libDir = Join-Path $env:USERPROFILE ".local\lib\vibe-local"
    $binDir = Join-Path $env:USERPROFILE ".local\bin"
    $targets = @(
        $configDir,
        $stateDir,
        $libDir,
        (Join-Path $binDir "vibe-local.cmd"),
        (Join-Path $binDir "vibe-local.ps1"),
        (Join-Path $binDir "vibe-local-uninstall.cmd"),
        (Join-Path $binDir "vibe-local-uninstall.ps1")
    )
    $selfPath = $Script:LauncherPath
    $deferredDelete = @()
    $removed = 0

    Write-Host ""
    Write-Host "============================================"
    Write-Host " Uninstall vibe-local"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "Targets:"
    foreach ($path in $targets) { Write-Host "  - $path" }
    Write-Host ""

    if (-not $SkipConfirm) {
        $confirm = Read-Host "Continue? [y/N]"
        if ($confirm -notmatch '^[yY]') {
            Write-Host "Canceled."
            return
        }
    }

    foreach ($path in $targets) {
        if (Test-Path -LiteralPath $path) {
            try {
                $leaf = Split-Path -Leaf $path
                if (($selfPath -and ($path -ieq $selfPath)) -or ($leaf -like "vibe-local*.cmd")) {
                    $deferredDelete += $path
                    continue
                }
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
                Write-Host "  ✓ $path"
                $removed++
            } catch {
                Write-Host "  ! Failed to remove: $path"
            }
        }
    }

    if ($deferredDelete.Count -gt 0) {
        $quoted = ($deferredDelete | ForEach-Object { "'$($_.Replace("'", "''"))'" }) -join ", "
        $cleanupScript = "Start-Sleep -Seconds 1; Remove-Item -LiteralPath @($quoted) -Force -ErrorAction SilentlyContinue"
        Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command", $cleanupScript
        ) | Out-Null
        Write-Host "  ✓ launcher cleanup scheduled"
    }

    Write-Host ""
    if ($removed -gt 0 -or $deferredDelete.Count -gt 0) {
        Write-Host "Uninstall complete."
    } else {
        Write-Host "No installed files were found."
    }
    Write-Host "Note: LM Studio is not removed."
}

# Parse config file (safe grep-style, no dot-sourcing)
if (Test-Path $ConfigFile) {
    $configLines = Get-Content $ConfigFile -ErrorAction SilentlyContinue
    foreach ($line in $configLines) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*MODEL\s*=\s*"?([^"]*)"?\s*$') { $CfgModel = $Matches[1].Trim() }
        if ($line -match '^\s*SIDECAR_MODEL\s*=\s*"?([^"]*)"?\s*$') { $SidecarModel = $Matches[1].Trim() }
        if ($line -match '^\s*LLM_ENGINE\s*=\s*"?([^"]*)"?\s*$') { $LLMEngine = $Matches[1].Trim() }
        if ($line -match '^\s*OLLAMA_HOST\s*=\s*"?([^"]*)"?\s*$') { $OllamaHost = $Matches[1].Trim() }
        if ($line -match '^\s*LMSTUDIO_HOST\s*=\s*"?([^"]*)"?\s*$') { $LMStudioHost = $Matches[1].Trim() }
        if ($line -match '^\s*LLM_HOST\s*=\s*"?([^"]*)"?\s*$') {
            if ($LLMEngine -eq "lmstudio") {
                $LMStudioHost = $Matches[1].Trim()
            } else {
                $OllamaHost = $Matches[1].Trim()
            }
        }
        if ($line -match '^\s*VIBE_LOCAL_DEBUG\s*=\s*"?([01])"?\s*$') { $VibeLocalDebug = [int]$Matches[1] }
    }
}

if ($UninstallMode) {
    Invoke-VibeLocalUninstall -SkipConfirm:$Yes
    exit 0
}

# Command line overrides
if ($Model) { $CfgModel = $Model }
if ($DebugMode) { $VibeLocalDebug = 1 }

# [SEC] Validate LLM engine host - only allow localhost (SSRF prevention)
if ($LLMEngine -eq "lmstudio") {
    $ollamaUri = [System.Uri]::new($LMStudioHost)
    if ($ollamaUri.Host -notin @("localhost", "127.0.0.1", "::1", "[::1]")) {
        Write-Host "Warning: LMSTUDIO_HOST '$($ollamaUri.Host)' is not localhost. Resetting to localhost for security." -ForegroundColor Yellow
        $LMStudioHost = "http://localhost:1234"
    }
} else {
    $ollamaUri = [System.Uri]::new($OllamaHost)
    if ($ollamaUri.Host -notin @("localhost", "127.0.0.1", "::1", "[::1]")) {
        Write-Host "Warning: OLLAMA_HOST '$($ollamaUri.Host)' is not localhost. Resetting to localhost for security." -ForegroundColor Yellow
        $OllamaHost = "http://localhost:11434"
    }
}

# --- Find vibe-coder.py ---
if (-not (Test-Path $VibeCoderScript)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $DevScript = Join-Path $ScriptDir "vibe-coder.py"
    if (Test-Path $DevScript) {
        $VibeCoderScript = $DevScript
    } else {
        Write-Host "Error: vibe-coder.py not found" -ForegroundColor Red
        Write-Host "  Run install.ps1 or place vibe-coder.py in the same directory"
        exit 1
    }
}

# --- Find Python command ---
function Find-Python {
    try {
        $ver = & py -3 --version 2>&1
        if ($LASTEXITCODE -eq 0 -and "$ver" -match "Python 3") { return "py -3" }
    } catch {}
    try {
        $ver = & python3 --version 2>&1
        if ($LASTEXITCODE -eq 0 -and "$ver" -match "Python 3") { return "python3" }
    } catch {}
    try {
        $ver = & python --version 2>&1
        if ($LASTEXITCODE -eq 0 -and "$ver" -match "Python 3") { return "python" }
    } catch {}
    return $null
}

$PythonCmd = Find-Python
if (-not $PythonCmd) {
    Write-Host "Error: Python not found. Install Python 3: winget install Python.Python.3.12" -ForegroundColor Red
    exit 1
}

# --- Ensure LM Studio is running ---
function Test-LMStudioRunning {
    try {
        $resp = Invoke-WebRequest -Uri "$LMStudioHost/v1/models" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        return ($resp.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Ensure-LMStudio {
    if (-not (Test-LMStudioRunning)) {
        Write-Host "Error: LM Studio is not running." -ForegroundColor Red
        Write-Host ""
        Write-Host "対処法:" -ForegroundColor Yellow
        Write-Host "  1. LM Studioを起動してください"
        Write-Host "  2. Settings → API Server を有効にしてください"
        Write-Host "  3. Portが $LMStudioHost であることを確認してください"
        return $false
    }
    return $true
}

# --- Network check ---
function Test-Network {
    try {
        $null = Invoke-RestMethod -Uri "https://api.anthropic.com/" -TimeoutSec 3 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# --- Auto mode ---
if ($Auto) {
    if (Test-Network) {
        $hasClaude = Get-Command claude -ErrorAction SilentlyContinue
        if ($hasClaude) {
            Write-Host "Network available + Claude Code found -> launching Claude Code" -ForegroundColor Cyan
            claude @ExtraArgs
            exit $LASTEXITCODE
        }
        Write-Host "Network available (no Claude Code) -> local mode" -ForegroundColor Yellow
    } else {
        Write-Host "No network -> local mode" -ForegroundColor Yellow
    }
}

# --- Local mode startup ---
try {
    if (-not (Ensure-LMStudio)) {
        exit 1
    }

    # --- Permission check ---
    $PermArgs = @()

    if ($Yes) {
        $PermArgs += "-y"
    } else {
        Write-Host ""
        Write-Host "============================================"
        Write-Host " Warning: Permission Check" -ForegroundColor Yellow
        Write-Host "============================================"
        Write-Host ""
        Write-Host " vibe-local can run in auto-approve mode (-y)."
        Write-Host ""
        Write-Host " This means the AI can execute commands, read/write"
        Write-Host " files, and modify your system WITHOUT asking."
        Write-Host ""
        Write-Host " Local LLMs are less accurate than cloud AI."
        Write-Host " Unintended actions may occur."
        Write-Host ""
        Write-Host "--------------------------------------------"
        Write-Host " [y] Auto-approve mode"
        Write-Host " [N] Normal mode (ask before each tool use)"
        Write-Host "--------------------------------------------"
        Write-Host ""
        $reply = Read-Host " Continue? [y/N]"

        if ($reply -match '^[yY]') {
            $PermArgs += "-y"
            Write-Host " -> Auto-approve mode" -ForegroundColor Yellow
        } else {
            Write-Host " -> Normal mode (ask each time)" -ForegroundColor Green
        }
    }

    $DebugArgs = @()
    if ($VibeLocalDebug -eq 1) { $DebugArgs += "--debug" }

    $ModelArgs = @()
    if ($CfgModel) { $ModelArgs += @("--model", $CfgModel) }

    Write-Host ""
    Write-Host "============================================"
    Write-Host " vibe-local (vibe-coder)"
    if ($CfgModel) {
        Write-Host " Model: $CfgModel"
    } else {
        Write-Host " Model: (auto-detect)"
    }
    if ($LLMEngine -eq "lmstudio") {
        Write-Host " Engine: LM Studio ($LMStudioHost)"
    } else {
        Write-Host " Engine: Ollama ($OllamaHost)"
    }
    Write-Host "============================================"
    Write-Host ""
    $env:VIBE_LOCAL_ENGINE = $LLMEngine
    $env:VIBE_LOCAL_MODEL = $CfgModel
    $env:VIBE_LOCAL_SIDECAR_MODEL = if ($SidecarModel) { $SidecarModel } else { "" }
    $env:VIBE_LOCAL_DEBUG = "$VibeLocalDebug"
    if ($LLMEngine -eq "lmstudio") {
        $env:LLM_HOST = $LMStudioHost
    } else {
        $env:OLLAMA_HOST = $OllamaHost
    }
    $env:PYTHONIOENCODING = "utf-8"
    $env:PYTHONUTF8 = "1"

    $PromptArgs = @()
    if ($Prompt) { $PromptArgs += @("-p", $Prompt) }

    $allArgs = $ModelArgs + $PermArgs + $DebugArgs + $PromptArgs + $ExtraArgs

    $pyParts = $PythonCmd -split ' '
    if ($pyParts.Count -eq 2) {
        & $pyParts[0] $pyParts[1] "$VibeCoderScript" @allArgs
    } else {
        & $pyParts[0] "$VibeCoderScript" @allArgs
    }
}
finally {
    # [SEC] Clean up environment variables set during this session
    Remove-Item Env:OLLAMA_HOST -ErrorAction SilentlyContinue
    Remove-Item Env:LLM_HOST -ErrorAction SilentlyContinue
    Remove-Item Env:VIBE_LOCAL_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:VIBE_LOCAL_SIDECAR_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:VIBE_LOCAL_DEBUG -ErrorAction SilentlyContinue
    Remove-Item Env:PYTHONIOENCODING -ErrorAction SilentlyContinue
    Remove-Item Env:PYTHONUTF8 -ErrorAction SilentlyContinue
}
