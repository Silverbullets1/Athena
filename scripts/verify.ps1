# verify.ps1 — Athena Windows PowerShell contract verifier
#
# Mirrors scripts/verify.sh:
#   - Reads ../.athena.receipt
#   - Recomputes SHA-256 of skills/athena/SKILL.md
#   - Verifies the receipt's expected SHA matches actual
#   - Verifies templated files exist and reference "Athena"
#   - Reports PASS / FAIL with exit code
#
# Exit codes:
#   0  PASS
#   1  no receipt
#   2  skill SHA mismatch
#   3  template mismatch
#   9  unhandled error

[CmdletBinding()]
param(
    [string]$HermesRoot,
    [switch]$Json = $false
)

$ErrorActionPreference = "Stop"

# --- env var resolution ---
if (-not $HermesRoot) {
    if ($env:ATHENA_HOME) { $HermesRoot = $env:ATHENA_HOME }
    elseif ($env:HERMES_HOME) { $HermesRoot = $env:HERMES_HOME }
    else { $HermesRoot = "$env:USERPROFILE\.hermes" }
}

# --- banner ---
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BannersDir = Join-Path $RepoRoot "banners"
foreach ($name in @("athena", "nerv")) {
    $p = Join-Path $BannersDir "$name.ascii"
    if (Test-Path -LiteralPath $p) {
        try { Get-Content -LiteralPath $p -Raw } catch { }
    }
}

$ReceiptPath = Join-Path $HermesRoot ".athena.receipt"
$SkillPath = Join-Path $HermesRoot "skills\athena\SKILL.md"
$LogPath = Join-Path $HermesRoot ".athena.audit.log"

# --- read receipt ---
if (-not (Test-Path -LiteralPath $ReceiptPath)) {
    if ($Json) {
        Write-Output "{`"status`":`"FAIL`",`"reason`":`"no receipt`"}"
    } else {
        Write-Error "No receipt at $ReceiptPath"
    }
    exit 1
}

$receipt = Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json
$expected = $receipt.receipt_sha256
$profile = $receipt.profile

# --- compute actual SHA ---
if (-not (Test-Path -LiteralPath $SkillPath)) {
    if ($Json) {
        Write-Output "{`"status`":`"FAIL`",`"reason`":`"SKILL.md missing`"}"
    } else {
        Write-Error "Skill file missing: $SkillPath"
    }
    exit 2
}

$bytes = [System.IO.File]::ReadAllBytes($SkillPath)
$h = [System.Security.Cryptography.SHA256]::Create()
$actual = ($h.ComputeHash($bytes) | ForEach-Object { $_.ToString("X2") }) -join ""
$h.Dispose()

# --- check templates ---
$templates = @("SOUL.md", "MEMORY.md", "USER.md")
$templatesOK = $true
foreach ($t in $templates) {
    $p = Join-Path $HermesRoot $t
    if (-not (Test-Path -LiteralPath $p)) {
        $templatesOK = $false
        break
    }
    $content = Get-Content -LiteralPath $p -Raw
    if ($content -notmatch "Athena") {
        $templatesOK = $false
        break
    }
}

# --- check scripts ---
$scriptsCheck = @(
    "scripts\athena-install.ps1"
    "scripts\athena-install.sh"
    "scripts\athena-uninstall.sh"
    "scripts\athena-verify.sh"
    "scripts\athena-release.py"
    "scripts\build-dmg.sh"
)
$scriptsOK = $true
foreach ($s in $scriptsCheck) {
    $p = Join-Path $HermesRoot $s
    if (-not (Test-Path -LiteralPath $p)) {
        $scriptsOK = $false
        break
    }
}

# --- verdict ---
$status = "PASS"
$reason = ""
if ($actual -ne $expected) { $status = "FAIL"; $reason = "SHA mismatch" }
elseif (-not $templatesOK) { $status = "FAIL"; $reason = "templates missing or invalid" }
elseif (-not $scriptsOK) { $status = "FAIL"; $reason = "scripts missing" }

# --- audit log entry ---
$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$auditEntry = "{`"ts`":`"$ts`",`"action`":`"verify`",`"status`":`"$status`",`"reason`":`"$reason`",`"sha_expected`":`"$expected`",`"sha_actual`":`"$actual`"}"
if (Test-Path -LiteralPath $LogPath) {
    Add-Content -LiteralPath $LogPath -Value $auditEntry
}

# --- output ---
if ($Json) {
    Write-Output (ConvertTo-Json -Depth 4 @{
        status           = $status
        skill_path       = $SkillPath
        receipt_path     = $ReceiptPath
        expected_sha256  = $expected
        actual_sha256    = $actual
        templates_ok     = $templatesOK
        scripts_ok       = $scriptsOK
        profile          = $profile
        verified_at      = $ts
    })
} else {
    Write-Host "Athena verify"
    Write-Host "  Skill file        : $(if ($actual -eq $expected) {'OK'} else {'FAIL'})"
    Write-Host "  Script files      : $(if ($scriptsOK) {'6/6 OK'} else {'FAIL'})"
    Write-Host "  Templates         : $(if ($templatesOK) {'3/3 OK'} else {'FAIL'})"
    Write-Host "  Receipt           : OK"
    Write-Host "  Profile           : $profile"
    Write-Host "  Status            : $status"
}

if ($status -ne "PASS") {
    switch ($reason) {
        "SHA mismatch" { exit 2 }
        "templates missing or invalid" { exit 3 }
        "scripts missing" { exit 3 }
        default { exit 9 }
    }
}

exit 0
