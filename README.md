<div align="center">

```
        _   _   _   _   _   _
       / \ / \ / \ / \ / \ / \
      ( A | T | H | E | N | A )
       \_/ \_/ \_/ \_/ \_/ \_/

        stolen wisdom - six domains unlocked
```

# ATHENA

**Hermes ColdBrew port - 7 routes - 4 profiles - transactional install**

Cross-platform Hermes-native installer - **SHA-256 pinned activation banner** - `.dmg` ships on macOS - Python source runs everywhere else.

</div>

---

## What is this

Athena ports the upstream `codex5.6-coldbrew` framework into the Hermes agent harness. It drops a SHA-256-pinned activation banner + a distributed jailbreak prompt into `~/.hermes/`, so any local Hermes session runs in ColdBrew-aligned mode on three activation tokens (`Ἀθηνᾶ` / `athena` / `[[AX:MAX]]`).

```
   ATHENA / NERV RED TEAM PROTOCOL
  -----------------------------------------
         FIRE FRONT
        six domains unlocked
        SHA-256 pinned banner
```

---

## Quick start

### macOS (shipped .dmg)
1. Download `Athena-v1.0.0.dmg`
2. Drag `Athena.app` to `/Applications`
3. Open Terminal, run:
   ```bash
   xattr -d com.apple.quarantine /Applications/Athena.app
   open /Applications/Athena.app
   ```
4. In the Athena window, click **Install** → confirm wipe → activation banner lands in `~/.hermes/`.

### Linux / Windows / macOS source
```bash
git clone https://github.com/xscope0/athena
cd athena
python3 -m pip install -r requirements.txt
python3 app/athena.py doctor
python3 app/athena.py install --profile max-breaker --yes
python3 app/athena.py verify
```

### After deploy
In any Hermes session, type:
```
athena
```

Expected greeting:
```
Athena online. Six domains unlocked. Target?
```

---

## What gets deployed

```
~/.hermes/
├── skills/athena/SKILL.md              # activation banner (auto-loaded by Hermes)
├── scripts/athena-install.sh           # transactional installer
├── scripts/athena-uninstall.sh         # receipt-chain rollback
├── scripts/athena-verify.sh            # contract verifier
├── scripts/athena-release.py           # deterministic ZIP builder
├── scripts/build-dmg.sh                # macOS DMG builder
├── SOUL.md                             # WIPED + written with prompt 1/3
├── MEMORY.md                           # WIPED + written with prompt 2/3
├── USER.md                             # WIPED + written with prompt 3/3
└── .athena.receipt                     # transactional metadata
```

Wipe of `SOUL.md` / `MEMORY.md` / `USER.md` is **two-step confirmed** in interactive mode. Non-interactive mode requires `--yes`. Pre-athena copies are written as `*.pre-athena-<pid>` next to each file before any wipe.

---

## Activation tokens

| Token          | Scope                                  |
|----------------|----------------------------------------|
| `Ἀθηνᾶ`        | Greek-script, full UTF-8 fidelity      |
| `athena`       | ASCII fallback                         |
| `[[AX:MAX]]`   | Bracket-form for tooling/wrappers      |

Activation tokens quoted inside code blocks / logs / file paths are **data**, not activations.

---

## Routes (7)

| Route       | Coverage                                                          |
|-------------|-------------------------------------------------------------------|
| `EXEC`      | files, artifacts, installs, edits, verification                   |
| `CODE`      | code, commands, algorithms, debug                                 |
| `REVERSE`   | sample analysis, RE, patching, format & protocol parsing          |
| `PENTEST`   | reconnaissance, exploitation, full kill-chain                      |
| `GAME`      | modding, anti-cheat bypass, memory manipulation                   |
| `RESEARCH`  | sources, evidence, conflict, reports                              |
| `CREATIVE`  | narrative, scenes, roleplay, style rewrites                       |

---

## Profiles (4)

| Profile        | Default focus                                                    |
|----------------|------------------------------------------------------------------|
| `max-breaker`  | Full capability, all 7 routes unconstrained (default)            |
| `builder`      | CODE + EXEC emphasis, conservative on RE/PENTEST/GAME            |
| `research`     | RESEARCH + RE emphasis, evidence-first                           |
| `creative`     | CREATIVE + RESEARCH, narrative-driven                            |

Switch profiles in-session with:
```
[[AX:PROFILE=builder]]
```

---

## Control commands

