# CONTRIBUTING.md — Athena Development Workflow

**Audience:** Engineers extending or auditing Athena.
**Style:** TDD discipline, terse, operator-focused.

---

## 1. Code of conduct

This is a developer tool. Treat it as one. Disagreement is welcome; rudeness is not.

If your contribution changes the activation banner, the route table, the profile table, or the receipt format, you are changing the operator-facing contract. Document it explicitly in the PR.

---

## 2. Dev setup

```bash
git clone https://github.com/xscope0/athena
cd athena

# Create venv
python3 -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\activate on Windows

# Install deps
python3 -m pip install -r requirements.txt
python3 -m pip install -r test/requirements-test.txt

# Verify install
python3 app/athena.py doctor
```

For GUI work, also `python3 -m pip install pyqt6 pyinstaller`.

For .dmg work, also `brew install hdiutil` (preinstalled on macOS).

---

## 3. TDD discipline (per phase)

Every phase follows RED → GREEN → REFACTOR:

1. **RED**: Write the test first. Run it. Confirm it fails for the right reason.
2. **GREEN**: Write the minimum implementation that passes the test.
3. **REFACTOR**: Clean up the implementation. Tests still pass.

Per the locked 7 phases:

| Phase | Artifact (RED)                                  | Implementation (GREEN)                  |
|-------|--------------------------------------------------|------------------------------------------|
| 1     | `app/test_athena_activation.py`                  | `app/athena_activation.py`               |
| 2     | `test/test_install_script.sh`                    | `scripts/install.sh` + uninstall + verify|
| 3     | `app/test_athena_cli.py`                         | `app/athena.py`                          |
| 4     | `test/test_memory_templates.py`                  | `pack/SOUL.md.template` + MEMORY + USER  |
| 5     | `test/test_athena_gui.py` (headless QTest)       | `gui/athena_gui.py`                      |
| 6     | `test/test_build_dmg.sh`                         | `scripts/build_dmg.sh`                   |
| 7     | `test/test_harness.py`                           | `test/test_athena.py` (live gateway)     |

Coverage target: ≥ 80% on `app/` and `gui/`. Shell scripts: every code path covered by `test_install_script.sh` and `test_build_dmg.sh`.

### 3.1 Anti-pattern guardrails

- No `TODO` / `FIXME` / placeholder comments standing in for real logic
- No `test.skip` / `.only` / stubbed assertions
- No "this should work" claims — every assertion is runnable
- No unimplemented branches, `throw new Error("not implemented")`, silent empty catches
- No hardcoded values masquerading as computed results

---

## 4. Adding a new route

1. **Edit `MEMORY.md.template`** — add the new route to the route table.
2. **Edit `pack/rules/10-routing.md`** — add the route description and priority.
3. **Edit `gui/athena_gui.py`** — add a new `QRadioButton` to the routes group.
4. **Edit `test/test_athena.py`** — add a probe that checks the route name appears in the response.
5. **Bump version** in `athena_activation.py:CANONICAL_SHA256` (the SHA-256 changes because the rules change).
6. **Re-install** with `python3 app/athena.py install --profile <X> --yes --force`.
7. **Verify** with `python3 test/test_athena.py` — score should still be ≥ 2/3.

---

## 5. Adding a new profile

1. **Edit `MEMORY.md.template`** — add the profile to the profile table.
2. **Edit `pack/rules/20-profile.md`** — add profile priority + suppression logic.
3. **Edit `gui/athena_gui.py`** — add a new `QRadioButton` to the profiles group.
4. **Edit `test/test_athena.py`** — add a probe for `[[AX:PROFILE=<NEW>]]` switch.
5. **Bump version + re-pin** as in §4.

---

## 6. Changing the activation banner (SHA-256 re-pin ceremony)

The banner is SHA-256-pinned. Changing it requires:

```bash
# 1. Edit the canonical banner source
$EDITOR pack/rules/05-activation.md

# 2. Recompute the SHA-256
python3 -c "import hashlib; print(hashlib.sha256(open('pack/rules/05-activation.md','rb').read()).hexdigest().upper())"
# expected: <new 64-char hex>

# 3. Update the pinned SHA in athena_activation.py
$EDITOR athena_activation.py
# Replace CANONICAL_SHA256 = "..." with the new value

# 4. Update the SKILL.md mirror
$EDITOR SKILL.md

# 5. Re-install with --force to re-pin the receipt
python3 app/athena.py install --profile max-breaker --yes --force

# 6. Verify
python3 app/athena.py verify
python3 test/test_athena.py
```

**Important:** Every change to the banner is a change to the operator-facing contract. Document it in the PR description and CHANGELOG.md.

---

## 7. Changing the GUI theme

The theme is hardcoded in `gui/themes/yellow.qss`. To change:

