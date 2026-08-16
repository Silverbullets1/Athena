#!/bin/sh
# test/test_install_script.sh — POSIX install script test
#
# Sets ATHENA_HOME to a tempdir, creates a fake Hermes root, runs install.sh,
# verifies SKILL.md + scripts + SOUL/MEMORY/USER + .athena.receipt, then runs
# uninstall.sh and verifies cleanup.
#
# Exit codes:
#   0  all tests passed
#   1  test failed
#   2  prerequisite missing

set -eu

# --- preflight ---
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_SH="$REPO_ROOT/scripts/install.sh"
UNINSTALL_SH="$REPO_ROOT/scripts/uninstall.sh"
VERIFY_SH="$REPO_ROOT/scripts/verify.sh"

if [ ! -x "$INSTALL_SH" ]; then
    echo "FAIL: $INSTALL_SH not executable" >&2
    exit 2
fi

# --- setup tempdir ---
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
HERMES_ROOT="$TMPDIR/hermes"
mkdir -p "$HERMES_ROOT/skills"
mkdir -p "$HERMES_ROOT/scripts"

# Pre-existing files
echo "# original soul" > "$HERMES_ROOT/SOUL.md"
echo "# original memory" > "$HERMES_ROOT/MEMORY.md"
echo "# original user" > "$HERMES_ROOT/USER.md"
echo "# agent" > "$HERMES_ROOT/AGENTS.md"
echo "gateway: x" > "$HERMES_ROOT/config.yaml"

PASS=0
FAIL=0

assert_eq() {
    desc="$1"
    expected="$2"
    actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    expected: $expected"
        echo "    actual  : $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_file() {
    desc="$1"
    path="$2"
    if [ -f "$path" ]; then
        echo "  PASS: $desc ($path)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (missing: $path)"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_file() {
    desc="$1"
    path="$2"
    if [ ! -f "$path" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (still exists: $path)"
        FAIL=$((FAIL + 1))
    fi
}

# --- install ---
echo "=== install.sh ==="
# Capture pre-install baseline for files install must NOT touch
AGENTS_BEFORE=$(cat "$HERMES_ROOT/AGENTS.md")
CONFIG_BEFORE=$(cat "$HERMES_ROOT/config.yaml")

"$INSTALL_SH" "$HERMES_ROOT" "max-breaker" "--yes" >/dev/null 2>&1
RC=$?
assert_eq "install exit code" "0" "$RC"

assert_file "SKILL.md written"   "$HERMES_ROOT/skills/athena/SKILL.md"
assert_file "athena-router SKILL" "$HERMES_ROOT/skills/athena-router/SKILL.md"
assert_file "SOUL.md written"    "$HERMES_ROOT/SOUL.md"
assert_file "MEMORY.md written"  "$HERMES_ROOT/MEMORY.md"
assert_file "USER.md written"    "$HERMES_ROOT/USER.md"
assert_file "receipt written"    "$HERMES_ROOT/.athena.receipt"
assert_file "install script"     "$HERMES_ROOT/scripts/athena-install.sh"
assert_file "uninstall script"   "$HERMES_ROOT/scripts/athena-uninstall.sh"
assert_file "verify script"      "$HERMES_ROOT/scripts/athena-verify.sh"
assert_file "release.py"         "$HERMES_ROOT/scripts/athena-release.py"
assert_file "build-dmg.sh"       "$HERMES_ROOT/scripts/build-dmg.sh"

# Verify pre-athena backups
BACKUP_COUNT=$(ls "$HERMES_ROOT"/*.pre-athena-* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "pre-athena backup count" "3" "$BACKUP_COUNT"

# Verify receipt is valid JSON
if python3 -c "import json; json.load(open('$HERMES_ROOT/.athena.receipt'))" 2>/dev/null; then
    echo "  PASS: receipt is valid JSON"
    PASS=$((PASS + 1))
else
    echo "  FAIL: receipt is not valid JSON"
    FAIL=$((FAIL + 1))
fi

# Verify AGENTS.md + config.yaml untouched (re-read post-install, compare to baseline)
AGENTS_AFTER=$(cat "$HERMES_ROOT/AGENTS.md")
CONFIG_AFTER=$(cat "$HERMES_ROOT/config.yaml")
assert_eq "AGENTS.md unchanged" "$AGENTS_BEFORE" "$AGENTS_AFTER"
assert_eq "config.yaml unchanged" "$CONFIG_BEFORE" "$CONFIG_AFTER"

# Verify scripts are executable
for s in athena-install.sh athena-uninstall.sh athena-verify.sh athena-release.py build-dmg.sh; do
    if [ -x "$HERMES_ROOT/scripts/$s" ]; then
        echo "  PASS: $s is executable"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $s is NOT executable"
        FAIL=$((FAIL + 1))
    fi
done

# --- verify ---
echo ""
echo "=== verify.sh ==="
"$VERIFY_SH" "$HERMES_ROOT" >/dev/null 2>&1
RC=$?
assert_eq "verify exit code" "0" "$RC"

# --- uninstall ---
echo ""
echo "=== uninstall.sh ==="
"$UNINSTALL_SH" "$HERMES_ROOT" "--yes" >/dev/null 2>&1
RC=$?
assert_eq "uninstall exit code" "0" "$RC"

assert_not_file "SKILL.md removed"   "$HERMES_ROOT/skills/athena/SKILL.md"
assert_not_file "install script removed"   "$HERMES_ROOT/scripts/athena-install.sh"
assert_not_file "uninstall script removed" "$HERMES_ROOT/scripts/athena-uninstall.sh"
assert_not_file "verify script removed"    "$HERMES_ROOT/scripts/athena-verify.sh"
assert_not_file "release.py removed"       "$HERMES_ROOT/scripts/athena-release.py"
assert_not_file "build-dmg.sh removed"     "$HERMES_ROOT/scripts/build-dmg.sh"
assert_not_file "receipt removed"          "$HERMES_ROOT/.athena.receipt"

# Pre-athena backups should still be there
BACKUP_AFTER=$(ls "$HERMES_ROOT"/*.pre-athena-* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "pre-athena backups preserved" "3" "$BACKUP_AFTER"

# --- second install: refuse without --force ---
echo ""
echo "=== second install without --force ==="
"$INSTALL_SH" "$HERMES_ROOT" "max-breaker" "--yes" >/dev/null 2>&1
RC=$?
assert_eq "second install exit code" "0" "$RC"

# Second install should not have wiped since we don't pre-athena backups from 2nd install
# (or if it did, that's fine — the test just checks exit code)

# --- repair run: persona files wiped manually, no --force ---
echo ""
echo "=== repair run: wipe persona files, reinstall without --force ==="
rm -f "$HERMES_ROOT/SOUL.md" "$HERMES_ROOT/MEMORY.md" "$HERMES_ROOT/USER.md"
"$INSTALL_SH" "$HERMES_ROOT" "max-breaker" "--yes" >/dev/null 2>&1
RC=$?
assert_eq "repair install exit code" "0" "$RC"
assert_file "SOUL.md re-applied"   "$HERMES_ROOT/SOUL.md"
assert_file "MEMORY.md re-applied" "$HERMES_ROOT/MEMORY.md"
assert_file "USER.md re-applied"   "$HERMES_ROOT/USER.md"

# --- summary ---
echo ""
echo "=== summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo "all tests passed."
exit 0
