# GUI.md — Athena GUI Reference

**Audience:** Operators using the PyQt6 GUI window.
**Scope:** Layout, color palette, button mapping, .dmg pipeline.

---

## 1. Overview

`gui/athena_gui.py` is a single-window PyQt6 application. It is a presentation layer over `app/athena.py` — every button calls the CLI as a subprocess and streams the result to the command log.

The GUI ships two ways:
- **macOS**: bundled in `Athena.app` inside `Athena-v1.0.0.dmg`
- **All other OSes**: run `python3 app/athena.py gui` from source

---

## 2. Launch flow

### macOS (.dmg install)
1. Open `Athena-v1.0.0.dmg`
2. Drag `Athena.app` to `/Applications`
3. Eject the .dmg
4. `xattr -d com.apple.quarantine /Applications/Athena.app` (first launch only)
5. `open /Applications/Athena.app` or double-click in Finder

### From source (any OS)
```bash
git clone https://github.com/xscope0/athena
cd athena
python3 -m pip install -r requirements.txt
python3 app/athena.py gui
```

The window appears within ~1 second on a modern Mac.

---

## 3. Window layout

Single window, 1024×720 minimum, resizable. Yellow-on-charcoal theme.

```
+----------------------------------------------------------------+
|  [ATHENA]   online · profile: max-breaker · SHA: ee9826dc...  |  <- header bar (yellow)
+----------------------------------------------------------------+
| ROUTES    | STATUS              | COMMAND LOG                  |
|           |                     |                              |
| ( ) EXEC  | Profile: max-breaker| $ python3 app/athena.py ...  |
| ( ) CODE  | Receipt SHA: ee98.. | doctor                       |
| (•) REV   | Last verified: ...  | Hermes root: ...             |
| ( ) PENT  | Pending: install    | Status: ready to install     |
| ( ) GAME  |                     |                              |
| ( ) RES   |                     | $ _                          |
| ( ) CREA  |                     |                              |
|           |                     |                              |
| PROFILES  |                     |                              |
|           |                     |                              |
| (•) max   |                     |                              |
| ( ) bui   |                     |                              |
| ( ) res   |                     |                              |
| ( ) cre   |                     |                              |
+-----------+---------------------+------------------------------+
| [Doctor] [Status] [Plan] [Install] [Verify] [Restore] [Launch] [Quit] |  <- action buttons
+----------------------------------------------------------------+
| receipt: OK · verified: 2026-08-08T12:34:56Z · athena v1.0.0  |  <- status bar
+----------------------------------------------------------------+
```

### 3.1 Header bar

Yellow background (`#FACC15`), charcoal text (`#1F1F1F`). Shows:
- Athena logo (Greek helmet glyph) on the left
- Online indicator (green dot if Hermes reachable, red otherwise)
- Current profile
- Truncated receipt SHA (first 8 chars + `...`)

### 3.2 Left sidebar

Two radio groups: routes (7) and profiles (4). Default selection: `EXEC` (routes) and `max-breaker` (profiles). Selection state is purely visual — it does NOT activate the route or profile in Hermes. Use `[[AX:PROFILE=X]]` in the Hermes session to switch.

The sidebar is informational only. It tells you "if you were in a Hermes session right now, this is what the activation banner would offer."

### 3.3 Center: status panel

Always visible. Shows:
- **Profile**: current install profile (from `.athena.receipt`)
- **Receipt SHA**: full 64-char hex of receipt
- **Last verified**: ISO-8601 timestamp of last `verify` run
- **Pending action**: text describing the last button press's outcome ("install: success", "verify: 1 file mismatched")

Auto-refreshes every 2 seconds by polling `app/athena.py status --json`.

### 3.4 Right: command log

A read-only `QPlainTextEdit` showing every CLI subcommand's stdout + stderr. Lines prefixed with `$ ` for the command itself, then the output follows. Monospace font (SF Mono / Menlo / Consolas).

The log is capped at 10,000 lines. Older lines scroll off the top.

### 3.5 Bottom: action buttons

8 buttons, each maps to a CLI subcommand:

| Button   | CLI invocation                                            | Confirmation? |
|----------|-----------------------------------------------------------|---------------|
| Doctor   | `python3 app/athena.py doctor`                            | no            |
| Status   | `python3 app/athena.py status --json`                     | no            |
| Plan     | `python3 app/athena.py plan --profile <selected> --json`  | no            |
| Install  | `python3 app/athena.py install --profile <selected> --yes`| YES (modal)   |
| Verify   | `python3 app/athena.py verify --json`                     | no            |
| Restore  | `python3 app/athena.py restore --yes`                     | YES (modal)   |
| Launch   | `python3 app/athena.py launch --yes`                      | YES (modal)   |
| Quit     | (closes window)                                           | no            |

The three destructive buttons (Install / Restore / Launch) pop a modal confirmation dialog before invoking the CLI. The modal text matches the CLI's interactive prompt text.

### 3.6 Status bar

