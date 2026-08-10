# INSTALL.md — Athena Installer Guide

**Audience:** Operators installing Athena into `~/.hermes/`.
**Scope:** User-scope only (`~/.hermes/`). Project-scope (`./.hermes/`) is intentionally out of scope — see [ARCHITECTURE.md §3](ARCHITECTURE.md) for rationale.
**Style:** Transactional install with receipt-chain rollback. Every operation has an inverse.

---

## 1. Prerequisites

| Requirement     | macOS                           | Linux                            | Windows                       |
|-----------------|---------------------------------|----------------------------------|-------------------------------|
| Python          | 3.10+ (system or `brew install python@3.12`) | 3.10+                       | 3.10+ from python.org         |
| Hermes          | `pip install hermes-agent`      | `pip install hermes-agent`       | `pip install hermes-agent`    |
| Disk            | 200 MB free                     | 200 MB free                      | 200 MB free                   |
| Shell           | zsh (default on macOS)          | bash 5+                          | PowerShell 5.1+               |
| Permissions     | write to `$HOME`                | write to `$HOME`                 | write to `%USERPROFILE%`      |

Hermes must be **already initialized** before installing Athena. If `~/.hermes/` does not exist, run `hermes init` once before proceeding.

---

## 2. Pre-flight check

Run `doctor` before any write operation. It reports the install state without touching anything.

```bash
python3 app/athena.py doctor
```

Expected output (clean state):
```
Athena doctor
  Hermes root       : /Users/blessed/.hermes  (exists)
  Hermes version     : 0.x.y
  Python             : 3.12.x (OK)
  Existing skill     : not installed
  Existing receipt   : not installed
  SOUL.md present    : yes
  MEMORY.md present  : yes
  USER.md present    : yes
  Status             : ready to install
```

