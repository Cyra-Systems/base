#Requires -Version 5.1
<#
.SYNOPSIS
    One-shot local dev setup for Cyra on Windows.

.DESCRIPTION
    Pairs this repo with an existing upstream Red Eclipse install (Steam or
    standalone) so you can iterate on Cyra without downloading multi-GB
    assets from CI. Creates a junction from this repo's data/ to the
    upstream install's data/, then optionally builds the binary via
    Visual Studio.

    Per-change loop afterwards:
        git pull
        .\tools\setup-local-dev.ps1 -BuildOnly   # if C++ changed
        .\redeclipse.bat                          # run

.PARAMETER DataFrom
    Path to an existing Red Eclipse install (the folder containing data/,
    bin/, redeclipse.bat). If omitted, the script auto-detects from Steam.

.PARAMETER NoBuild
    Skip the Visual Studio build step. Useful if you only want to wire up
    the data junction.

.PARAMETER BuildOnly
    Skip junction setup, just build the binary. Use this in the per-change
    loop once the initial setup is done.

.PARAMETER Force
    Replace an existing data/ junction or directory if present.

.PARAMETER Configuration
    MSBuild configuration. Default: Release. Use Debug for a debuggable
    build (slower, larger binary).

.EXAMPLE
    .\tools\setup-local-dev.ps1
    Auto-detect Steam install, wire it up, build the binary.

.EXAMPLE
    .\tools\setup-local-dev.ps1 -DataFrom 'C:\Program Files\Red Eclipse'
    Use the official standalone installer's data instead of Steam.

.EXAMPLE
    .\tools\setup-local-dev.ps1 -BuildOnly
    Just rebuild after a C++ change.
#>
[CmdletBinding()]
param(
    [string]$DataFrom,
    [switch]$NoBuild,
    [switch]$BuildOnly,
    [switch]$Force,
    [ValidateSet('Release', 'Debug', 'SanitizeRelease')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

function Write-Step  { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "    $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "    $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "!!! $m" -ForegroundColor Red }

function Test-RedEclipseInstall {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    # An install is valid if it has data/ populated with a few known subdirs.
    $markers = @('data\appleflap', 'data\actors', 'data\sounds')
    foreach ($m in $markers) {
        if (-not (Test-Path (Join-Path $Path $m))) { return $false }
    }
    return $true
}

function Find-RedEclipseInstall {
    $candidates = New-Object System.Collections.Generic.List[string]

    # Steam library paths from libraryfolders.vdf
    $steamReg = 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam'
    foreach ($k in $steamReg) {
        $sp = (Get-ItemProperty -Path $k -Name InstallPath -ErrorAction SilentlyContinue).InstallPath
        if (-not $sp) { continue }
        $vdf = Join-Path $sp 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path $vdf)) { continue }
        Get-Content $vdf | Select-String -Pattern '"path"\s+"(.+?)"' | ForEach-Object {
            $libPath = $_.Matches[0].Groups[1].Value -replace '\\\\', '\'
            $candidates.Add((Join-Path $libPath 'steamapps\common\Red Eclipse'))
        }
    }

    # Standalone installer defaults
    $candidates.Add('C:\Program Files\Red Eclipse')
    $candidates.Add('C:\Program Files (x86)\Red Eclipse')
    $candidates.Add((Join-Path $env:LOCALAPPDATA 'Red Eclipse'))

    foreach ($c in $candidates) {
        if (Test-RedEclipseInstall $c) { return (Resolve-Path $c).Path }
    }
    return $null
}

function New-DataJunction {
    param([string]$SourceData)

    $target = Join-Path $RepoRoot 'data'

    # If git submodules are populated, the user already has data. Don't clobber.
    if ((Test-Path (Join-Path $target 'appleflap\.git')) -and -not $Force) {
        Write-Warn2 "data\ already populated by git submodules; skipping junction."
        Write-Warn2 "Pass -Force to replace with a junction to '$SourceData'."
        return
    }

    if (Test-Path $target) {
        $item = Get-Item $target -Force
        $isJunction = $item.Attributes -band [IO.FileAttributes]::ReparsePoint
        if ($isJunction) {
            if (-not $Force) {
                Write-Warn2 "data\ junction already exists -> $($item.Target)"
                Write-Warn2 "Pass -Force to re-point it."
                return
            }
            cmd /c rmdir "`"$target`"" | Out-Null
        } elseif ($Force) {
            Remove-Item $target -Recurse -Force
        } else {
            throw "data\ exists and is not a junction. Move/delete it or pass -Force."
        }
    }

    cmd /c mklink /J "`"$target`"" "`"$SourceData`"" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "mklink failed (exit $LASTEXITCODE)" }
    Write-Ok "Junctioned data\ -> $SourceData"
}

function Find-MSBuild {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) { return $null }
    $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild `
        -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
    if ($msbuild -and (Test-Path $msbuild)) { return $msbuild }
    return $null
}

function Invoke-VsBuild {
    $sln = Join-Path $RepoRoot 'src\vcpp\redeclipse.sln'
    if (-not (Test-Path $sln)) { throw "Solution not found: $sln" }

    $msbuild = Find-MSBuild
    if (-not $msbuild) {
        Write-Err "Visual Studio not found."
        Write-Host ""
        Write-Host "Install Visual Studio 2022 Community (free) with the"
        Write-Host "'Desktop development with C++' workload:"
        Write-Host "  https://visualstudio.microsoft.com/downloads/"
        Write-Host ""
        Write-Host "Or rerun with -NoBuild to skip the build step."
        throw "msbuild not available"
    }

    Write-Step "Building ($Configuration|x64) via $msbuild"
    & $msbuild $sln /nologo /m /p:Configuration=$Configuration /p:Platform=x64 /v:minimal
    if ($LASTEXITCODE -ne 0) { throw "Build failed (exit $LASTEXITCODE)" }

    $exe = Join-Path $RepoRoot 'bin\amd64\redeclipse.exe'
    if (-not (Test-Path $exe)) { throw "Build reported success but $exe is missing" }
    Write-Ok "Built bin\amd64\redeclipse.exe"
}

# --- main ---

if (-not $BuildOnly) {
    if (-not $DataFrom) {
        Write-Step "Looking for an existing Red Eclipse install"
        $DataFrom = Find-RedEclipseInstall
        if (-not $DataFrom) {
            Write-Err "No Red Eclipse install found."
            Write-Host ""
            Write-Host "Install Red Eclipse from one of:"
            Write-Host "  Steam:      steam://install/513710"
            Write-Host "  Standalone: https://www.redeclipse.net/download"
            Write-Host ""
            Write-Host "Then rerun this script (or pass -DataFrom <path>)."
            exit 1
        }
        Write-Ok "Found: $DataFrom"
    } elseif (-not (Test-RedEclipseInstall $DataFrom)) {
        throw "Not a valid Red Eclipse install: $DataFrom"
    }

    Write-Step "Wiring up data\ -> $DataFrom\data"
    New-DataJunction -SourceData (Join-Path $DataFrom 'data')
}

if (-not $NoBuild) {
    Invoke-VsBuild
}

Write-Host ""
Write-Step "Done"
Write-Host "Run the game with:" -ForegroundColor Cyan
Write-Host "    .\redeclipse.bat" -ForegroundColor White
Write-Host ""
Write-Host "Iteration loop after C++ changes:" -ForegroundColor Cyan
Write-Host "    .\tools\setup-local-dev.ps1 -BuildOnly" -ForegroundColor White
