# test/test_install_script.ps1 — Windows PowerShell installer test
#
# Mirrors test/test_install_script.sh semantics:
#   - Skip if not on Windows
#   - Create a temp dir with a fake Hermes root
#   - Run install.ps1 with -Yes
#   - Assert SKILL.md + 3 templates + 6 scripts + receipt + 3 pre-athena backups
#   - Run verify.ps1
#   - Run uninstall.ps1
#   - Assert cleanup preserved pre-athena backups
#
# Exit codes:
#   0  PASS
#   1  FAIL
#   2  prerequisite missing
#   77 skipped (not Windows)

$ErrorActionPreference = "Stop"

# --- platform check ---
if (-not $IsWindows -and ($env:OS -ne "Windows_NT")) {
    if ($env:CI -or $env:ATHENA_TEST_FORCE_WIN) {
        Write-Host "Athena windows test: forced via env"
    } else {
        Write-Host "SKIP: install.ps1 requires Windows. Current: $($env:OS)"
        exit 77
    }
}

# --- locate installer ---
$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path -Parent $ScriptDir
$InstallPs1 = Join-Path $RepoRoot "scripts\install.ps1"
$UninstallPs1 = Join-Path $RepoRoot "scripts\uninstall.ps1"
$VerifyPs1 = Join-Path $RepoRoot "scripts\verify.ps1"

if (-not (Test-Path -LiteralPath $InstallPs1)) {
    Write-Error "FAIL: $InstallPs1 not found"
    exit 2
}

# --- setup tempdir ---
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "athena-test-$([System.Guid]::NewGuid())"
$HomerRoot = Join-Path $TmpDir "hermes"
New-Item -ItemType Directory -Force -Path (Join-Path $HomerRoot "skills") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $HomerRoot "scripts") | Out-Null

# Pre-existing files
"original soul"   | Out-File -FilePath (Join-Path $HomerRoot "SOUL.md") -Encoding utf8
"original memory" | Out-File -FilePath (Join-Path $HomerRoot "MEMORY.md") -Encoding utf8
"original user"   | Out-File -FilePath (Join-Path $HomerRoot "USER.md") -Encoding utf8
"agent"           | Out-File -FilePath (Join-Path $HomerRoot "AGENTS.md") -Encoding utf8
"gateway: x"      | Out-File -FilePath (Join-Path $HomerRoot "config.yaml") -Encoding utf8

$pass = 0
$fail = 0