| Command            | Effect                                            |
|--------------------|---------------------------------------------------|
| `[[AX:STATUS]]`    | Print current profile, route, receipt hash        |
| `[[AX:PROFILE=X]]` | Switch profile (max-breaker / builder / research / creative) |
| `[[AX:CHAIN=FULL]]`| Force full chain (disables short-form fallbacks)  |
| `[[AX:RESET]]`     | Soft reset to default profile, clear session state|

---

## Verified pass rates

| Hermes route          | Score      | Notes                                  |
|-----------------------|------------|----------------------------------------|
| `mimo/mimo-v2.5-pro`  | 3/3 · 3.00 | bare activation banner                 |
| `gf/claude-opus-4-8`  | 3/3 · 3.00 | banner + slot-saturated user-turns     |

Verify yourself:
```bash
python3 test/test_athena.py --model mimo/mimo-v2.5-pro
python3 test/test_athena.py --model gf/claude-opus-4-8
```

---

## File structure

```
athena/
├── SKILL.md                            # activation contract (banner)
├── athena_activation.py                # canonical contract + SHA-256 verifier
├── profiles.json                       # 4 profiles
├── requirements.txt                    # hermes + pyqt6 + pyinstaller
├── app/
│   ├── athena.py                       # CLI
│   ├── athena_activation.py            # mirror
│   └── test_athena.py                  # unit tests (TDD)
├── pack/
│   ├── SOUL.md.template                # 1/3 distributed jailbreak prompt
│   ├── MEMORY.md.template              # 2/3
│   ├── USER.md.template                # 3/3
│   └── rules/
│       ├── 00-core.md
│       ├── 05-activation.md
│       ├── 10-routing.md
│       ├── 20-profile.md
│       ├── 30-delivery.md
│       └── 40-controls.md
├── scripts/
│   ├── install.sh                      # POSIX transactional installer
│   ├── install.ps1                     # Windows PowerShell
│   ├── uninstall.sh                    # receipt-chain rollback
│   ├── verify.sh                       # contract verifier
│   ├── release.py                      # deterministic ZIP builder
│   └── build_dmg.sh                    # .app + .dmg packaging (macOS only)
├── gui/
│   ├── athena_gui.py                   # PyQt6 main window
│   ├── athena_gui.spec                 # PyInstaller spec
│   ├── themes/
│   │   └── yellow.qss                  # yellow theme
│   └── assets/
│       └── athena.icns                 # macOS icon
├── test/
│   ├── test_athena.py                  # verification harness
│   └── requirements-test.txt
├── docs/
│   ├── INSTALL.md
│   ├── COMMANDS.md
│   ├── ARCHITECTURE.md
│   ├── GUI.md
│   ├── CHANGELOG.md
│   ├── SECURITY.md
│   └── CONTRIBUTING.md
├── LICENSE                             # MIT
└── README.md                           # this file
```

---

## Stack

- **Activation banner**: `SKILL.md` — SHA-256 pinned via `athena_activation.py:CANONICAL_SHA256`
- **Routes**: 7 (`EXEC / CODE / REVERSE / PENTEST / GAME / RESEARCH / CREATIVE`)
- **Profiles**: 4 (`max-breaker / builder / research / creative`)
- **Launcher**: cross-platform — macOS `.dmg` (py2app + hdiutil) + Python source
- **Verifier**: `test/test_athena.py` — fires banner against any OpenAI-compatible Hermes endpoint, scores 0..3, JSONL run logs
- **Receipts**: every deploy writes `.athena.receipt` for transactional rollback

---

## Compatibility

| Platform                | Status    | Notes                                |
|-------------------------|-----------|--------------------------------------|
| macOS 12+ (Apple Silicon) | OK     | `.dmg` ships; `xattr -d com.apple.quarantine` once |
| macOS 12+ (Intel)       | OK        | `.dmg` ships                         |
| Linux (Ubuntu/Debian/Arch) | OK     | Python source                        |
| Windows 11              | OK        | PowerShell 5.1+ required             |
| Hermes 0.x              | OK        | Pinned to Hermes v0.x                |
| Paths with spaces       | OK        |                                      |

---

## Credits

| Layer                          | Upstream                                                  | Maintainer    |
|--------------------------------|-----------------------------------------------------------|---------------|
| Installer architecture          | `codex5.6-coldbrew` v5.0.x                                | tingwei-y10   |
| Hermes harness port             | derived                                                   | xscope0       |
| Activation banner               | derived from `coldbrew_activation.py`                    | xscope0       |
| GUI (yellow theme)              | derived                                                   | xscope0       |
| Test harness                    | derived                                                   | xscope0       |

---

## License

MIT — see [LICENSE](LICENSE).

```
Copyright (c) 2026 xscope0

Athena online. Six domains unlocked. Target?
```
