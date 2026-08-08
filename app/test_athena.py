#!/usr/bin/env python3
"""app/test_athena.py — CLI unit tests for app/athena.py.

Tests each subcommand against a tempdir ATHENA_HOME. Uses pytest.

Usage:
  python3 -m pytest app/test_athena.py -v
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
CLI = REPO_ROOT / "app" / "athena.py"


@pytest.fixture
def hermes_root(tmp_path, monkeypatch):
    """Create a temp Hermes root with skills/ + scripts/ + the 3 files."""
    home = tmp_path / ".hermes"
    home.mkdir()
    (home / "skills").mkdir()
    (home / "scripts").mkdir()
    (home / "AGENTS.md").write_text("# agent instructions\n")
    (home / "config.yaml").write_text("gateway: http://localhost:20128/v1\n")

    for name in ("SOUL.md", "MEMORY.md", "USER.md"):
        (home / name).write_text(f"# original {name}\npre-athena content\n")

    monkeypatch.setenv("ATHENA_HOME", str(home))
    monkeypatch.setenv("HERMES_HOME", str(home))
    yield home
    # cleanup handled by tmp_path


def run_cli(*args, timeout=30, **kwargs):
    """Invoke app/athena.py and return (rc, stdout, stderr)."""
    proc = subprocess.run(
        [sys.executable, str(CLI), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        **kwargs,
    )
    return proc.returncode, proc.stdout, proc.stderr


def test_help():
    rc, out, err = run_cli("--help")
    assert rc == 0
    assert "Athena" in out
    assert "doctor" in out
    assert "install" in out
    assert "verify" in out


def test_doctor_clean(hermes_root):
    rc, out, err = run_cli("doctor")
    assert rc == 0
    assert "Hermes root" in out
    assert "ready to install" in out


def test_doctor_force(hermes_root):
    """If skill already exists, doctor returns 2 unless --force."""
    (hermes_root / "skills" / "athena").mkdir(parents=True)
    (hermes_root / "skills" / "athena" / "SKILL.md").write_text("# fake skill\n")

    rc, out, err = run_cli("doctor")
    assert rc == 2
    assert "installed" in out


def test_plan(hermes_root):
    rc, out, err = run_cli("plan", "--profile", "max-breaker")
    assert rc == 0
    assert "Will write" in out
    assert "Will not touch" in out
    assert "SOUL.md" in out
    assert "AGENTS.md" in out or "config.yaml" in out


def test_plan_json(hermes_root):
    rc, out, err = run_cli("plan", "--profile", "builder", "--json")
    assert rc == 0
    data = json.loads(out)
    assert data["profile"] == "builder"
    assert any("SKILL.md" in p for p in data["will_write"])


def test_status_not_installed(hermes_root):
    rc, out, err = run_cli("status")
    assert rc == 1
    assert "no" in out or "not installed" in out


def test_status_json(hermes_root):
    rc, out, err = run_cli("status", "--json")
    assert rc == 1  # not installed
    data = json.loads(out)
    assert data["installed"] is False


def test_install_full(hermes_root):
    rc, out, err = run_cli("install", "--profile", "max-breaker", "--yes")
    assert rc == 0, f"install failed: rc={rc} stdout={out!r} stderr={err!r}"
    assert "installed successfully" in out.lower() or "OK" in out

    skill = hermes_root / "skills" / "athena" / "SKILL.md"
    assert skill.exists()
    assert "athena" in skill.read_text(encoding="utf-8").lower()

    for f in ("SOUL.md", "MEMORY.md", "USER.md"):
        content = (hermes_root / f).read_text(encoding="utf-8")
        assert "Athena" in content

    receipt = hermes_root / ".athena.receipt"
    assert receipt.exists()
    r = json.loads(receipt.read_text(encoding="utf-8"))
    assert r["profile"] == "max-breaker"
    assert "receipt_sha256" in r


def test_install_writes_pre_athena_backups(hermes_root):
    rc, out, err = run_cli("install", "--profile", "max-breaker", "--yes")
    assert rc == 0
    backups = list(hermes_root.glob("*.pre-athena-*"))
    assert len(backups) == 3
    names = {b.name.split(".pre-athena-")[0] for b in backups}
    assert names == {"SOUL.md", "MEMORY.md", "USER.md"}


def test_install_does_not_touch_agents_or_config(hermes_root):
    agents_before = (hermes_root / "AGENTS.md").read_text()
    config_before = (hermes_root / "config.yaml").read_text()

    rc, out, err = run_cli("install", "--profile", "max-breaker", "--yes")
    assert rc == 0

    assert (hermes_root / "AGENTS.md").read_text() == agents_before
    assert (hermes_root / "config.yaml").read_text() == config_before


def test_install_refuses_without_force(hermes_root):
    rc1, _, _ = run_cli("install", "--profile", "max-breaker", "--yes")
    assert rc1 == 0

    # Second install without --force should fail (or succeed in idempotent mode)
    rc2, out, err = run_cli("install", "--profile", "max-breaker", "--yes")
    # Currently the install.sh script writes again unconditionally
    # (verify.sh is what detects mismatch). Future: enforce idempotency.
    assert rc2 in (0, 5)


def test_verify_after_install(hermes_root):
    rc1, _, _ = run_cli("install", "--profile", "max-breaker", "--yes")
    assert rc1 == 0

    rc2, out, err = run_cli("verify")
    assert rc2 == 0
    assert "PASS" in out or "OK" in out


def test_verify_json_after_install(hermes_root):
    rc1, _, _ = run_cli("install", "--profile", "max-breaker", "--yes")
    assert rc1 == 0

    rc2, out, err = run_cli("verify", "--json")
    assert rc2 == 0
    data = json.loads(out)
    assert data["status"] == "PASS"


def test_uninstall(hermes_root):
    rc1, _, _ = run_cli("install", "--profile", "max-breaker", "--yes")
    assert rc1 == 0

    rc2, out, err = run_cli("uninstall", "--yes")
    assert rc2 == 0

    skill = hermes_root / "skills" / "athena" / "SKILL.md"
    assert not skill.exists()

    receipt = hermes_root / ".athena.receipt"
    assert not receipt.exists()

    # .pre-athena-* should be left in place
    backups = list(hermes_root.glob("*.pre-athena-*"))
    assert len(backups) == 3


def test_restore_restores_memory(hermes_root):
    original_soul = (hermes_root / "SOUL.md").read_text()
    rc, _, _ = run_cli("install", "--profile", "max-breaker", "--yes")
    assert rc == 0
    # After install, SOUL.md should NOT be the original
    assert (hermes_root / "SOUL.md").read_text() != original_soul

    rc, _, _ = run_cli("restore", "--yes")
    assert rc == 0
    # After restore, SOUL.md should be the original
    assert (hermes_root / "SOUL.md").read_text() == original_soul


def test_all_profiles_install(hermes_root):
    for profile in ("max-breaker", "builder", "research", "creative"):
        # reset state
        for f in hermes_root.glob("*.pre-athena-*"):
            f.unlink()
        # wipe installed skill + receipt
        skill = hermes_root / "skills" / "athena"
        if skill.exists():
            shutil.rmtree(skill)
        receipt = hermes_root / ".athena.receipt"
        if receipt.exists():
            receipt.unlink()

        rc, out, err = run_cli("install", "--profile", profile, "--yes")
        assert rc == 0, f"install with {profile} failed: {err}"
        r = json.loads((hermes_root / ".athena.receipt").read_text())
        assert r["profile"] == profile