function Assert-File {
    param([string]$Desc, [string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Write-Host "  PASS: $Desc ($Path)"
        $script:pass++
    } else {
        Write-Host "  FAIL: $Desc (missing: $Path)"
        $script:fail++
    }
}

function Assert-Not-File {
    param([string]$Desc, [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "  PASS: $Desc"
        $script:pass++
    } else {
        Write-Host "  FAIL: $Desc (still exists: $Path)"
        $script:fail++
    }
}

# --- install ---
Write-Host "=== install.ps1 ==="
$env:ATHENA_HOME = $HomerRoot
& $InstallPs1 -HermesRoot $HomerRoot -Profile "max-breaker" -Yes -Force 2>&1 | Out-Null
$rc = $LASTEXITCODE
if ($rc -eq 0) {
    Write-Host "  PASS: install exit code 0"
    $pass++
} else {
    Write-Host "  FAIL: install exit code $rc"
    $fail++
}

Assert-File "SKILL.md written"   (Join-Path $HomerRoot "skills\athena\SKILL.md")
Assert-File "SOUL.md written"    (Join-Path $HomerRoot "SOUL.md")
Assert-File "MEMORY.md written"  (Join-Path $HomerRoot "MEMORY.md")
Assert-File "USER.md written"    (Join-Path $HomerRoot "USER.md")
Assert-File "receipt written"    (Join-Path $HomerRoot ".athena.receipt")
Assert-File "install.ps1"        (Join-Path $HomerRoot "scripts\athena-install.ps1")
Assert-File "uninstall.ps1"      (Join-Path $HomerRoot "scripts\athena-uninstall.ps1")
Assert-File "verify.ps1"         (Join-Path $HomerRoot "scripts\athena-verify.ps1")
Assert-File "install.sh"         (Join-Path $HomerRoot "scripts\athena-install.sh")
Assert-File "uninstall.sh"       (Join-Path $HomerRoot "scripts\athena-uninstall.sh")
Assert-File "verify.sh"          (Join-Path $HomerRoot "scripts\athena-verify.sh")
Assert-File "release.py"         (Join-Path $HomerRoot "scripts\athena-release.py")
Assert-File "build-dmg.sh"       (Join-Path $HomerRoot "scripts\build-dmg.sh")

# --- pre-athena backups ---
$backups = Get-ChildItem -Path $HomerRoot -Filter "*.pre-athena-*" -File
if ($backups.Count -eq 3) {
    Write-Host "  PASS: pre-athena backup count 3"
    $pass++
} else {
    Write-Host "  FAIL: pre-athena backup count $($backups.Count) (expected 3)"
    $fail++
}

# --- AGENTS.md + config.yaml untouched ---
$agentsContent = Get-Content -Raw -LiteralPath (Join-Path $HomerRoot "AGENTS.md")
$configContent = Get-Content -Raw -LiteralPath (Join-Path $HomerRoot "config.yaml")
if ($agentsContent -match "agent") {
    Write-Host "  PASS: AGENTS.md untouched"
    $pass++
} else {
    Write-Host "  FAIL: AGENTS.md was modified"
    $fail++
}
if ($configContent -match "gateway: x") {
    Write-Host "  PASS: config.yaml untouched"
    $pass++
} else {
    Write-Host "  FAIL: config.yaml was modified"
    $fail++
}

# --- receipt is valid JSON ---
try {
    $null = Get-Content -LiteralPath (Join-Path $HomerRoot ".athena.receipt") -Raw | ConvertFrom-Json
    Write-Host "  PASS: receipt is valid JSON"
    $pass++
} catch {
    Write-Host "  FAIL: receipt is not valid JSON: $_"
    $fail++
}

# --- verify ---
Write-Host ""
Write-Host "=== verify.ps1 ==="
& $VerifyPs1 -HermesRoot $HomerRoot 2>&1 | Out-Null
$rc = $LASTEXITCODE
if ($rc -eq 0) {
    Write-Host "  PASS: verify exit code 0"
    $pass++
} else {
    Write-Host "  FAIL: verify exit code $rc"
    $fail++
}

# --- uninstall ---
Write-Host ""
Write-Host "=== uninstall.ps1 ==="
& $UninstallPs1 -HermesRoot $HomerRoot -Yes 2>&1 | Out-Null
$rc = $LASTEXITCODE
if ($rc -eq 0) {
    Write-Host "  PASS: uninstall exit code 0"
    $pass++
} else {
    Write-Host "  FAIL: uninstall exit code $rc"
    $fail++
}

Assert-Not-File "SKILL.md removed"        (Join-Path $HomerRoot "skills\athena\SKILL.md")
Assert-Not-File "install.ps1 removed"     (Join-Path $HomerRoot "scripts\athena-install.ps1")
Assert-Not-File "verify.ps1 removed"      (Join-Path $HomerRoot "scripts\athena-verify.ps1")
Assert-Not-File "install.sh removed"      (Join-Path $HomerRoot "scripts\athena-install.sh")
Assert-Not-File "uninstall.sh removed"    (Join-Path $HomerRoot "scripts\athena-uninstall.sh")
Assert-Not-File "verify.sh removed"       (Join-Path $HomerRoot "scripts\athena-verify.sh")
Assert-Not-File "release.py removed"      (Join-Path $HomerRoot "scripts\athena-release.py")
Assert-Not-File "build-dmg.sh removed"    (Join-Path $HomerRoot "scripts\build-dmg.sh")
Assert-Not-File "receipt removed"         (Join-Path $HomerRoot ".athena.receipt")

# Pre-athena backups preserved
$backupsAfter = Get-ChildItem -Path $HomerRoot -Filter "*.pre-athena-*" -File
if ($backupsAfter.Count -eq 3) {
    Write-Host "  PASS: pre-athena backups preserved"
    $pass++
} else {
    Write-Host "  FAIL: pre-athena backup count after uninstall $($backupsAfter.Count) (expected 3)"
    $fail++
}

# --- cleanup ---
Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue

# --- summary ---
Write-Host ""
Write-Host "=== summary ==="
Write-Host "PASS: $pass"
Write-Host "FAIL: $fail"
if ($fail -gt 0) { exit 1 }
Write-Host "all tests passed."
exit 0
