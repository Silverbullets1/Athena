#!/bin/sh
# build_dmg.sh — Athena macOS .app + .dmg builder
#
# Usage:
#   bash scripts/build_dmg.sh
#
# Requires: macOS, pyinstaller, hdiutil (preinstalled)
#
# Produces: Athena-v<version>.dmg in repo root
#
# Exit codes:
#   0  success
#   1  not on macOS
#   2  pyinstaller missing
#   3  pyinstaller failed
#   4  Athena.app not produced
#   5  hdiutil failed
#   6  .dmg suspiciously small

set -eu

# --- platform check ---
if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: build_dmg.sh requires macOS. Current: $(uname -s)" >&2
    exit 1
fi

# --- pyinstaller check ---
if ! command -v pyinstaller >/dev/null 2>&1; then
    echo "ERROR: pyinstaller not found. Install with: pip install pyinstaller" >&2
    exit 2
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

# --- resolve version ---
VERSION="$(python3 -c 'import sys; sys.path.insert(0, "app"); from athena import __version__; print(__version__)')"

# --- clean previous build ---
rm -rf build dist Athena-v*.dmg

# --- build .app ---
echo "[1/4] Building Athena.app via pyinstaller..."
pyinstaller gui/athena_gui.spec --clean --noconfirm || { echo "pyinstaller failed" >&2; exit 3; }

# --- verify .app ---
if [ ! -d "dist/Athena.app" ]; then
    echo "ERROR: Athena.app not produced at dist/Athena.app" >&2
    exit 4
fi
echo "[2/4] Athena.app produced."

# --- build .dmg ---
DMG_NAME="Athena-v${VERSION}.dmg"
echo "[3/4] Building $DMG_NAME via hdiutil..."
hdiutil create \
    -volname "Athena" \
    -srcfolder "dist/Athena.app" \
    -ov \
    -format UDZO \
    "$DMG_NAME" || { echo "hdiutil failed" >&2; exit 5; }

# --- verify .dmg ---
if [ ! -f "$DMG_NAME" ]; then
    echo "ERROR: $DMG_NAME not created" >&2
    exit 5
fi
SIZE=$(stat -f%z "$DMG_NAME")
MIN_SIZE=$((50 * 1024 * 1024))  # 50 MB
if [ "$SIZE" -lt "$MIN_SIZE" ]; then
    echo "ERROR: $DMG_NAME is suspiciously small ($SIZE bytes; expected >= $MIN_SIZE)" >&2
    exit 6
fi

echo "[4/4] OK: $DMG_NAME ($SIZE bytes)"
echo ""
echo "First-launch workaround (Apple Silicon):"
echo "  xattr -d com.apple.quarantine /Applications/Athena.app"
echo ""
echo "Install:"
echo "  open $DMG_NAME"
echo "  # drag Athena.app to /Applications"
exit 0