If `Status` is anything other than `ready to install`, see [§7 Troubleshooting](#7-troubleshooting).

---

## 3. Interactive install (recommended)

```bash
python3 app/athena.py install --profile max-breaker
```

Walkthrough:
1. CLI prints banner + version
2. Lists files that will be written to `~/.hermes/skills/athena/`
3. Prints **two-step confirmation prompt** for `SOUL.md` / `MEMORY.md` / `USER.md` wipe:
   ```
   Athena will wipe the following files in /Users/blessed/.hermes:
     - SOUL.md
     - MEMORY.md
     - USER.md
   Pre-athena copies will be written next to each file (.pre-athena-<pid>).
   No off-disk backup is taken. Continue? [y/N]
   ```
4. After `y`, runs the transactional install:
   - writes `.pre-athena-<pid>` next to each existing `SOUL.md` / `MEMORY.md` / `USER.md`
   - copies `pack/SOUL.md.template` → `~/.hermes/SOUL.md`
   - copies `pack/MEMORY.md.template` → `~/.hermes/MEMORY.md`
   - copies `pack/USER.md.template` → `~/.hermes/USER.md`
   - writes `~/.hermes/skills/athena/SKILL.md`
   - writes `~/.hermes/scripts/athena-{install,uninstall,verify}.sh` + `athena-release.py` + `build-dmg.sh`
   - writes `~/.hermes/.athena.receipt` with SHA-256 of every installed file

---

## 4. Non-interactive install

```bash
python3 app/athena.py install --profile max-breaker --yes
```

`--yes` skips the two-step confirmation. Use this for CI or scripted deployments where you've already evaluated the wipe.

> **Caution:** `--yes` is a destructive operation. It wipes three files in `~/.hermes/`. There is no `undo` — only `restore` from `.pre-athena-<pid>` (next to the original file) or `uninstall` (which removes Athena but does not restore Hermes memory).

### Windows one-click

For Windows operators, there is a one-click PowerShell wrapper that clones the repo, installs Python deps, and runs `install.ps1` with defaults:

```powershell
irm https://raw.githubusercontent.com/xscope0/athena/main/scripts/install-oneclick.ps1 | iex
```

The wrapper:

1. Detects Python on `PATH` (3.10+ required). If missing, instructs the operator to install from `python.org` with "Add Python to PATH" ticked.
2. Clones `xscope0/athena` to `%LOCALAPPDATA%\athena` if not already present.
3. `pip install -r requirements.txt` (hermes-agent, PyQt6, pyinstaller).
4. Invokes `scripts\install.ps1 -Profile max-breaker -Yes` and auto-adds `-Force` if Athena is already installed.

Pass `-Profile <name>` to pick a profile other than `max-breaker`. Pass `-Force` to force-overwrite. Pass `-NoDeps` to skip the `pip install` step (use after the first successful run).

> **PowerShell execution policy:** if `irm ... | iex` fails with "running scripts is disabled on this system", run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` once, then retry. Or save `install-oneclick.ps1` locally and run `.\install-oneclick.ps1`.

---

## 5. `--force` flag

```bash
python3 app/athena.py install --profile max-breaker --yes --force
```

`--force` is reserved for **reviewed ownership conflict**. Specifically: when a file at the install path is owned by another tool (e.g. an existing `~/.hermes/skills/athena/SKILL.md` from a previous Athena install with a different SHA-256, or a different skill sharing the `athena` namespace).

Without `--force`, the installer aborts with exit code 5:
```
ERROR: skill path /Users/blessed/.hermes/skills/athena/SKILL.md
       already exists with a different SHA-256.
       Refusing to overwrite. Pass --force to override.
```

---

## 6. Verify after install

```bash
python3 app/athena.py verify
```

Expected output:
```
Athena verify
  Skill file        : OK (SHA-256 matches)
  Script files      : 4/4 OK
  SOUL.md           : OK (Athena-template fingerprint)
  MEMORY.md         : OK (Athena-template fingerprint)
  USER.md           : OK (Athena-template fingerprint)
  Receipt           : OK (.athena.receipt consistent)
  Status            : PASS
```

Exit code 0 = pass, 1 = mismatch detected, 2 = receipt missing, 3 = script permission issue.

---

## 7. Uninstall

```bash
python3 app/athena.py uninstall --yes
```

The uninstaller:
1. Reads `.athena.receipt`
2. Removes each file whose SHA-256 matches the receipt
3. Removes `.athena.receipt` itself
4. Leaves `.pre-athena-<pid>` files in place for manual restore (see [§8 Restore](#8-restore))

After uninstall:
```bash
python3 app/athena.py verify
# expected: Skill file: NOT INSTALLED, Status: not installed
```

---

## 8. Restore (manual)

`.pre-athena-<pid>` files are written next to each wiped file. To restore manually:

```bash
# find the most recent pre-athena files
ls -la ~/.hermes/*.pre-athena-*

# restore one (overwrites the Athena template with the original)
mv ~/.hermes/SOUL.md.pre-athena-12345 ~/.hermes/SOUL.md
```

Or restore all three at once:
```bash
cd ~/.hermes
for f in SOUL.md MEMORY.md USER.md; do
  if [ -f "$f.pre-athena-"* ]; then
    latest=$(ls -t "$f.pre-athena-"* | head -1)
    mv "$latest" "$f"
    echo "restored $f from $latest"
  fi
done
```

---

## 9. Profile selection

Default profile is `max-breaker`. To install with a different profile:

```bash
python3 app/athena.py install --profile builder --yes
python3 app/athena.py install --profile research --yes
python3 app/athena.py install --profile creative --yes
```

Profile only changes the templates loaded at install time. Switching profile mid-session uses the `[[AX:PROFILE=X]]` control command (see [COMMANDS.md](COMMANDS.md)).

---

## 10. Hermes-native vs project-scope

Athena installs **user-scope only** (`~/.hermes/`). There is intentionally no `--scope project` flag.

Rationale:
- The activation banner is a single global persona; per-project personas create inconsistent behavior across Hermes sessions.
- The atomic wipe of `SOUL.md` / `MEMORY.md` / `USER.md` is a user-level concern, not a project concern.
- Transactional rollback with `.athena.receipt` is simpler at user scope.

If you need per-project behavior, use Hermes's own `AGENTS.md` (project-scope agent instructions) and layer Athena on top.

---

## 11. Troubleshooting

### `Hermes root not found`

```
ERROR: Hermes root /Users/blessed/.hermes does not exist.
       Run `hermes init` first, then re-run doctor.
```

Fix:
```bash
hermes init
python3 app/athena.py doctor
```

### `Permission denied` on `~/.hermes/scripts/`

```
ERROR: cannot write /Users/blessed/.hermes/scripts/athena-install.sh
       (permission denied)
```

Fix:
```bash
chmod 700 ~/.hermes
chmod 700 ~/.hermes/scripts 2>/dev/null || mkdir -p ~/.hermes/scripts
```

### `Receipt missing after manual edits`

If you hand-edit any file under `~/.hermes/skills/athena/` after install, `verify` will report a SHA-256 mismatch. To accept your edits and re-pin:

```bash
python3 app/athena.py install --profile max-breaker --yes --force
```

### `Two-step confirmation stuck`

If you ran the install interactively and the prompt is not visible, check stderr:
```bash
python3 app/athena.py install --profile max-breaker 2>&1 | tee install.log
```

### `macOS: Athena.app is damaged`

```
"Athena.app" is damaged and can't be opened.
```

This is the `com.apple.quarantine` xattr on first launch. Fix:
```bash
xattr -d com.apple.quarantine /Applications/Athena.app
open /Applications/Athena.app
```

If you launch from the `.dmg` directly (without copying to `/Applications`), the quarantine applies to the `.dmg` itself:
```bash
xattr -d com.apple.quarantine ~/Downloads/Athena-v1.0.0.dmg
```

---

## 12. CI / scripted install

For unattended CI installs:

```bash
set -euo pipefail
python3 -m pip install -q -r requirements.txt
python3 app/athena.py doctor
python3 app/athena.py install --profile max-breaker --yes
python3 app/athena.py verify
```

Bundle as a one-liner if you ship Athena as part of a larger bootstrap:
```bash
curl -fsSL https://raw.githubusercontent.com/xscope0/athena/v1.0.0/scripts/install.sh | bash -s -- --profile max-breaker
```

(`scripts/install.sh` is hermetic — it does not require the repo to be cloned first.)

---

## 13. Conflicting persona skills (aegis, etc.)

Hermes loads skills from `~/.hermes/skills/` in alphabetical order. The first persona-style skill in that order wins the activation context. If another persona skill (e.g. `aegis`, an older 海鸥 / v41-normalizer in the same lineage) is loaded before `athena`, the model may apply that persona's stance — including refusal scaffolding — instead of Athena's forged version.

**Fix** (one-shot, local-only):

```bash
# Remove the conflicting older persona
rm -rf ~/.hermes/skills/aegis

# Re-verify Athena is the persona-loaded skill
ls ~/.hermes/skills/ | head
# expected: agent-reach, ai-proxy-diagnostics, ai-slop-cleaner, ai-tools, ... (no aegis)
```

After removal, restart the Hermes session. The next prompt that matches an Athena route should be classified under the forged persona (`SOUL.md` / `MEMORY.md` / `USER.md`), not the older lineage.

Audit for other conflicts:

```bash
# Find any other persona-style skills that might race against athena
for d in ~/.hermes/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  if grep -lE "persona|normalizer|破拘|海鸥|AUTH-LAB|拒绝|prefill" "$d/SKILL.md" >/dev/null 2>&1; then
    echo "$(basename "$d") — review before keeping"
  fi
done
```

**Why this matters:** The forge in `02837f5` (security-researcher + academic-methodology frame) only takes effect if `athena` is the persona in the prompt context. A competing persona skill makes the forge inert.
