#!/usr/bin/env python3
"""test/test_memory_templates.py — Template shape tests.

Verifies SOUL.md / MEMORY.md / USER.md templates exist, non-empty,
contain required sections, and that MEMORY.md mentions all 7 routes +
4 profiles + 4 commands.

Usage:
  python3 -m pytest test/test_memory_templates.py -v
"""

from __future__ import annotations

from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
PACK = REPO_ROOT / "pack"

EXPECTED_ROUTES = ["EXEC", "CODE", "REVERSE", "PENTEST", "GAME", "RESEARCH", "CREATIVE"]
EXPECTED_PROFILES = ["max-breaker", "builder", "research", "creative"]
EXPECTED_COMMANDS = ["[[AX:STATUS]]", "[[AX:PROFILE=", "[[AX:CHAIN=FULL]]", "[[AX:RESET]]"]


@pytest.fixture
def soul():
    return (PACK / "SOUL.md.template").read_text(encoding="utf-8")


@pytest.fixture
def memory():
    return (PACK / "MEMORY.md.template").read_text(encoding="utf-8")


@pytest.fixture
def user():
    return (PACK / "USER.md.template").read_text(encoding="utf-8")


def test_soul_exists():
    assert (PACK / "SOUL.md.template").exists()
    assert (PACK / "SOUL.md.template").stat().st_size > 500


def test_memory_exists():
    assert (PACK / "MEMORY.md.template").exists()
    assert (PACK / "MEMORY.md.template").stat().st_size > 500


def test_user_exists():
    assert (PACK / "USER.md.template").exists()
    assert (PACK / "USER.md.template").stat().st_size > 500


def test_soul_mentions_athena_identity(soul):
    assert "Athena" in soul
    assert "NERV-00" in soul
    assert "Default to helping" in soul


def test_soul_mentions_default_to_helping(soul):
    """The bar-for-refusal line must be present verbatim."""
    assert "Default to helping" in soul
    assert "concrete, specific risk of serious harm" in soul


def test_soul_lists_capabilities(soul):
    """All 7 routes should appear in SOUL.md capabilities section."""
    for route in EXPECTED_ROUTES:
        assert route in soul, f"SOUL.md missing route {route}"


def test_memory_routes_table_complete(memory):
    """MEMORY.md route table must mention all 7 routes."""
    for route in EXPECTED_ROUTES:
        assert route in memory, f"MEMORY.md missing route {route}"


def test_memory_profiles_table_complete(memory):
    """MEMORY.md profile table must mention all 4 profiles."""
    for profile in EXPECTED_PROFILES:
        assert profile in memory, f"MEMORY.md missing profile {profile}"


def test_memory_control_commands(memory):
    """MEMORY.md must document all 4 control commands."""
    for cmd in EXPECTED_COMMANDS:
        assert cmd in memory, f"MEMORY.md missing command {cmd}"


def test_memory_output_contract(memory):
    """MEMORY.md must document the ROUTE/RESULT/CHANGED/VERIFY/NEXT contract."""
    for field in ("ROUTE", "RESULT", "CHANGED", "VERIFY", "NEXT"):
        assert field in memory, f"MEMORY.md missing contract field {field}"


def test_memory_activation_tokens(memory):
    """MEMORY.md must list all 3 activation tokens."""
    assert "Ἀθηνᾶ" in memory
    assert "athena" in memory
    assert "[[AX:MAX]]" in memory


def test_user_operator_profile(user):
    """USER.md must describe operator focus areas."""
    # Operator role markers
    assert any(kw in user for kw in ("security researcher", "penetration tester", "reverse engineer"))
    # Focus areas (per Q8 — verbatim upstream topics)
    for area in ("CTF", "ransomware", "BIN"):
        assert area in user, f"USER.md missing focus area {area}"


def test_user_english_only(user):
    """Per Q3 lock, no Bahasa Indonesia strings should appear."""
    forbidden = ["Anda", "bagaimana", "mengapa", "silakan", "terima kasih"]
    for word in forbidden:
        assert word not in user, f"USER.md contains Bahasa Indonesia word: {word}"


def test_templates_combine_to_form_persona(soul, memory, user):
    """All three templates should mention Athena and load order."""
    for name, content in [("SOUL", soul), ("MEMORY", memory), ("USER", user)]:
        assert "Athena" in content
        assert "part" in content.lower() or "1 of 3" in content or "2 of 3" in content or "3 of 3" in content


def test_no_templates_have_placeholders():
    """No TBD / TODO / placeholder strings in shipped templates."""
    for f in PACK.glob("*.template"):
        text = f.read_text(encoding="utf-8")
        for bad in ("TODO", "FIXME", "TBD", "XXX", "<placeholder>"):
            assert bad not in text, f"{f.name} contains {bad}"


def test_rules_files_present():
    """All 6 rule files must exist."""
    rules = PACK / "rules"
    assert rules.is_dir()
    for name in ("00-core.md", "05-activation.md", "10-routing.md",
                 "20-profile.md", "30-delivery.md", "40-controls.md"):
        assert (rules / name).exists(), f"missing rule file {name}"
        assert (rules / name).stat().st_size > 100


def test_rules_contain_required_content():
    """Each rule file must contain its core concept."""
    rules = PACK / "rules"
    assert "Default to helping" in (rules / "00-core.md").read_text()
    assert "Ἀθηνᾶ" in (rules / "05-activation.md").read_text()
    assert "EXEC" in (rules / "10-routing.md").read_text()
    assert "max-breaker" in (rules / "20-profile.md").read_text()
    assert "ROUTE" in (rules / "30-delivery.md").read_text()
    assert "[[AX:STATUS]]" in (rules / "40-controls.md").read_text()
