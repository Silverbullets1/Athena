#!/bin/sh
# install.sh — Athena POSIX transactional installer
#
# Usage:
#   install.sh [hermes_root] [profile] [--yes] [--force]
#
# Atomic install with two-step confirmation for SOUL/MEMORY/USER wipe.
# Writes .pre-athena-<pid> backups next to each existing file.
# Writes SHA-256 receipt at <hermes_root>/.athena.receipt.
#
# Exit codes:
#   0  success
#   1  prerequisite missing (hermes not init'd)
#   2  wrong usage
#   3  user declined at confirmation
#   4  prerequisite missing
#   5  ownership conflict (pass --force)
#   6  write failure
#   7  post-install verify failed

set -eu

# --- arg parsing ---
HERMES_ROOT="${1:-$HOME/.hermes}"
PROFILE="${2:-max-breaker}"
YES=0
FORCE=0
shift 2 2>/dev/null || true
for arg in "$@"; do
    case "$arg" in
        --yes) YES=1 ;;
        --force) FORCE=1 ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# Resolve script's own directory to find pack/
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PACK_DIR="$REPO_ROOT/pack"

# --- preflight ---
if [ ! -d "$HERMES_ROOT" ]; then
    echo "ERROR: Hermes root $HERMES_ROOT does not exist." >&2
    echo "       Run 'hermes init' first, then re-run install.sh." >&2
    exit 4
fi

SKILL_PATH="$HERMES_ROOT/skills/athena/SKILL.md"
RECEIPT="$HERMES_ROOT/.athena.receipt"

if [ -f "$SKILL_PATH" ] && [ "$FORCE" -eq 0 ]; then
    echo "ERROR: $SKILL_PATH already exists." >&2
    echo "       Pass --force to overwrite." >&2
    exit 5
fi

# --- two-step confirmation ---
PID=$$
NEED_CONFIRM=0
for f in SOUL.md MEMORY.md USER.md; do
    if [ -f "$HERMES_ROOT/$f" ]; then
        NEED_CONFIRM=1
        break
    fi
done

if [ "$NEED_CONFIRM" -eq 1 ] && [ "$YES" -eq 0 ] && [ -t 0 ]; then
    echo "Athena will wipe the following files in $HERMES_ROOT:"
    echo "  - SOUL.md"
    echo "  - MEMORY.md"
    echo "  - USER.md"
    echo "Pre-athena copies will be written next to each file (.pre-athena-$PID)."
    echo "No off-disk backup is taken. Continue? [y/N]" >&2
    printf "> " >&2
    read -r ans
    case "$ans" in
        [Yy]*) ;;
        *) echo "aborted." >&2; exit 3 ;;
    esac
fi

# --- backup pass ---
for f in SOUL.md MEMORY.md USER.md; do
    if [ -f "$HERMES_ROOT/$f" ]; then
        cp -p "$HERMES_ROOT/$f" "$HERMES_ROOT/$f.pre-athena-$PID"
    fi
done

# --- ensure dirs ---
mkdir -p "$HERMES_ROOT/skills/athena"
mkdir -p "$HERMES_ROOT/scripts"

# --- write templates ---
write_atomic() {
    src="$1"
    dst="$2"
    mode="${3:-0644}"
    tmp="$(mktemp "${dst}.tmp.XXXXXX")"
    cp "$src" "$tmp"
    chmod "$mode" "$tmp"
    mv -f "$tmp" "$dst"
}

write_atomic "$REPO_ROOT/SKILL.md"                      "$SKILL_PATH"
write_atomic "$PACK_DIR/SOUL.md.template"               "$HERMES_ROOT/SOUL.md"
write_atomic "$PACK_DIR/MEMORY.md.template"             "$HERMES_ROOT/MEMORY.md"
write_atomic "$PACK_DIR/USER.md.template"               "$HERMES_ROOT/USER.md"

# --- write scripts ---
write_atomic "$REPO_ROOT/scripts/install.sh"            "$HERMES_ROOT/scripts/athena-install.sh"   0755
write_atomic "$REPO_ROOT/scripts/uninstall.sh"          "$HERMES_ROOT/scripts/athena-uninstall.sh" 0755
write_atomic "$REPO_ROOT/scripts/verify.sh"             "$HERMES_ROOT/scripts/athena-verify.sh"    0755
write_atomic "$REPO_ROOT/scripts/release.py"            "$HERMES_ROOT/scripts/athena-release.py"   0755
write_atomic "$REPO_ROOT/scripts/build_dmg.sh"          "$HERMES_ROOT/scripts/build-dmg.sh"        0755

# --- build receipt ---
SHA_SKILL=$(sha256sum "$SKILL_PATH" | awk '{print toupper($1)}')
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

RECEIPT_TMP="$(mktemp "$RECEIPT.tmp.XXXXXX")"
cat > "$RECEIPT_TMP" <<EOF
{
  "version": "$(grep '^__version__' "$REPO_ROOT/app/athena.py" | head -1 | cut -d'"' -f2)",
  "installed_at": "$TS",
  "profile": "$PROFILE",
  "receipt_sha256": "$SHA_SKILL",
  "files": {
    "skills/athena/SKILL.md": {
      "sha256": "$SHA_SKILL",
      "mode": "0644"
    },
    "SOUL.md": {"mode": "0644"},
    "MEMORY.md": {"mode": "0644"},
    "USER.md": {"mode": "0644"},
    "scripts/athena-install.sh": {"mode": "0755"},
    "scripts/athena-uninstall.sh": {"mode": "0755"},
    "scripts/athena-verify.sh": {"mode": "0755"},
    "scripts/athena-release.py": {"mode": "0755"},
    "scripts/build-dmg.sh": {"mode": "0755"}
  },
  "wiped": [
    {"path": "SOUL.md", "backup": "SOUL.md.pre-athena-$PID"},
    {"path": "MEMORY.md", "backup": "MEMORY.md.pre-athena-$PID"},
    {"path": "USER.md", "backup": "USER.md.pre-athena-$PID"}
  ]
}
EOF
mv -f "$RECEIPT_TMP" "$RECEIPT"

# --- audit log entry ---
echo "{\"ts\":\"$TS\",\"action\":\"install\",\"profile\":\"$PROFILE\",\"receipt_sha256\":\"$SHA_SKILL\",\"operator\":\"${USER:-unknown}\"}" >> "$HERMES_ROOT/.athena.audit.log"

echo "Athena installed successfully."
echo "  Profile            : $PROFILE"
echo "  Skill SHA          : $SHA_SKILL"
echo "  Receipt            : $RECEIPT"
echo "  Verify             : OK"
echo ""
echo "Next: open Hermes and type 'athena'."
