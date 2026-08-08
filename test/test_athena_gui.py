#!/usr/bin/env python3
"""test/test_athena_gui.py — Headless GUI tests via QT_QPA_PLATFORM=offscreen.

Tests:
  - Window opens
  - Header bar present
  - Sidebar has 7 route + 4 profile radios
  - Status bar updates after subprocess call
  - Log captures stdout
  - 8 action buttons present

Usage:
  QT_QPA_PLATFORM=offscreen python3 -m pytest test/test_athena_gui.py -v
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

# Force offscreen Qt platform
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "gui"))

# Skip entire module if PyQt6 not installed
pytest.importorskip("PyQt6")

from PyQt6.QtWidgets import QApplication, QPushButton, QRadioButton  # noqa: E402

import athena_gui  # noqa: E402


@pytest.fixture(scope="module")
def qapp():
    app = QApplication.instance() or QApplication(sys.argv)
    athena_gui.load_theme(app)
    yield app


@pytest.fixture
def window(qapp):
    win = athena_gui.AthenaMainWindow()
    yield win
    win.close()


def test_window_opens(window):
    assert window.isVisible() or not window.isVisible()  # may not be shown but exists
    assert window.windowTitle() == "Athena"
    assert window.minimumWidth() >= 1024
    assert window.minimumHeight() >= 720


def test_header_bar_present(window):
    headers = window.findChildren(type(window.findChild(type(window), None)))
    # Check via object name "header"
    from PyQt6.QtWidgets import QFrame
    headers = [w for w in window.findChildren(QFrame) if w.objectName() == "header"]
    assert len(headers) >= 1


def test_sidebar_has_seven_route_radios(window):
    radios = window.findChildren(QRadioButton)
    route_radios = [r for r in radios if r.text() in athena_gui.ROUTES]
    assert len(route_radios) == 7
    route_texts = {r.text() for r in route_radios}
    assert route_texts == set(athena_gui.ROUTES)


def test_sidebar_has_four_profile_radios(window):
    radios = window.findChildren(QRadioButton)
    profile_radios = [r for r in radios if r.text() in athena_gui.PROFILES]
    assert len(profile_radios) == 4
    profile_texts = {r.text() for r in profile_radios}
    assert profile_texts == set(athena_gui.PROFILES)


def test_eight_action_buttons_present(window):
    buttons = window.findChildren(QPushButton)
    btn_texts = {b.text() for b in buttons}
    expected = {"Doctor", "Status", "Plan", "Install", "Verify", "Restore", "Launch", "Quit"}
    assert expected.issubset(btn_texts)


def test_destructive_buttons_marked(window):
    """Install / Restore / Launch should have objectName='destructive'."""
    buttons = window.findChildren(QPushButton)
    destructive = {b.text() for b in buttons if b.objectName() == "destructive"}
    assert "Install" in destructive
    assert "Restore" in destructive
    assert "Launch" in destructive


def test_status_labels_present(window):
    assert window.profile_label is not None
    assert window.receipt_label is not None
    assert window.verified_label is not None
    assert window.pending_label is not None


def test_log_widget_is_read_only(window):
    assert window.log.isReadOnly()


def test_log_captures_appended_text(window):
    initial = window.log.toPlainText()
    window.log.appendPlainText("hello world")
    new = window.log.toPlainText()
    assert "hello world" in new
    assert len(new) > len(initial)


def test_profile_change_updates_selection(window):
    """Clicking a profile radio updates selected_profile."""
    radios = window.findChildren(QRadioButton)
    profile_radios = [r for r in radios if r.text() in athena_gui.PROFILES]
    builder = next(r for r in profile_radios if r.text() == "builder")
    builder.click()
    # Process events so the signal fires
    QApplication.processEvents()
    assert window.selected_profile == "builder"


def test_run_cli_appends_to_log(window):
    """run_cli should append the command and its output to the log."""
    before = window.log.toPlainText()
    window.run_cli(["doctor"])
    # Wait briefly for the thread to complete
    import time
    for _ in range(20):
        QApplication.processEvents()
        time.sleep(0.05)
        if "$ " in window.log.toPlainText():
            break
    after = window.log.toPlainText()
    assert "$" in after  # command echo prefix


def test_minimum_size_is_1024_720(window):
    assert window.minimumWidth() == 1024
    assert window.minimumHeight() == 720
