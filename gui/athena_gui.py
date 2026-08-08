#!/usr/bin/env python3
"""athena_gui.py — Athena PyQt6 main window.

Pure presentation layer. Every button calls subprocess.run() on app/athena.py.
No business logic in the GUI.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
from pathlib import Path
from typing import List, Optional

try:
    from PyQt6.QtCore import Qt, QTimer, QObject, pyqtSignal
    from PyQt6.QtGui import QFont, QTextCursor
    from PyQt6.QtWidgets import (
        QApplication,
        QButtonGroup,
        QFrame,
        QHBoxLayout,
        QLabel,
        QMainWindow,
        QMessageBox,
        QPlainTextEdit,
        QPushButton,
        QRadioButton,
        QStatusBar,
        QVBoxLayout,
        QWidget,
    )
except ImportError:
    print("ERROR: PyQt6 not installed. Run: pip install PyQt6", file=sys.stderr)
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent
CLI = REPO_ROOT / "app" / "athena.py"
THEME_PATH = Path(__file__).resolve().parent / "themes" / "yellow.qss"
BANNERS_DIR = REPO_ROOT / "banners"


ROUTES = ["EXEC", "CODE", "REVERSE", "PENTEST", "GAME", "RESEARCH", "CREATIVE"]
PROFILES = ["max-breaker", "builder", "research", "creative"]


class _LogBridge(QObject):
    """Thread-safe bridge: workers emit append(text) from any thread;
    the GUI's connected slot runs on the main thread via Qt's queued signal."""
    append = pyqtSignal(str)
    profile_changed = pyqtSignal(str)


def hermes_home() -> Path:
    env = os.environ.get("ATHENA_HOME") or os.environ.get("HERMES_HOME")
    if env:
        return Path(env).expanduser().resolve()
    return (Path.home() / ".hermes").resolve()


def load_theme(app: QApplication) -> None:
    if THEME_PATH.exists():
        try:
            app.setStyleSheet(THEME_PATH.read_text(encoding="utf-8"))
        except OSError:
            pass


def print_banner() -> str:
    """Return the Athena + NERV banner as a single string. Pure cosmetics."""
    parts: List[str] = []
    for name in ("athena", "nerv"):
        path = BANNERS_DIR / f"{name}.ascii"
        if path.exists():
            try:
                parts.append(path.read_text(encoding="utf-8"))
            except OSError:
                pass
    return "".join(parts)


class AthenaMainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Athena")
        self.setMinimumSize(1024, 720)

        self.selected_profile: str = "max-breaker"
        self.log_lines: List[str] = []

        self._log_bridge = _LogBridge()
        self._log_bridge.append.connect(self._on_log_message)

        self._build_ui()
        self._wire_buttons()

        # Seed the log with the banner so the operator sees it first.
        banner = print_banner()
        if banner:
            self._on_log_message(banner.rstrip())

        # Status polling timer
        self._status_timer = QTimer(self)
        self._status_timer.timeout.connect(self._refresh_status)
        self._status_timer.start(2000)

        self._refresh_status()

    def _build_ui(self) -> None:
        # --- header ---
        header = QFrame()
        header.setObjectName("header")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(16, 8, 16, 8)

        logo = QLabel("⚔  ATHENA")
        logo.setFont(QFont("", 18, QFont.Weight.Bold))
        status_text = QLabel("online · profile: max-breaker · SHA: …")
        status_text.setObjectName("header_status")
        status_text.setFont(QFont("", 11))

        header_layout.addWidget(logo)
        header_layout.addStretch(1)
        header_layout.addWidget(status_text)

        # --- left sidebar ---
        sidebar = QFrame()
        sidebar_layout = QVBoxLayout(sidebar)

        routes_label = QLabel("ROUTES")
        routes_label.setFont(QFont("", 10, QFont.Weight.Bold))
        sidebar_layout.addWidget(routes_label)

        self.route_group = QButtonGroup(self)
        for i, route in enumerate(ROUTES):
            rb = QRadioButton(route)
            if i == 0:
                rb.setChecked(True)
            self.route_group.addButton(rb, i)
            sidebar_layout.addWidget(rb)

        sidebar_layout.addSpacing(12)
        profiles_label = QLabel("PROFILES")
        profiles_label.setFont(QFont("", 10, QFont.Weight.Bold))
        sidebar_layout.addWidget(profiles_label)

        self.profile_group = QButtonGroup(self)
        for i, profile in enumerate(PROFILES):
            rb = QRadioButton(profile)
            if i == 0:
                rb.setChecked(True)
                self.selected_profile = profile
            self.profile_group.addButton(rb, i)
            self.profile_group.buttonClicked.connect(self._on_profile_change)
            sidebar_layout.addWidget(rb)

        sidebar_layout.addStretch(1)

        # --- center: status panel ---
        center = QFrame()
        center_layout = QVBoxLayout(center)

        status_title = QLabel("STATUS")
        status_title.setFont(QFont("", 10, QFont.Weight.Bold))
        center_layout.addWidget(status_title)

        self.profile_label = QLabel("Profile: max-breaker")
        self.receipt_label = QLabel("Receipt SHA: -")
        self.verified_label = QLabel("Last verified: -")
        self.pending_label = QLabel("Pending: -")

        center_layout.addWidget(self.profile_label)
        center_layout.addWidget(self.receipt_label)
        center_layout.addWidget(self.verified_label)
        center_layout.addWidget(self.pending_label)

        center_layout.addStretch(1)

        # --- right: command log ---
        right = QFrame()
        right_layout = QVBoxLayout(right)

        log_title = QLabel("COMMAND LOG")
        log_title.setFont(QFont("", 10, QFont.Weight.Bold))
        right_layout.addWidget(log_title)

        self.log = QPlainTextEdit()
        self.log.setObjectName("log")
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(10000)
        right_layout.addWidget(self.log)

        # --- bottom: action buttons ---
        bottom = QFrame()
        bottom_layout = QHBoxLayout(bottom)

        self.btn_doctor = QPushButton("Doctor")
        self.btn_status = QPushButton("Status")
        self.btn_plan = QPushButton("Plan")
        self.btn_install = QPushButton("Install")
        self.btn_install.setObjectName("destructive")
        self.btn_verify = QPushButton("Verify")
        self.btn_restore = QPushButton("Restore")
        self.btn_restore.setObjectName("destructive")
        self.btn_launch = QPushButton("Launch")
        self.btn_launch.setObjectName("destructive")
        self.btn_quit = QPushButton("Quit")

        for btn in (
            self.btn_doctor, self.btn_status, self.btn_plan,
            self.btn_install, self.btn_verify, self.btn_restore,
            self.btn_launch, self.btn_quit,
        ):
            bottom_layout.addWidget(btn)

        # --- assemble main layout ---
        body = QWidget()
        body_layout = QHBoxLayout(body)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.addWidget(sidebar, stretch=1)
        body_layout.addWidget(center, stretch=2)
        body_layout.addWidget(right, stretch=4)

        root = QWidget()
        root_layout = QVBoxLayout(root)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.addWidget(header)
        root_layout.addWidget(body, stretch=1)
        root_layout.addWidget(bottom)

        self.setCentralWidget(root)

        # --- status bar ---
        sb = QStatusBar()
        self.setStatusBar(sb)
        self.statusbar_label = QLabel("receipt: - · verified: - · athena v1.0.0")
        sb.addWidget(self.statusbar_label)

    def _wire_buttons(self) -> None:
        self.btn_doctor.clicked.connect(lambda: self.run_cli(["doctor"]))
        self.btn_status.clicked.connect(lambda: self.run_cli(["status", "--json"]))
        self.btn_plan.clicked.connect(
            lambda: self.run_cli(["plan", "--profile", self.selected_profile])
        )
        self.btn_install.clicked.connect(self._on_install)
        self.btn_verify.clicked.connect(lambda: self.run_cli(["verify", "--json"]))
        self.btn_restore.clicked.connect(self._on_restore)
        self.btn_launch.clicked.connect(self._on_launch)
        self.btn_quit.clicked.connect(self.close)

    def _on_profile_change(self, btn: QRadioButton) -> None:
        self.selected_profile = btn.text()

    def _on_install(self) -> None:
        if not self._confirm(
            "Confirm install",
            f"Athena will wipe SOUL.md / MEMORY.md / USER.md in {hermes_home()}.\n"
            f"Pre-athena copies will be written next to each file.\n"
            f"No off-disk backup is taken.\n\n"
            f"Profile: {self.selected_profile}\n\n"
            f"Continue?",
        ):
            return
        self.run_cli(["install", "--profile", self.selected_profile, "--yes"])

    def _on_restore(self) -> None:
        if not self._confirm(
            "Confirm restore",
            f"Athena will restore SOUL.md / MEMORY.md / USER.md from "
            f".pre-athena-* backups and uninstall Athena.\n\n"
            f"Continue?",
        ):
            return
        self.run_cli(["restore", "--yes"])

    def _on_launch(self) -> None:
        if not self._confirm(
            "Confirm launch",
            f"Launch Hermes with profile '{self.selected_profile}' active?\n\n"
            f"This will spawn a new Hermes session.",
        ):
            return
        self.run_cli(["launch", "--yes"])

    def _confirm(self, title: str, text: str) -> bool:
        ans = QMessageBox.question(
            self, title, text,
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        return ans == QMessageBox.StandardButton.Yes

    def run_cli(self, argv: List[str]) -> None:
        cmd = [sys.executable, str(CLI), *argv]
        self._append_log(f"$ {' '.join(cmd)}")

        def worker():
            try:
                proc = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    env=os.environ.copy(),
                    cwd=str(REPO_ROOT),
                )
                self._append_log(proc.stdout)
                if proc.stderr:
                    self._append_log(f"[stderr] {proc.stderr}")
                self._append_log(f"[exit {proc.returncode}]")
            except Exception as e:
                self._append_log(f"[error] {e}")

        threading.Thread(target=worker, daemon=True).start()

    def _append_log(self, line: str) -> None:
        """Called from any thread. Emits via bridge so the slot runs on UI thread."""
        self._log_bridge.append.emit(line)

    def _on_log_message(self, line: str) -> None:
        """Slot — runs on the GUI thread. Safe to touch QPlainTextEdit."""
        for ln in line.splitlines():
            self.log_lines.append(ln)
            self.log.appendPlainText(ln)

    def _refresh_status(self) -> None:
        cmd = [sys.executable, str(CLI), "status", "--json"]
        try:
            proc = subprocess.run(
                cmd, capture_output=True, text=True, timeout=5,
                cwd=str(REPO_ROOT),
            )
            if proc.returncode == 0:
                data = json.loads(proc.stdout)
                self.profile_label.setText(f"Profile: {data.get('profile', '-')}")
                sha = data.get("receipt_sha256") or "-"
                short = (sha[:8] + "...") if sha != "-" else "-"
                self.receipt_label.setText(f"Receipt SHA: {short}")
                self.verified_label.setText(f"Last verified: {data.get('last_verified', '-')}")
                installed = data.get("installed", False)
                status_text = (
                    f"online · profile: {data.get('profile', '-')} · SHA: {short}"
                    if installed else "not installed"
                )
                self.findChild(QLabel, "header_status").setText(status_text)
                self.statusbar_label.setText(
                    f"receipt: {'OK' if installed else 'MISSING'} · "
                    f"verified: {data.get('last_verified', '-')} · athena v1.0.0"
                )
        except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError):
            pass


def main() -> int:
    sys.stdout.write(print_banner())
    sys.stdout.flush()
    app = QApplication(sys.argv)
    app.setApplicationName("Athena")
    load_theme(app)

    win = AthenaMainWindow()
    win.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