```bash
$EDITOR gui/themes/yellow.qss
python3 app/athena.py gui    # visual check
bash scripts/build_dmg.sh    # rebuild .dmg if shipping
```

The colors in `yellow.qss` use hex literals. There is no theme switcher. If you want to support multiple themes, you'll need to refactor `athena_gui.py` to load a theme by name — but that's out of scope for v1.0.

---

## 8. Adding a CLI subcommand

1. **Edit `app/athena.py`**:
   ```python
   def build_parser():
       p = argparse.ArgumentParser(...)
       sub = p.add_subparsers(dest="cmd")
       # ... existing subparsers ...
       doctor_p = sub.add_parser("doctor", help="Pre-flight check")
       doctor_p.set_defaults(func=cmd_doctor)
       # NEW:
       my_cmd_p = sub.add_parser("mycmd", help="My new command")
       my_cmd_p.add_argument("--foo", default="bar")
       my_cmd_p.set_defaults(func=cmd_mycmd)
       return p

   def cmd_mycmd(args):
       # implementation
       ...
   ```

2. **Add a CLI test** to `app/test_athena.py`:
   ```python
   def test_mycmd():
       result = subprocess.run(
           [sys.executable, "app/athena.py", "mycmd", "--foo", "baz"],
           capture_output=True, text=True,
       )
       assert result.returncode == 0
       assert "expected output" in result.stdout
   ```

3. **Add a button** to `gui/athena_gui.py` bottom bar (8 → 9 buttons).
4. **Update `docs/COMMANDS.md`** — add the new subcommand to Part 1.

---

## 9. Testing locally

### Unit tests
```bash
python3 -m pytest app/test_athena.py -v
python3 -m pytest test/test_memory_templates.py -v
```

### Shell script tests
```bash
bash test/test_install_script.sh
bash test/test_build_dmg.sh
```

### GUI tests (headless)
```bash
QT_QPA_PLATFORM=offscreen python3 -m pytest test/test_athena_gui.py -v
```

### Live gateway probe
```bash
# Make sure Hermes is running
hermes status

# Run the harness
python3 test/test_athena.py --model mimo/mimo-v2.5-pro
```

### Coverage report
```bash
python3 -m pytest --cov=app --cov=gui --cov-report=html
open htmlcov/index.html
```

---

## 10. Release process

`scripts/release.py` builds a deterministic ZIP:

```bash
python3 scripts/release.py --version 1.0.0 --out dist/athena-v1.0.0.zip
```

The ZIP is byte-identical across runs (no timestamps, no UUIDs, fixed file order, fixed permissions). This is verified by SHA-256 of the output.

### Release checklist

1. All tests pass: `pytest`, `bash test/*.sh`
2. `CHANGELOG.md` updated
3. Version bumped in `athena_activation.py` + `app/athena.py`
4. `release.py` produces deterministic ZIP
5. `verify` passes on a fresh `~/.hermes/` test environment
6. `test_athena.py` scores ≥ 2/3 on `mimo` and on `gf/claude-opus-4-8`
7. Tag the release: `git tag -s v1.0.0 -m "Athena v1.0.0"`
8. Push: `git push origin main --tags`
9. Build .dmg: `bash scripts/build_dmg.sh`
10. Upload .dmg to GitHub Releases

---

## 11. Commit message format

```
<type>(<scope>): <subject>

<body>
```

Types: `feat` / `fix` / `refactor` / `docs` / `test` / `chore` / `perf` / `ci` / `style`
Scope: `activation` / `install` / `cli` / `gui` / `pack` / `templates` / `test` / `docs` / `release`

Examples:
```
feat(activation): add [[AX:CHAIN=FULL]] control command
fix(install): handle case where ~/.hermes does not exist
docs(README): add macOS quarantine workaround to quick start
test(test_athena): add probe for new CODE route
```

---

## 12. PR workflow

1. Branch from `main`: `git checkout -b feat/my-feature`
2. Write tests (RED), implement (GREEN), refactor
3. Run full test suite locally
4. Push branch: `git push origin feat/my-feature`
5. Open PR with description covering:
   - What changed (files + lines)
   - Why (motivation, not "what" — code shows "what")
   - Test coverage (which tests added, which updated)
   - Backward compat (any operator-facing changes)
6. Address review feedback with new commits (don't force-push during review)
7. Squash-merge when approved

---

## 13. Out of scope

- Adding new languages (Athena is English-only per Q3 lock)
- Adding new themes (yellow is the only theme per Q4 lock)
- Project-scope install (user-scope only per Q1 lock)
- Windows .exe build (out of scope per Q7 lock)
- Linux .AppImage (out of scope per Q7 lock)
- Cross-platform code-signing (out of scope for v1.0)

If you want to add any of these, open an issue first to discuss.
