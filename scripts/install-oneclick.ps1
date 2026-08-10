# install-oneclick.ps1 — Athena one-click Windows installer
#
# Usage:
#   irm https://raw.githubusercontent.com/xscope0/athena/main/scripts/install-oneclick.ps1 | iex
#
# Or locally:
#   .\scripts\install-oneclick.ps1
#   .\scripts\install-oneclick.ps1 -Profile builder
#   .\scripts\install-oneclick.ps1 -Force
#
# What it does:
#   1. Resolves repo root (auto-clones to $env:LOCALAPPDATA\athena if invoked via irm|iex)
#   2. Detects Python; tells the operator how to install if missing
#   3. pip installs requirements.txt
#   4. Calls scripts/install.ps1 with -Profile -Yes (and -Force if Athena already installed)
#
# Exit codes:
#   0  success
#   1  unhandled error
#   2  Python missing
#   3  user declined confirmation
#   4  prerequisite missing
#   5  install.ps1 ownership conflict (already installed, no -Force)
#   6  write failure

[CmdletBinding()]
param(
    [ValidateSet("max-breaker", "builder", "research", "creative")]
    [string]$Profile = "max-breaker",
    [switch]$Force = $false,
    [switch]$NoDeps = $false
)

$ErrorActionPreference = "Stop"

# --- banner ---
$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) {
    # Running via irm|iex — clone the repo to LOCALAPPDATA and use that as the script root
    $RepoRoot = Join-Path $env:LOCALAPPDATA "athena"
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot "SKILL.md"))) {
        Write-Host "Athena one-click installer — first run, cloning repository..."
        if (Test-Path -LiteralPath $RepoRoot) {
            Remove-Item -LiteralPath $RepoRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $RepoRoot | Out-Null
        $clone = Start-Process -FilePath "git" -ArgumentList @(
            "clone", "--depth=1",
            "https://github.com/xscope0/athena.git",
            $RepoRoot
        ) -NoNewWindow -Wait -PassThru
        if ($clone.ExitCode -ne 0) {
            Write-Error "git clone failed (exit $($clone.ExitCode)). Install git first: https://git-scm.com/download/win"
            exit 4
        }
    }
}

$BannersDir = Join-Path $RepoRoot "banners"
foreach ($name in @("athena", "nerv")) {
    $p = Join-Path $BannersDir "$name.ascii"
    if (Test-Path -LiteralPath $p) {
        try { Get-Content -LiteralPath $p -Raw } catch { }
    }
}

# --- python check ---
function Find-Python {
    $candidates = @("python", "python3", "py")
    foreach ($c in $candidates) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { return $c }
    }
    return $null
}

$python = Find-Python
if (-not $python) {
    Write-Error "Python not found on PATH. Install Python 3.10+ from https://python.org/downloads/ — tick 'Add Python to PATH' on the first screen."
    exit 2
}

# Confirm Python version
$versionOutput = & $python --version 2>&1
Write-Host "Using: $versionOutput"

# --- deps ---
if (-not $NoDeps) {
    $requirementsPath = Join-Path $RepoRoot "requirements.txt"
    if (Test-Path -LiteralPath $requirementsPath) {
        Write-Host "Installing Python dependencies (hermes-agent, PyQt6, pyinstaller)..."
        & $python -m pip install --quiet --disable-pip-version-check -r $requirementsPath
        if ($LASTEXITCODE -ne 0) {
            Write-Error "pip install failed (exit $LASTEXITCODE). Re-run with -NoDeps to skip, then debug manually."
            exit 6
        }
    }
}

# --- invoke install.ps1 with defaults ---
$installScript = Join-Path $RepoRoot "scripts\install.ps1"
if (-not (Test-Path -LiteralPath $installScript)) {
    Write-Error "install.ps1 not found at $installScript"
    exit 4
}

# Detect pre-existing install: add -Force if requested OR if SKILL.md is already there
$skillPath = Join-Path $env:USERPROFILE ".hermes\skills\athena\SKILL.md"
$needsForce = $Force -or (Test-Path -LiteralPath $skillPath)

$argList = @{
    Profile = $Profile
    Yes     = $true
}
if ($needsForce) { $argList.Force = $true }

Write-Host "Invoking install.ps1 with profile=$Profile$(if ($needsForce) { ' +force' })..."
& $installScript @argList
exit $LASTEXITCODE