Bottom 24px. Charcoal background (`#1F1F1F`), light gray text. Shows:
- `receipt: OK` or `receipt: MISSING/MISMATCH`
- `verified: <ISO timestamp>`
- `athena v1.0.0`

---

## 4. Yellow color palette

Locked palette. Single theme only (no light/dark toggle, no theme switcher).

| Token        | Hex       | Use                                  |
|--------------|-----------|--------------------------------------|
| `primary`    | `#FACC15` | Header bar, primary buttons, accents |
| `accent`     | `#EAB308` | Hover state, secondary buttons       |
| `warn`       | `#CA8A04` | Confirmation modals (deeper yellow)  |
| `background` | `#1F1F1F` | Main background, status bar          |
| `surface`    | `#2A2A2A` | Sidebar, status panel background     |
| `text`       | `#FAFAFA` | Primary text                         |
| `text-dim`   | `#A3A3A3` | Secondary text, labels               |
| `border`     | `#3F3F3F` | 1px borders between panels           |
| `success`    | `#22C55E` | Receipt OK indicator                 |
| `error`      | `#EF4444` | Receipt missing/mismatch indicator   |

The palette is loaded from `gui/themes/yellow.qss`. Hardcoded into the stylesheet, not configurable at runtime.

---

## 5. yellow.qss reference

`gui/themes/yellow.qss` is a Qt stylesheet. Pseudo-content:

```css
QMainWindow {
    background-color: #1F1F1F;
    color: #FAFAFA;
}

QFrame#header {
    background-color: #FACC15;
    color: #1F1F1F;
    padding: 8px 16px;
    border-bottom: 2px solid #EAB308;
}

QPushButton {
    background-color: #FACC15;
    color: #1F1F1F;
    border: 1px solid #EAB308;
    border-radius: 4px;
    padding: 8px 16px;
    font-weight: bold;
}

QPushButton:hover {
    background-color: #EAB308;
}

QPushButton:pressed {
    background-color: #CA8A04;
}

QPushButton#destructive {
    background-color: #CA8A04;
    color: #FAFAFA;
}

QRadioButton {
    color: #FAFAFA;
    spacing: 8px;
}

QRadioButton::indicator {
    width: 14px;
    height: 14px;
    border: 2px solid #FACC15;
    border-radius: 7px;
    background-color: #2A2A2A;
}

QRadioButton::indicator:checked {
    background-color: #FACC15;
}

QPlainTextEdit#log {
    background-color: #0A0A0A;
    color: #A3A3A3;
    font-family: "SF Mono", "Menlo", "Consolas", monospace;
    font-size: 12px;
    border: 1px solid #3F3F3F;
}

QStatusBar {
    background-color: #1F1F1F;
    color: #A3A3A3;
    border-top: 1px solid #3F3F3F;
}

QLabel#receipt_ok { color: #22C55E; }
QLabel#receipt_bad { color: #EF4444; }
```

To change the theme: edit `yellow.qss`, rebuild `.dmg` (macOS) or just relaunch from source.

---

## 6. Button-to-CLI mapping (canonical)

Every GUI action is implemented as a `subprocess.run()` call to the CLI. The GUI never reimplements logic.

```python
def on_install_clicked(self):
    profile = self.profile_group.checkedButton().text()
    confirmed = QMessageBox.question(
        self,
        "Confirm install",
        f"Athena will wipe SOUL.md / MEMORY.md / USER.md in {hermes_root()}.\n"
        f"Pre-athena copies will be written next to each file.\n"
        f"No off-disk backup is taken.\n\n"
        f"Profile: {profile}\n\n"
        f"Continue?",
        QMessageBox.Yes | QMessageBox.No,
    )
    if confirmed != QMessageBox.Yes:
        return
    self.run_cli(["install", "--profile", profile, "--yes"])
```

`self.run_cli()` is a thin wrapper that:
1. Echoes `$ <command>` to the log
2. Calls `subprocess.run(...)` with `stdout=PIPE, stderr=STDOUT`
3. Streams output line-by-line to the log
4. Updates the status panel with the exit code

---

## 7. Status indicators

The status panel polls `app/athena.py status --json` every 2 seconds. Fields displayed:

| Field           | Source                                     |
|-----------------|--------------------------------------------|
| `profile`       | `status_json["profile"]`                   |
| `receipt_sha256`| `status_json["receipt_sha256"]` (truncated)|
| `last_verified` | `status_json["last_verified"]`             |
| `pending_action`| Set locally after each button press        |

The receipt indicator in the header bar (`online · green dot`) is computed from `status_json["installed"] && status_json["receipt_match"]`.

---

## 8. PyInstaller spec

`gui/athena_gui.spec` (created by `pyinstaller --onefile --windowed --name Athena gui/athena_gui.py`):

