#!/bin/sh
# install-oneclick.sh — Athena one-click POSIX installer (Linux / Raspberry Pi / macOS)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/xscope0/athena/main/scripts/install-oneclick.sh | sh
#
# Or locally:
#   ./scripts/install-oneclick.sh
#   ./scripts/install-oneclick.sh --profile builder
#   ./scripts/install-oneclick.sh --force
#
# What it does:
#   1. Auto-clones xscope0/athena to ~/.local/share/athena (or $XDG_DATA_HOME/athena)
#      when invoked via curl|sh.
#   2. Detects Python (3.10+). If missing, prints the install command for the
#      operator's distro and exits 2.
#   3. Detects display server: if no $DISPLAY and no $WAYLAND_DISPLAY (Linux
#      only), skips the GUI deps and prints a CLI-only banner.
#   4. pip installs requirements.txt (core only) plus optionally
#      requirements-gui.txt when a display is detected.
#   5. Calls scripts/install.sh with -Profile -Yes (-Force auto-detected).
#
# Exit codes:
#   0  success
#   1  unhandled error
#   2  Python missing
#   3  user declined confirmation
#   4  prerequisite missing
#   5  install.sh ownership conflict (no -Force)
#   6  write failure

set -eu

# --- arg parsing ---
PROFILE="max-breaker"
FORCE=0
INSTALL_GUI=0
NO_DEPS=0

for arg in "$@"; do
    case "$arg" in
        --profile) shift; PROFILE="${1:-max-breaker}" ;;
        --profile=*) PROFILE="${arg#--profile=}" ;;
        --force) FORCE=1 ;;
        --with-gui) INSTALL_GUI=1 ;;
        --no-deps) NO_DEPS=1 ;;
        --help|-h)
            echo "Usage: $0 [--profile NAME] [--force] [--with-gui] [--no-deps]"
            echo ""
            echo "  --profile NAME   one of: max-breaker, builder, research, creative (default: max-breaker)"
            echo "  --force          overwrite existing install"
            echo "  --with-gui       install PyQt6 GUI deps (default: auto-detect)"
            echo "  --no-deps        skip pip install step"
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# --- detect POSIX environment ---
SCRIPT_DIR="${SCRIPT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(dirname "$SCRIPT_DIR")}"

# Detect "running via curl|sh" by checking if SKILL.md is reachable.
# When curl|sh, $SCRIPT_DIR is empty (no script) and $REPO_ROOT is not set.
if [ ! -f "$REPO_ROOT/SKILL.md" ]; then
    XDG="${XDG_DATA_HOME:-$HOME/.local/share}"
    REPO_ROOT="$XDG/athena"
    mkdir -p "$REPO_ROOT"
    if [ ! -f "$REPO_ROOT/SKILL.md" ]; then
        echo "Athena one-click installer — first run, cloning repository..."
        if command -v git >/dev/null 2>&1; then
            git clone --depth=1 https://github.com/xscope0/athena.git "$REPO_ROOT"
        else
            # Fallback: tarball
            curl -fsSL https://github.com/xscope0/athena/archive/refs/heads/main.tar.gz \
                | tar -xz -C "$REPO_ROOT" --strip-components=1
        fi
    fi
fi

# --- banner ---
BANNERS_DIR="$REPO_ROOT/banners"
if [ -d "$BANNERS_DIR" ]; then
    for n in athena nerv; do
        if [ -f "$BANNERS_DIR/$n.ascii" ]; then
            cat "$BANNERS_DIR/$n.ascii" 2>/dev/null 1>&2 || true
        fi
    done
fi

# --- detect Python ---
PYTHON=""
for cmd in python3 python; do
    if command -v "$cmd" >/dev/null 2>&1; then
        if "$cmd" -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" 2>/dev/null; then
            PYTHON="$cmd"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python 3.10+ not found." >&2
    echo "" >&2
    echo "Install via your package manager:" >&2
    echo "  Debian/Ubuntu/Raspberry Pi OS:  sudo apt install python3 python3-pip python3-venv" >&2
    echo "  Fedora/RHEL:                    sudo dnf install python3 python3-pip" >&2
    echo "  Arch:                           sudo pacman -S python python-pip" >&2
    echo "  Alpine:                         sudo apk add python3 py3-pip" >&2
    echo "  macOS:                          brew install python@3.12" >&2
    exit 2
fi

VER=$("$PYTHON" --version 2>&1)
echo "Using: $VER"

# --- detect headless (Linux) ---
IS_HEADLESS=0
case "$(uname -s)" in
    Linux)
        if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
            IS_HEADLESS=1
        fi
        ;;
esac

if [ "$INSTALL_GUI" -eq 0 ] && [ "$IS_HEADLESS" -eq 1 ]; then
    INSTALL_GUI=0
    echo "Detected headless Linux — skipping GUI deps (PyQt6)."
    echo "Use --with-gui to force-install anyway."
fi

# --- deps ---
if [ "$NO_DEPS" -eq 0 ]; then
    if [ -f "$REPO_ROOT/requirements.txt" ]; then
        echo "Installing core Python dependencies (hermes-agent)..."
        "$PYTHON" -m pip install --quiet --disable-pip-version-check -r "$REPO_ROOT/requirements.txt"
        if [ $? -ne 0 ]; then
            echo "ERROR: pip install failed." >&2
            echo "Re-run with --no-deps to skip, then debug manually." >&2
            exit 6
        fi
    fi

    if [ "$INSTALL_GUI" -eq 1 ] && [ -f "$REPO_ROOT/requirements-gui.txt" ]; then
        echo "Installing GUI dependencies (PyQt6)..."
        "$PYTHON" -m pip install --quiet --disable-pip-version-check -r "$REPO_ROOT/requirements-gui.txt" || {
            echo "WARNING: GUI deps install failed. Athena CLI still works without GUI."
            echo "On Raspberry Pi 32-bit (armv7l), PyQt6 has no PyPI wheel — use:"
            echo "  sudo apt install python3-pyqt6"
        }
    fi
fi

# --- invoke install.sh with defaults ---
INSTALL_SH="$REPO_ROOT/scripts/install.sh"
if [ ! -x "$INSTALL_SH" ]; then
    echo "ERROR: install.sh not found at $INSTALL_SH" >&2
    exit 4
fi

NEEDS_FORCE="$FORCE"
SKILL_PATH="${HERMES_ROOT:-$HOME/.hermes}/skills/athena/SKILL.md"
if [ -f "$SKILL_PATH" ] && [ "$NEEDS_FORCE" -eq 0 ]; then
    NEEDS_FORCE=1
fi

ARGS="--yes"
if [ "$NEEDS_FORCE" -eq 1 ]; then
    ARGS="$ARGS --force"
fi

echo "Invoking install.sh --profile=$PROFILE $ARGS"
sh "$INSTALL_SH" "$HOME/.hermes" "$PROFILE" "$ARGS"
exit $?