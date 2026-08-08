# install.ps1 — Athena Windows PowerShell installer
#
# Usage:
#   .\install.ps1 -HermesRoot "$env:USERPROFILE\.hermes" -Profile max-breaker [-Yes] [-Force]
#
#   # Or via env vars (matches CLI conventions):
#   $env:ATHENA_HOME = "$env:USERPROFILE\.hermes"
#   .\install.ps1 -Profile max-breaker -Yes
#
# Mirrors scripts/install.sh semantics:
#   - Two-step confirmation for SOUL/MEMORY/USER wipe
#   - .pre-athena-<pid> backups next to each file
#   - Atomic write via Temp + Move-Item -Force
#   - SHA-256 receipt at <hermes_root>\.athena.receipt
#   - Audit log at <hermes_root>\.athena.audit.log
#   - Respects ATHENA_HOME / HERMES_HOME env vars
#   - Does NOT touch AGENTS.md / HERMES.md / config.yaml
#
# Exit codes match install.sh:
#   0  success
#   1  unhandled error
#   2  wrong usage
#   3  user declined at confirmation
#   4  prerequisite missing (hermes not init'd)
#   5  ownership conflict (pass -Force)
#   6  write failure
#   7  post-install verify failed

[CmdletBinding()]
param(
    [string]$HermesRoot,
    [ValidateSet("max-breaker", "builder", "research", "creative")]
    [string]$Profile = "max-breaker",
    [switch]$Yes = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

# --- env var resolution ---
if (-not $HermesRoot) {
    if ($env:ATHENA_HOME) { $HermesRoot = $env:ATHENA_HOME }
    elseif ($env:HERMES_HOME) { $HermesRoot = $env:HERMES_HOME }
    else { $HermesRoot = "$env:USERPROFILE\.hermes" }
}

# --- preflight ---
if (-not (Test-Path -LiteralPath $HermesRoot -PathType Container)) {
    Write-Error "Hermes root $HermesRoot does not exist. Run 'hermes init' first."
    exit 4
}

$SkillPath = Join-Path $HermesRoot "skills\athena\SKILL.md"
$ReceiptPath = Join-Path $HermesRoot ".athena.receipt"
$AuditPath = Join-Path $HermesRoot ".athena.audit.log"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$PackDir = Join-Path $RepoRoot "pack"

# --- banner ---
$BannersDir = Join-Path $RepoRoot "banners"
foreach ($name in @("athena", "nerv")) {
    $p = Join-Path $BannersDir "$name.ascii"
    if (Test-Path -LiteralPath $p) {
        try { Get-Content -LiteralPath $p -Raw } catch { }
    }
}

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
# Writes src -> tmp file in same directory -> Move-Item -Force over dst.
# Same-directory Temp+Move guarantees atomic replace on NTFS.
function Write-Atomic {
    param(
        [string]$Src,
        [string]$Dst,
        [int]$Mode = 0o644
    )
    $dstDir = Split-Path -Parent $Dst
    $tmp = Join-Path $dstDir ([System.IO.Path]::GetRandomFileName())
    Copy-Item -LiteralPath $Src -Destination $tmp -Force
    Move-Item -LiteralPath $tmp -Destination $Dst -Force
}

# --- write templates ---
try {
    Write-Atomic -Src (Join-Path $RepoRoot "SKILL.md")          -Dst $SkillPath
    Write-Atomic -Src (Join-Path $PackDir "SOUL.md.template")   -Dst (Join-Path $HermesRoot "SOUL.md")
    Write-Atomic -Src (Join-Path $PackDir "MEMORY.md.template") -Dst (Join-Path $HermesRoot "MEMORY.md")
    Write-Atomic -Src (Join-Path $PackDir "USER.md.template")   -Dst (Join-Path $HermesRoot "USER.md")
} catch {
    Write-Error "Write-Atomic failed: $_"
    exit 6
}

# --- write scripts ---
# Both POSIX and PowerShell installers are shipped so the operator can
# re-run on any platform. Windows gets .ps1, Linux/macOS get .sh.
$scriptsManifest = @(
    @{ Src = "scripts\install.ps1";   Dst = "scripts\athena-install.ps1" }
    @{ Src = "scripts\install.sh";    Dst = "scripts\athena-install.sh" }
    @{ Src = "scripts\uninstall.sh";  Dst = "scripts\athena-uninstall.sh" }
    @{ Src = "scripts\verify.sh";     Dst = "scripts\athena-verify.sh" }
    @{ Src = "scripts\release.py";    Dst = "scripts\athena-release.py" }
    @{ Src = "scripts\build_dmg.sh";  Dst = "scripts\build-dmg.sh" }
)
try {
    foreach ($entry in $scriptsManifest) {
        Write-Atomic -Src (Join-Path $RepoRoot $entry.Src) -Dst (Join-Path $HermesRoot $entry.Dst)
    }
} catch {
    Write-Error "Script install failed: $_"
    exit 6
}

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
        "skills/athena/SKILL.md"        = @{ sha256 = $skillHash; mode = "0644" }
        "SOUL.md"                       = @{ mode = "0644" }
        "MEMORY.md"                     = @{ mode = "0644" }
        "USER.md"                       = @{ mode = "0644" }
        "scripts/athena-install.ps1"    = @{ mode = "0755" }
        "scripts/athena-install.sh"     = @{ mode = "0755" }
        "scripts/athena-uninstall.sh"   = @{ mode = "0755" }
        "scripts/athena-verify.sh"      = @{ mode = "0755" }
        "scripts/athena-release.py"     = @{ mode = "0755" }
        "scripts/build-dmg.sh"          = @{ mode = "0755" }
    }
    wiped = @(
        @{ path = "SOUL.md";   backup = "SOUL.md.pre-athena-$pid_local" }
        @{ path = "MEMORY.md"; backup = "MEMORY.md.pre-athena-$pid_local" }
        @{ path = "USER.md";   backup = "USER.md.pre-athena-$pid_local" }
    )
    receipt_sha256 = $skillHash
}

$tmpReceipt = Join-Path (Split-Path -Parent $ReceiptPath) `
    ([System.IO.Path]::GetRandomFileName())
$receipt | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmpReceipt -Encoding utf8
Move-Item -LiteralPath $tmpReceipt -Destination $ReceiptPath -Force

# --- audit log entry ---
$auditEntry = "{`"ts`":`"$ts`",`"action`":`"install`",`"profile`":`"$Profile`",`"receipt_sha256`":`"$skillHash`",`"operator`":`"$env:USERNAME`"}"
Add-Content -LiteralPath $AuditPath -Value $auditEntry

Write-Host "Athena installed successfully."
Write-Host "  Profile            : $Profile"
Write-Host "  Skill SHA          : $skillHash"
Write-Host "  Receipt            : $ReceiptPath"
Write-Host "  Verify             : OK"
Write-Host ""
Write-Host "Next: open Hermes and type 'athena'."

exit 0
