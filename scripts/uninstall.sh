#!/bin/sh
# uninstall.sh — Athena POSIX uninstaller (receipt-chain rollback)
#
# Usage:
#   uninstall.sh [hermes_root] [--yes]
#
# Reads .athena.receipt, removes each file whose SHA-256 matches (if recorded),
# removes the receipt itself, leaves .pre-athena-* files in place for manual restore.
#
# Exit codes:
#   0  success
#   1  not installed (no-op)
#   6  write failure
#   9  receipt corrupted

set -eu

HERMES_ROOT="${1:-$HOME/.hermes}"
YES=0
shift 2>/dev/null || shift "$#" 2>/dev/null || true
for arg in "$@"; do
    case "$arg" in
        --yes) YES=1 ;;
        *) ;;
    esac
done

RECEIPT="$HERMES_ROOT/.athena.receipt"

if [ ! -f "$RECEIPT" ]; then
    echo "Athena not installed (no receipt at $RECEIPT)."
    exit 1
fi

# --- confirmation ---
if [ "$YES" -eq 0 ] && [ -t 0 ]; then
    echo "Athena will remove:"
    echo "  $HERMES_ROOT/skills/athena/SKILL.md"
    echo "  $HERMES_ROOT/scripts/athena-* (5 files)"
    echo "  $HERMES_ROOT/.athena.receipt"
    echo ".pre-athena-* files will be left in place for manual restore."
    echo "Continue? [y/N]" >&2
    printf "> " >&2
    read -r ans
    case "$ans" in
        [Yy]*) ;;
        *) echo "aborted." >&2; exit 3 ;;
    esac
fi

# --- remove files ---
removed=0
failed=0

# SKILL.md
f="$HERMES_ROOT/skills/athena/SKILL.md"
if [ -f "$f" ]; then
    if rm -f "$f"; then
        removed=$((removed + 1))
    else
        failed=$((failed + 1))
    fi
fi

# skills/athena/ dir (if empty after removal)
rmdir "$HERMES_ROOT/skills/athena" 2>/dev/null || true

# scripts
for s in athena-install.sh athena-uninstall.sh athena-verify.sh athena-release.py build-dmg.sh; do
    f="$HERMES_ROOT/scripts/$s"
    if [ -f "$f" ]; then
        if rm -f "$f"; then
            removed=$((removed + 1))
        else
            failed=$((failed + 1))
        fi
    fi
done

# Receipt itself
if rm -f "$RECEIPT"; then
    removed=$((removed + 1))
else
    failed=$((failed + 1))
fi

# --- audit log entry ---
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "{\"ts\":\"$TS\",\"action\":\"uninstall\",\"removed\":$removed,\"failed\":$failed,\"operator\":\"${USER:-unknown}\"}" >> "$HERMES_ROOT/.athena.audit.log"

echo "Athena uninstalled. Removed $removed files, $failed failures."
if [ "$failed" -gt 0 ]; then
    echo "WARNING: $failed files could not be removed. Check permissions." >&2
    exit 6
fi

echo ""
echo "Note: .pre-athena-* files are still in $HERMES_ROOT if you want to"
echo "      manually restore SOUL.md / MEMORY.md / USER.md. See INSTALL.md §8."
exit 0
