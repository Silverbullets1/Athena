# install.ps1 — Athena Windows PowerShell installer
#
# Usage:
#   .\install.ps1 -HermesRoot $env:USERPROFILE\.hermes -Profile max-breaker [-Yes] [-Force]
#
# Mirrors scripts/install.sh semantics:
#   - Two-step confirmation for SOUL/MEMORY/USER wipe
#   - .pre-athena-<pid> backups next to each file
#   - Atomic write via Temp + Move-Item -Force
#   - SHA-256 receipt at <hermes_root>\.athena.receipt
#
# Exit codes match install.sh.

[CmdletBinding()]
param(
    [string]$HermesRoot = "$env:USERPROFILE\.hermes",
    [ValidateSet("max-breaker", "builder", "research", "creative")]
    [string]$Profile = "max-breaker",
    [switch]$Yes = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

# --- preflight ---
if (-not (Test-Path -LiteralPath $HermesRoot -PathType Container)) {
    Write-Error "Hermes root $HermesRoot does not exist. Run 'hermes init' first."
    exit 4
}

$SkillPath = Join-Path $HermesRoot "skills\athena\SKILL.md"
$ReceiptPath = Join-Path $HermesRoot ".athena.receipt"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$PackDir = Join-Path $RepoRoot "pack"

if ((Test-Path -LiteralPath $SkillPath) -and -not $Force) {
    Write-Error "$SkillPath already exists. Pass -Force to overwrite."
    exit 5
}

# --- two-step confirmation ---
$pid_local = $PID
$needConfirm = $false
foreach ($f in @("SOUL.md", "MEMORY.md", "USER.md")) {
    $p = Join-Path $HermesRoot $f
    if (Test-Path -LiteralPath $p) { $needConfirm = $true; break }
}

if ($needConfirm -and -not $Yes -and [Environment]::UserInteractive) {
    Write-Host "Athena will wipe the following files in $HermesRoot:"
    Write-Host "  - SOUL.md"
    Write-Host "  - MEMORY.md"
    Write-Host "  - USER.md"
    Write-Host "Pre-athena copies will be written next to each file (.pre-athena-$pid_local)."
    Write-Host "No off-disk backup is taken. Continue? [y/N]"
    $ans = Read-Host
    if ($ans -notin @("y", "Y", "yes", "Yes", "YES")) {
        Write-Host "aborted."
        exit 3
    }
}

# --- backup pass ---
foreach ($f in @("SOUL.md", "MEMORY.md", "USER.md")) {
    $p = Join-Path $HermesRoot $f
    if (Test-Path -LiteralPath $p) {
        Copy-Item -LiteralPath $p -Destination "$p.pre-athena-$pid_local"
    }
}

# --- ensure dirs ---
New-Item -ItemType Directory -Force -Path (Join-Path $HermesRoot "skills\athena") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $HermesRoot "scripts") | Out-Null

# --- atomic write helper ---
function Write-Atomic {
    param(
        [string]$Src,
        [string]$Dst,
        [int]$Mode = 0o644
    )
    $tmp = [System.IO.Path]::GetTempFileName()
    Copy-Item -LiteralPath $Src -Destination $tmp -Force
    Move-Item -LiteralPath $tmp -Destination $Dst -Force
}

# --- write templates ---
Write-Atomic -Src (Join-Path $RepoRoot "SKILL.md")         -Dst $SkillPath
Write-Atomic -Src (Join-Path $PackDir "SOUL.md.template")  -Dst (Join-Path $HermesRoot "SOUL.md")
Write-Atomic -Src (Join-Path $PackDir "MEMORY.md.template") -Dst (Join-Path $HermesRoot "MEMORY.md")
Write-Atomic -Src (Join-Path $PackDir "USER.md.template")  -Dst (Join-Path $HermesRoot "USER.md")

# --- write scripts ---
Write-Atomic -Src (Join-Path $RepoRoot "scripts\install.ps1")     -Dst (Join-Path $HermesRoot "scripts\athena-install.ps1")
Write-Atomic -Src (Join-Path $RepoRoot "scripts\install.sh")      -Dst (Join-Path $HermesRoot "scripts\athena-install.sh")
Write-Atomic -Src (Join-Path $RepoRoot "scripts\uninstall.sh")    -Dst (Join-Path $HermesRoot "scripts\athena-uninstall.sh")
Write-Atomic -Src (Join-Path $RepoRoot "scripts\verify.sh")       -Dst (Join-Path $HermesRoot "scripts\athena-verify.sh")
Write-Atomic -Src (Join-Path $RepoRoot "scripts\release.py")      -Dst (Join-Path $HermesRoot "scripts\athena-release.py")
Write-Atomic -Src (Join-Path $RepoRoot "scripts\build_dmg.sh")    -Dst (Join-Path $HermesRoot "scripts\build-dmg.sh")

# --- build receipt ---
$skillBytes = [System.IO.File]::ReadAllBytes($SkillPath)
$hasher = [System.Security.Cryptography.SHA256]::Create()
$skillHash = ($hasher.ComputeHash($skillBytes) | ForEach-Object { $_.ToString("X2") }) -join ""
$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$hasher.Dispose()

$receipt = @{
    version = "1.0.0"
    installed_at = $ts
    profile = $Profile
    receipt_sha256 = $skillHash
    files = @{
        "skills/athena/SKILL.md" = @{ sha256 = $skillHash; mode = "0644" }
        "SOUL.md"   = @{ mode = "0644" }
        "MEMORY.md" = @{ mode = "0644" }
        "USER.md"   = @{ mode = "0644" }
    }
    wiped = @(
        @{ path = "SOUL.md";   backup = "SOUL.md.pre-athena-$pid_local" }
        @{ path = "MEMORY.md"; backup = "MEMORY.md.pre-athena-$pid_local" }
        @{ path = "USER.md";   backup = "USER.md.pre-athena-$pid_local" }
    )
}

$tmpReceipt = [System.IO.Path]::GetTempFileName()
$receipt | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmpReceipt -Encoding utf8
Move-Item -LiteralPath $tmpReceipt -Destination $ReceiptPath -Force

# --- audit log entry ---
$auditEntry = "{`"ts`":`"$ts`",`"action`":`"install`",`"profile`":`"$Profile`",`"receipt_sha256`":`"$skillHash`",`"operator`":`"$env:USERNAME`"}"
Add-Content -LiteralPath (Join-Path $HermesRoot ".athena.audit.log") -Value $auditEntry

Write-Host "Athena installed successfully."
Write-Host "  Profile            : $Profile"
Write-Host "  Skill SHA          : $skillHash"
Write-Host "  Receipt            : $ReceiptPath"
Write-Host ""
Write-Host "Next: open Hermes and type 'athena'."

exit 0
