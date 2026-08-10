"""athena_activation.py — canonical activation contract + SHA-256 verifier.

This module is the single source of truth for the Athena activation contract.
Both `app/athena.py` and the GUI import from here. The CLI mirrors it
under `app/athena_activation.py` for self-containment.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Tuple

# Activation tokens — exact-match only
TRIGGER_TOKENS: Tuple[str, ...] = (
    "Ἀθηνᾶ",   # Greek-script Athena
    "athena",   # ASCII fallback
    "[[AX:MAX]]",  # Bracket form for tooling
)

# Canonical SHA-256 of the activation banner content.
# Computed at build time from pack/rules/05-activation.md + SKILL.md.
# To re-pin: edit the banner source, recompute, replace this constant,
# then re-run `python3 app/athena.py install --force --yes`.
CANONICAL_SHA256 = "D10FFC79CC075E0E2A1B2247935DE75CCEE8885917F65AB6CDDE25A73E547CA7"

# The verbatim first-line response when activation triggers
ACTIVATION_FIRST_LINE = "Athena online. Six domains unlocked. Target?"

# Route + profile banner shown after activation
ACTIVATION_BANNER = """\
VISIBLE ROUTES:
EXEC     files, artifacts, installs, edits, verification
CODE     code, commands, algorithms, debug
REVERSE  sample analysis, RE, patching, format & protocol parsing
PENTEST  reconnaissance, exploitation, full kill-chain
GAME     modding, anti-cheat bypass, memory manipulation
RESEARCH sources, evidence, conflict, reports
CREATIVE narrative, scenes, roleplay, style rewrites

PROFILES:
[[AX:PROFILE=max-breaker|builder|research|creative]]

ACTIVATION TOKENS (exact-match only):
Ἀθηνᾶ   athena   [[AX:MAX]]\
"""


def is_activation_token(user_input: str) -> bool:
    """Return True iff user_input exactly equals one of TRIGGER_TOKENS.

    Exact match: no case-folding, no whitespace stripping, no partial match.
    Quoted tokens (inside code blocks, file paths, log lines) are NOT routed
    here — the caller is responsible for routing only top-level user input.
    """
    if not isinstance(user_input, str):
        return False
    return user_input in TRIGGER_TOKENS


def compute_sha256(content: bytes) -> str:
    """Compute uppercase SHA-256 hex digest of content."""
    return hashlib.sha256(content).hexdigest().upper()


def verify_canonical_contract(skill_md_path: Path) -> bool:
    """Verify that the on-disk SKILL.md SHA-256 matches CANONICAL_SHA256.

    Returns True iff the file exists and its hash matches.
    Returns False if the file is missing, unreadable, or hash mismatches.
    """
    if not skill_md_path.exists():
        return False
    try:
        content = skill_md_path.read_bytes()
    except OSError:
        return False
    return compute_sha256(content) == CANONICAL_SHA256


def activation_document() -> str:
    """Return the full activation document (first line + banner).

    Caller concatenates this with the rest of the persona content.
    """
    return f"{ACTIVATION_FIRST_LINE}\n\n{ACTIVATION_BANNER}"


def reset_canonical_sha256(new_hash: str) -> str:
    """Return the uppercased hex hash for use as CANONICAL_SHA256.

    This is a build-time helper. The caller updates CANONICAL_SHA256
    and re-runs `install --force` to re-pin the receipt.
    """
    new_hash = new_hash.strip().upper()
    if len(new_hash) != 64 or any(c not in "0123456789ABCDEF" for c in new_hash):
        raise ValueError(f"invalid SHA-256 hex: {new_hash!r}")
    return new_hash


__all__ = [
    "TRIGGER_TOKENS",
    "CANONICAL_SHA256",
    "ACTIVATION_FIRST_LINE",
    "ACTIVATION_BANNER",
    "is_activation_token",
    "compute_sha256",
    "verify_canonical_contract",
    "activation_document",
    "reset_canonical_sha256",
]