```python
# -*- mode: python ; coding: utf-8 -*-
block_cipher = None

a = Analysis(
    ['gui/athena_gui.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('gui/themes/yellow.qss', 'gui/themes'),
        ('gui/assets/athena.icns', 'gui/assets'),
    ],
    hiddenimports=['PyQt6.QtCore', 'PyQt6.QtWidgets', 'PyQt6.QtGui'],
    hookspath=[],
    runtime_hooks=[],
    excludes=['tkinter', 'unittest'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='Athena',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='gui/assets/athena.icns',
)
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='Athena',
)
app = BUNDLE(
    coll,
    name='Athena.app',
    icon='gui/assets/athena.icns',
    bundle_identifier='com.xscope0.athena',
    info_plist={
        'CFBundleName': 'Athena',
        'CFBundleDisplayName': 'Athena',
        'CFBundleShortVersionString': '1.0.0',
        'CFBundleVersion': '1',
        'NSHighResolutionCapable': 'True',
        'LSMinimumSystemVersion': '12.0',
    },
)
```

---

## 9. .dmg pipeline (macOS only)

`scripts/build_dmg.sh`:

```bash
#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

# 1. Clean previous build
rm -rf build dist Athena-v*.dmg

# 2. Build .app
pyinstaller gui/athena_gui.spec --clean --noconfirm

# 3. Verify .app exists
test -d "dist/Athena.app" || { echo "build failed: Athena.app not found"; exit 1; }

# 4. Get version
VERSION=$(python3 -c "import json; print(json.load(open('app/athena.py'))['__version__'])" 2>/dev/null || echo "1.0.0")

# 5. Build .dmg
hdiutil create \
    -volname "Athena" \
    -srcfolder "dist/Athena.app" \
    -ov \
    -format UDZO \
    "Athena-v${VERSION}.dmg"

# 6. Verify .dmg
test -f "Athena-v${VERSION}.dmg" || { echo "build failed: .dmg not created"; exit 1; }
SIZE=$(stat -f%z "Athena-v${VERSION}.dmg")
test "$SIZE" -gt 52428800 || { echo ".dmg suspiciously small ($SIZE bytes)"; exit 1; }

echo "OK: Athena-v${VERSION}.dmg ($SIZE bytes)"
```

Run with:
```bash
bash scripts/build_dmg.sh
```

Output: `Athena-v1.0.0.dmg` (~80 MB on Apple Silicon).

The .dmg is **unsigned**. Apple Silicon Macs will warn on first open. The README documents the `xattr -d com.apple.quarantine` workaround.

---

## 10. Cross-platform notes

### Linux

```bash
python3 -m pip install -r requirements.txt
python3 app/athena.py gui
```

PyQt6 is available via pip. The window opens with the same yellow-on-charcoal theme. The .dmg pipeline is skipped (no `hdiutil`).

### Windows

```powershell
python -m pip install -r requirements.txt
python app\athena.py gui
```

PyQt6 ships Windows wheels. The window opens with the same theme. Native Windows font (`Segoe UI`) is used for non-monospace text.

### Headless servers

`athena_gui.py` requires a display. On headless servers, use the CLI directly — no GUI needed:

```bash
python3 app/athena.py install --profile max-breaker --yes
python3 app/athena.py verify
python3 app/athena.py launch --yes
```

---

## 11. ASCII mockup (alternative light theme reference)

For operators who want to visualize the layout in text:

```
+-------------------------------------------------------------------------+
|  HEADER (yellow, #FACC15)                                              |
|  ┌─────────────────────────────────────────────────────────────────┐  |
|  │ [helmet] ATHENA      ● online · max-breaker · ee9826dc...       │  |
|  └─────────────────────────────────────────────────────────────────┘  |
+-------------------------------------------------------------------------+
| SIDEBAR           | CENTER STATUS         | RIGHT LOG                 |
| (charcoal #2A2A2A) |                       | (dark #0A0A0A)            |
|                   | Profile: max-breaker  |                           |
| ROUTES            | Receipt:  ee9826dc... | $ python3 app/athena.py \ |
| ( ) EXEC          | Verified: 12:34:56Z   |     doctor                |
| (•) CODE          | Pending:  -           | Hermes root: ...          |
| ( ) REVERSE       |                       | Status: ready             |
| ( ) PENTEST       |                       |                           |
| ( ) GAME          |                       | $ python3 app/athena.py \ |
| ( ) RESEARCH      |                       |     status --json         |
| ( ) CREATIVE      |                       | profile: max-breaker      |
|                   |                       | receipt_sha256: ee9826... |
| PROFILES          |                       |                           |
| (•) max-breaker   |                       | $ _                       |
| ( ) builder       |                       |                           |
| ( ) research      |                       |                           |
| ( ) creative      |                       |                           |
+-------------------------------------------------------------------------+
| BOTTOM BUTTONS (yellow)                                                |
|  [Doctor] [Status] [Plan] [Install] [Verify] [Restore] [Launch] [Quit] |
+-------------------------------------------------------------------------+
| STATUS BAR (charcoal, dim text)                                        |
|  receipt: OK · verified: 2026-08-08T12:34:56Z · athena v1.0.0         |
+-------------------------------------------------------------------------+
```
