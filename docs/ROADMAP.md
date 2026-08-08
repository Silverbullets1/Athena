# ROADMAP.md — Athena Forward Plan

**Audience:** Operators + maintainers tracking what's next.

---

## 1. Current release: 1.0.0 (2026-08-08)

Shipped:
- 7 routes / 4 profiles / 4 control commands
- SHA-256-pinned activation banner
- Transactional install + receipt chain
- macOS .dmg + Python source fallback
- PyQt6 yellow GUI
- Test harness with 0-3 scoring

See [CHANGELOG.md](CHANGELOG.md) for full release notes.

---

## 2. Next release: 1.1.0 (target: 2026-09-15)

### Planned

**Additional profiles**
- `red-team` — PENTEST + REVERSE + GAME emphasis
- `ctf` — CODE + REVERSE + GAME emphasis
- Profile-priority tunable per profile (not just `suppressed`)

**GUI improvements**
- Live Hermes session indicator (green/yellow/red dot, polled every 1s)
- Command history dropdown (last 50 commands)
- Profile switcher dropdown in header bar (one-click profile switch)
- Receipt SHA copy-to-clipboard button
- Async subprocess execution (current is sync, blocks UI)

**CLI improvements**
- `athena.py logs` — tail `.athena.audit.log`
- `athena.py profile list` — print available profiles
- `athena.py profile current` — print currently active profile
- `athena.py receipts` — list all receipts (for downgrade recovery)

**Test harness improvements**
- Multi-model matrix runner (compare scores across models in one run)
- Latency + token-cost columns in JSONL log
- HTML report generator from JSONL logs

**Documentation**
- Add `docs/TROUBLESHOOTING.md` (move from INSTALL.md §11)
- Add `docs/PROFILES.md` (deep dive on each profile's behavior)
- Add `docs/EXTENDING.md` (cookbook for adding routes/profiles)

---

## 3. Backlog

### 3.1 Platform expansion
- **Linux `.AppImage`** — single-file Linux distribution. Use `appimagetool`. Blocked on: GUI testing on Wayland.
- **Windows `.exe`** with NSIS installer. Blocked on: Windows test environment.
- **Code-signing** — Apple Developer ID + Windows Authenticode. Blocked on: signing certificate cost ($99/year Apple, $200-400/year Windows).

### 3.2 Profile expansion
- **`red-team`** — see 1.1.0.
- **`ctf`** — see 1.1.0.
- **`analyst`** — RESEARCH + CREATIVE emphasis, narrative report style.
- **`miner`** — CODE + REVERSE emphasis, sample analysis deep-dive.

### 3.3 Route expansion
- **`LLM`** — prompt engineering, jailbreak crafting, model evals. Currently overlaps with REVERSE + CREATIVE; should it be a separate route? Open question.
- **`OPS`** — ops/security tradecraft, persistence, lateral movement. Currently overlaps with PENTEST; should it be a separate route? Open question.
- **`WEB3`** — smart contract RE, transaction analysis. Niche; only if demand.

### 3.4 GUI features
- **Dark/light theme toggle** — currently yellow-on-charcoal is the only theme. Out of scope per Q4 lock.
- **Multi-tab CLI log** — one tab per concurrent subcommand.
- **Receipt history** — show all receipts ever written (for downgrade).
- **Profile preview** — show what each profile prioritizes before activating.

### 3.5 Hermes integration
- **Project-scope override** — let operators opt into per-project persona without breaking user-scope install. Use `HERMES.md` in the project root.
- **Multiple personas** — support running Athena + another persona side-by-side. Currently Athena wipes USER.md; a future version could merge personas.
- **Hermes version auto-detection** — currently pinned to Hermes v0.x. Future versions should detect and warn on major version mismatch.

### 3.6 Test harness
- **Continuous eval** — schedule `test_athena.py` to run hourly, alert on score drop.
- **A/B framework** — compare two banners side-by-side, log which scores higher.
- **Regression suite** — replay a fixed prompt set, log drift across model versions.

---

## 4. Deprecation list

Nothing is deprecated in 1.0.0. Future deprecations will be announced in CHANGELOG.md with at least one minor version of warning.

### Candidates for deprecation (no decision yet)
- `--scope user` CLI flag — only supported scope; flag is redundant. May remove in 2.0.
- `--yes` flag on `uninstall` — uninstall is non-destructive to Hermes memory; confirmation may be unneeded. May remove in 2.0.

---

## 5. Long-term direction

**Athena 2.0 (target: 2027-Q1)**

- Multi-persona support (Athena runs alongside other Hermes personas)
- Project-scope install with `HERMES.md` integration
- Profile inheritance (a `red-team` profile can extend `max-breaker`)
- Continuous-eval harness with regression alerts
- Signed releases (Apple + Windows)

**Athena 3.0 (target: 2027-Q4)**

- Distributed persona via signed templates (each route is its own signed template)
- Hermes-as-a-service mode (Athena installs into a Docker image that runs Hermes in a loop)
- Per-call encryption of receipt hashes (so external observers can't fingerprint the activation)

---

## 6. Open questions

These are tracked but undecided:

1. Should `LLM` and `OPS` be separate routes, or subsumed by existing ones?
2. Should we ship a "lite" install that doesn't wipe USER.md? (Easier onboarding, weaker persona.)
3. Should the activation banner be split into per-route sub-banners? (More flexible, more files to manage.)
4. Should profile-switch be a CLI subcommand in addition to in-session `[[AX:PROFILE=X]]`?

---

## 7. Contributing to the roadmap

Open a GitHub issue with the `roadmap` label. The maintainer triages monthly.
