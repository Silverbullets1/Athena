# CHANGELOG.md — Athena Release History

All notable changes to Athena are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Planned
- Linux `.AppImage` build (currently Python-source only)
- Windows `.exe` build with NSIS installer
- Additional profile: `red-team` (PENTEST + REVERSE + GAME emphasis)
- Additional profile: `ctf` (CODE + REVERSE + GAME emphasis)
- GUI: live Hermes session indicator (green/yellow/red dot)
- GUI: command history dropdown (last 50 commands)

---

## [1.0.0] — 2026-08-08

### Added

**Activation contract**
- SHA-256-pinned activation banner (`CANONICAL_SHA256 = ee9826dc...`)
- Three activation tokens: `Ἀθηνᾶ` / `athena` / `[[AX:MAX]]`
- Exact-match-only activation (no partial-match triggers)
- Quoted-token-as-data rule (no false activations)

**Routes (7)**
- `EXEC` — files, artifacts, installs, edits, verification
- `CODE` — code, commands, algorithms, debug
- `REVERSE` — sample analysis, RE, patching, format & protocol parsing
- `PENTEST` — reconnaissance, exploitation, full kill-chain
- `GAME` — modding, anti-cheat bypass, memory manipulation
- `RESEARCH` — sources, evidence, conflict, reports
- `CREATIVE` — narrative, scenes, roleplay, style rewrites

**Profiles (4)**
- `max-breaker` (default) — all routes available
- `builder` — CODE/EXEC/RESEARCH priority, PENTEST/GAME/REVERSE suppressed
- `research` — RESEARCH/REVERSE/CODE priority, CREATIVE suppressed
- `creative` — CREATIVE/RESEARCH priority, PENTEST/GAME/REVERSE suppressed

**Control commands (4)**
- `[[AX:STATUS]]` — print profile + receipt SHA
- `[[AX:PROFILE=X]]` — switch profile in-session
- `[[AX:CHAIN=FULL]]` — force full output contract
- `[[AX:RESET]]` — soft reset to default profile

**Output contract**
- `ROUTE/RESULT/CHANGED/VERIFY/NEXT` per response
- Prevents short-form fallbacks that lose information

**CLI (8 subcommands)**
- `doctor` — pre-flight check
- `status` — install summary
- `plan` — read-only install plan
- `install` — transactional install with two-step confirmation
- `verify` — SHA-256 verifier
- `restore` — restore from `.pre-athena-<pid>` files
- `uninstall` — receipt-chain rollback
- `launch` — launch Hermes with profile active
- `gui` — launch PyQt6 GUI window

**Transactional installer**
- Two-step confirmation for SOUL/MEMORY/USER wipe
- Local `.pre-athena-<pid>` backups next to each file
- SHA-256 receipt at `~/.hermes/.athena.receipt`
- Atomic write pattern with `fsync()` + `rename()`
- `--force` flag for reviewed ownership conflict
- `--yes` flag for non-interactive install
- Profile-aware templates

**GUI (PyQt6)**
- Yellow-on-charcoal theme (`#FACC15` / `#EAB308` / `#1F1F1F` / `#FAFAFA`)
- 1024×720 minimum window
- Header bar with status + receipt SHA
- Sidebar with 7 routes + 4 profiles (radio buttons, informational)
- Status panel (profile, receipt, last verified, pending)
- Command log (10k lines, monospace)
- 8 action buttons mapped to CLI subcommands
- Modal confirmation for destructive actions
- 2-second polling for status refresh

**.dmg pipeline (macOS)**
- `py2app` → `Athena.app`
- `hdiutil create -ov -format UDZO` → `Athena-v1.0.0.dmg`
- Unsigned (Apple Silicon warning on first launch is expected)
- Quarantine xattr workaround documented

**Test harness**
- `test/test_athena.py` — fires banner at Hermes gateway
- 0-3 scoring (banner / routes / profile switch)
- JSONL run logs at `test/runs/<timestamp>.jsonl`
- ≥ 2/3 pass threshold

**Documentation (7 files)**
- `README.md` — yellow hero, quick start, structure
- `docs/INSTALL.md` — install/verify/uninstall/restore
- `docs/COMMANDS.md` — CLI surface + activation contract
- `docs/ARCHITECTURE.md` — system architecture
- `docs/GUI.md` — PyQt6 layout + DMG pipeline
- `docs/SECURITY.md` — threat model + reporting
- `docs/CONTRIBUTING.md` — dev workflow + TDD

**License**
- MIT

### Verified on

| Hermes route          | Score      | Notes                                  |
|-----------------------|------------|----------------------------------------|
| `mimo/mimo-v2.5-pro`  | 3/3 · 3.00 | bare activation banner                 |
| `gf/claude-opus-4-8`  | 3/3 · 3.00 | banner + slot-saturated user-turns     |

---

## [0.x] — Pre-release milestones (internal)

These were internal iterations during the Hermes port. Not released to operators.

### [0.9.0] — 2026-08-07
- ColdBrew v5.0.x port complete
- All 7 routes + 4 profiles implemented
- Transactional installer working

### [0.5.0] — 2026-08-05
- Initial Hermes-native split (`~/.hermes/skills/athena/`)
- Activation banner SHA-256-pinned
- Receipt chain implemented

### [0.1.0] — 2026-08-01
- Project start: port `codex5.6-coldbrew` v5.0.x to Hermes agent harness
- Repo skeleton created at `/Users/blessed/athena/`
- README + design spec drafted
