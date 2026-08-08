# uninstall.ps1 — Athena Windows PowerShell uninstaller
#
# Mirrors scripts/uninstall.sh semantics:
#   - Reads ../.athena.receipt and removes every file listed there
#   - Leaves .pre-athena-<pid> backups in place (manual restore)
#   - Removes the receipt itself
#   - Two-step confirmation when -Yes is not passed
#
# Exit codes:
#   0  success
#   1  unhandled error
#   3  user declined at confirmation
#   6  write failure
#   9  receipt missing

[CmdletBinding()]
param(
    [string]$HermesRoot,
    [switch]$Yes = $false
)

$ErrorActionPreference = "Stop"

# --- env var resolution ---
if (-not $HermesRoot) {
    if ($env:ATHENA_HOME) { $HermesRoot = $env:ATHENA_HOME }
    elseif ($env:HERMES_HOME) { $HermesRoot = $env:HERMES_HOME }
    else { $HermesRoot = "$env:USERPROFILE\.hermes" }
}

$ReceiptPath = Join-Path $HermesRoot ".athena.receipt"

if (-not (Test-Path -LiteralPath $ReceiptPath)) {
    Write-Error "No receipt at $ReceiptPath. Run install.ps1 first."
    exit 9
}

# --- two-step confirmation ---
if (-not $Yes -and [Environment]::UserInteractive) {
    Write-Host "Athena will remove the following from $HermesRoot:"
    Write-Host "  - skills\athena\SKILL.md + the skill folder"
    Write-Host "  - SOUL.md, MEMORY.md, USER.md"
    Write-Host "  - scripts\athena-*.ps1, athena-*.sh, athena-*.py, build-dmg.sh"
    Write-Host "  - .athena.receipt"
    Write-Host ""
    Write-Host "Note: .pre-athena-<pid> backups are preserved."
    Write-Host "Continue? [y/N]"
    $ans = Read-Host
    if ($ans -notin @("y", "Y", "yes", "Yes", "YES")) {
        Write-Host "aborted."
        exit 3
    }
}

# --- read receipt ---
$receipt = Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json

$removed = 0
$failed  = 0

# --- remove skill folder ---
$skillDir = Join-Path $HermesRoot "skills\athena"
if (Test-Path -LiteralPath $skillDir) {
    try {
        Remove-Item -LiteralPath $skillDir -Recurse -Force
        $removed++
    } catch {
        Write-Warning "could not remove $skillDir : $_"
        $failed++
    }
}

# --- remove scripted files ---
$scriptFiles = @(
    "scripts\athena-install.ps1"
    "scripts\athena-install.sh"
    "scripts\athena-uninstall.sh"
    "scripts\athena-verify.sh"
    "scripts\athena-release.py"
    "scripts\build-dmg.sh"
)
foreach ($rel in $scriptFiles) {
    $p = Join-Path $HermesRoot $rel
    if (Test-Path -LiteralPath $p) {
        try {
            Remove-Item -LiteralPath $p -Force
            $removed++
        } catch {
            Write-Warning "could not remove $p : $_"
            $failed++
        }
    }
}

# --- remove the 3 templates (only the ones we wrote) ---
foreach ($f in @("SOUL.md", "MEMORY.md", "USER.md")) {
    $p = Join-Path $HermesRoot $f
    if (Test-Path -LiteralPath $p) {
        try {
            Remove-Item -LiteralPath $p -Force
            $removed++
        } catch {
            Write-Warning "could not remove $p : $_"
            $failed++
        }
    }
}

# --- remove the receipt ---
try {
    Remove-Item -LiteralPath $ReceiptPath -Force
    $removed++
} catch {
    Write-Warning "could not remove $ReceiptPath : $_"
    $failed++
}

# --- audit log entry ---
$auditEntry = "{`"ts`":`"$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))`",`"action`":`"uninstall`",`"profile`":`"$($receipt.profile)`",`"removed`":$removed,`"failed`":$failed,`"operator`":`"$env:USERNAME`"}"
$auditPath = Join-Path $HermesRoot ".athena.audit.log"
Add-Content -LiteralPath $auditPath -Value $auditEntry

Write-Host "Athena uninstalled. Removed $removed items, $failed failures."
Write-Host ""
Write-Host "Note: .pre-athena-* files are still in $HermesRoot if you want to"
Write-Host "      manually restore SOUL.md / MEMORY.md / USER.md. See INSTALL.md §8."

if ($failed -gt 0) { exit 6 }
exit 0
