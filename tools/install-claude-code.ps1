#Requires -Version 5.1
<#
.SYNOPSIS
    Install Claude Code on Windows so you can run it in VS's integrated
    terminal alongside the build.

.DESCRIPTION
    Installs Node.js LTS via winget if missing, then installs the Claude
    Code npm package globally. After it finishes, run `claude` in this
    same terminal to start a session.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tools\install-claude-code.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Step { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "    $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "    $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "!!! $m" -ForegroundColor Red }

function Test-Cmd { param([string]$Name) [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Update-PathFromMachine {
    # New installs (winget, msi) update the registry env but not the current
    # process. Pull both Machine and User PATH into the running shell so
    # npm/node become callable immediately.
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machine, $user, $env:Path -join ';')
}

Write-Step "Checking prerequisites"

# Node.js
if (Test-Cmd node) {
    $ver = (node --version).Trim()
    Write-Ok "Node.js found: $ver"
} else {
    Write-Warn2 "Node.js not found. Installing via winget..."
    if (-not (Test-Cmd winget)) {
        Write-Err "winget not available. Install Node.js LTS manually from https://nodejs.org/ and rerun this script."
        exit 1
    }
    winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget failed installing Node.js (exit $LASTEXITCODE)" }
    Update-PathFromMachine
    if (-not (Test-Cmd node)) {
        Write-Err "Node.js installed but not on PATH yet. Close this terminal, open a new one, and rerun the script."
        exit 1
    }
    Write-Ok "Node.js installed: $((node --version).Trim())"
}

# npm
if (-not (Test-Cmd npm)) {
    Write-Err "npm not found even though Node.js is installed. Try restarting the terminal."
    exit 1
}

Write-Step "Installing Claude Code globally"
npm install -g @anthropic-ai/claude-code
if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }

Update-PathFromMachine

if (-not (Test-Cmd claude)) {
    Write-Warn2 "claude not on PATH in this terminal yet."
    Write-Warn2 "Close this terminal and open a fresh one, then run: claude"
    exit 0
}

Write-Ok "Installed: $((claude --version) 2>&1 | Select-Object -First 1)"

Write-Host ""
Write-Step "Done"
Write-Host "Start a session with:" -ForegroundColor Cyan
Write-Host "    claude" -ForegroundColor White
Write-Host ""
Write-Host "First launch will open a browser to sign in with your Anthropic account." -ForegroundColor DarkGray
