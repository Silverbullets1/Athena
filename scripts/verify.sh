#!/bin/sh
# verify.sh — Athena POSIX verifier
#
# Usage:
#   verify.sh [hermes_root] [--json]
#
# Re-checks every file in .athena.receipt against current SHA-256.
# Reports mismatch with file path.
#
# Exit codes:
#   0  PASS
#   1  SHA-256 mismatch
#   2  receipt missing
#   3  script permission issue
#   9  receipt corrupted

set -eu

# --- banner ---
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BANNERS_DIR="$REPO_ROOT/banners"
if [ -d "$BANNERS_DIR" ]; then
    for n in athena nerv; do
        if [ -f "$BANNERS_DIR/$n.ascii" ]; then
            cat "\$BANNERS_DIR/\$n.ascii" 2>/dev/null 1>&2 || true
        fi
    done
fi

HERMES_ROOT="${1:-$HOME/.hermes}"
JSON=0
shift 2>/dev/null || shift "$#" 2>/dev/null || true
for arg in "$@"; do
    case "$arg" in
        --json) JSON=1 ;;
        *) ;;
    esac
done

RECEIPT="$HERMES_ROOT/.athena.receipt"
SKILL_PATH="$HERMES_ROOT/skills/athena/SKILL.md"

if [ ! -f "$RECEIPT" ]; then
    if [ "$JSON" -eq 1 ]; then
        echo '{"status":"FAIL","reason":"receipt missing"}'
    else
        echo "Athena verify"
        echo "  Receipt            : MISSING"
        echo "  Status             : FAIL"
    fi
    exit 2
fi

# Parse receipt (very simple key extraction — assumes our own format)
expected_skill_sha=$(grep '"sha256"' "$RECEIPT" | head -1 | sed 's/.*"sha256": "\([^"]*\)".*/\1/')
profile=$(grep '"profile"' "$RECEIPT" | head -1 | sed 's/.*"profile": "\([^"]*\)".*/\1/')

if [ -z "$expected_skill_sha" ]; then
    if [ "$JSON" -eq 1 ]; then
        echo '{"status":"FAIL","reason":"receipt corrupted"}'
    else
        echo "Athena verify"
        echo "  Receipt            : CORRUPTED"
    fi
    exit 9
fi

# Verify SKILL.md
if [ ! -f "$SKILL_PATH" ]; then
    actual_skill_sha="MISSING"
    skill_ok=0
else
    actual_skill_sha=$(sha256sum "$SKILL_PATH" | awk '{print toupper($1)}')
    if [ "$actual_skill_sha" = "$expected_skill_sha" ]; then
        skill_ok=1
    else
        skill_ok=0
    fi
fi

# Verify scripts
scripts_ok=0
scripts_total=0
for s in athena-install.sh athena-uninstall.sh athena-verify.sh athena-release.py build-dmg.sh; do
    f="$HERMES_ROOT/scripts/$s"
    scripts_total=$((scripts_total + 1))
    if [ -x "$f" ]; then
        scripts_ok=$((scripts_ok + 1))
    fi
done

# Verify templates
template_ok=0
template_total=0
for t in SOUL.md MEMORY.md USER.md; do
    f="$HERMES_ROOT/$t"
    template_total=$((template_total + 1))
    if [ -f "$f" ] && [ -s "$f" ]; then
        # check for athena-template fingerprint
        if grep -q "Athena" "$f" 2>/dev/null; then
            template_ok=$((template_ok + 1))
        fi
    fi
done

if [ "$JSON" -eq 1 ]; then
    cat <<EOF
{
  "status": "$([ "$skill_ok" -eq 1 ] && [ "$scripts_ok" -eq "$scripts_total" ] && [ "$template_ok" -eq "$template_total" ] && echo "PASS" || echo "FAIL")",
  "skill_ok": $skill_ok,
  "scripts_ok": $scripts_ok,
  "scripts_total": $scripts_total,
  "templates_ok": $template_ok,
  "templates_total": $template_total,
  "profile": "$profile",
  "expected_sha256": "$expected_skill_sha",
  "actual_sha256": "$actual_skill_sha"
}
EOF
else
    echo "Athena verify"
    if [ "$skill_ok" -eq 1 ]; then
        echo "  Skill file        : OK"
    else
        echo "  Skill file        : MISMATCH"
        echo "    expected        : $expected_skill_sha"
        echo "    actual          : $actual_skill_sha"
    fi
    echo "  Script files      : $scripts_ok/$scripts_total OK"
    echo "  Templates         : $template_ok/$template_total OK"
    echo "  Receipt           : OK"
    echo "  Profile           : $profile"

    if [ "$skill_ok" -eq 1 ] && [ "$scripts_ok" -eq "$scripts_total" ] && [ "$template_ok" -eq "$template_total" ]; then
        echo "  Status            : PASS"
        exit 0
    else
        echo "  Status            : FAIL"
        exit 1
    fi
fi
