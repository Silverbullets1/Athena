#!/bin/sh
# test/test_build_dmg.sh — DMG pipeline test
#
# Skipped if not on macOS. Runs scripts/build_dmg.sh, verifies Athena.app exists,
# verifies Athena-v*.dmg exists, verifies .dmg > 50MB.
#
# Exit codes:
#   0  all tests passed
#   1  test failed
#   2  prerequisite missing (macOS, pyinstaller)
#   77 skipped (not macOS)

set -eu

# --- platform check ---
if [ "$(uname -s)" != "Darwin" ]; then
    echo "SKIP: build_dmg.sh requires macOS. Current: $(uname -s)"
    exit 77
fi

# --- pyinstaller check ---
if ! command -v pyinstaller >/dev/null 2>&1; then
    echo "SKIP: pyinstaller not installed"
    exit 77
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

assert_eq() {
    if [ "$2" = "$3" ]; then
        echo "  PASS: $1"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $1 (expected: $2, actual: $3)"
        FAIL=$((FAIL + 1))
    fi
}

# --- clean before build ---
cd "$REPO_ROOT"
rm -rf build dist Athena-v*.dmg

# --- run build ---
echo "=== running build_dmg.sh ==="
bash scripts/build_dmg.sh >/dev/null 2>&1
RC=$?
assert_eq "build_dmg.sh exit code" "0" "$RC"

# --- verify Athena.app ---
if [ -d "dist/Athena.app" ]; then
    echo "  PASS: Athena.app produced"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Athena.app missing"
    FAIL=$((FAIL + 1))
fi

# --- verify .dmg ---
DMG=$(ls Athena-v*.dmg 2>/dev/null | head -1)
if [ -n "$DMG" ] && [ -f "$DMG" ]; then
    echo "  PASS: $DMG produced"
    PASS=$((PASS + 1))
    SIZE=$(stat -f%z "$DMG")
    MIN_SIZE=$((50 * 1024 * 1024))
    if [ "$SIZE" -ge "$MIN_SIZE" ]; then
        echo "  PASS: $DMG size $SIZE bytes >= $MIN_SIZE"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $DMG size $SIZE bytes < $MIN_SIZE"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  FAIL: no .dmg produced"
    FAIL=$((FAIL + 1))
fi

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
