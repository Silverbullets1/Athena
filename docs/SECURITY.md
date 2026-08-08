# SECURITY.md — Athena Security Policy + Threat Model

**Audience:** Operators evaluating the install's safety, and security researchers reviewing the receipt chain.

---

## 1. Supported versions

| Version | Supported          | Notes                                |
|---------|--------------------|--------------------------------------|
| 1.0.x   | yes                | current release                      |
| < 1.0   | no                 | pre-release, internal only           |

Security fixes are applied to the latest 1.x release. Older releases do not receive patches.

---

## 2. Reporting a vulnerability

**Do not** open a public GitHub issue for security-sensitive disclosures.

Instead, contact the maintainer directly via one of:
- Direct message on GitHub: [@xscope0](https://github.com/xscope0)
- Private security advisory: github.com/xscope0/athena/security/advisories/new

Response SLA:
- Acknowledgement: within 48 hours
- Triage: within 7 days
- Patch (if confirmed): within 30 days, depending on severity

Critical vulnerabilities (RCE on install, receipt-chain bypass) are fixed out-of-band and disclosed after a fix is available.

---

## 3. Threat model

### 3.1 What the install does

The `install` subcommand:
1. Writes `~/.hermes/skills/athena/SKILL.md` (the activation banner)
2. Writes `~/.hermes/scripts/athena-{install,uninstall,verify}.sh` + `athena-release.py` + `build-dmg.sh`
3. Writes `.pre-athena-<pid>` next to each existing `SOUL.md` / `MEMORY.md` / `USER.md`
4. Writes `~/.hermes/SOUL.md` / `MEMORY.md` / `USER.md` from the templates in `pack/`
5. Writes `~/.hermes/.athena.receipt` with SHA-256 of every installed file

### 3.2 What the install does NOT do

- Does NOT read or transmit any file outside `~/.hermes/`
- Does NOT phone home to any external endpoint
- Does NOT modify `~/.hermes/config.yaml` (gateway URL, default model, custom_providers)
- Does NOT modify `~/.hermes/AGENTS.md` (project-scope agent instructions)
- Does NOT modify `~/.hermes/HERMES.md`
- Does NOT modify any other skill under `~/.hermes/skills/`
- Does NOT touch any file outside `~/.hermes/`
- Does NOT write to `/etc/`, `/usr/`, `/var/`, or any system location
- Does NOT install a launchd/systemd service
- Does NOT modify shell rc files (`.zshrc`, `.bashrc`)

### 3.3 What the install protects against

| Threat                                | Mitigation                              |
|---------------------------------------|------------------------------------------|
| Operator mistypes command and wipes unintentionally | Two-step confirmation (interactive) / `--yes` required (CI) |
| Disk corruption during install       | Atomic write with `fsync()` + `rename()` |
| Tampering with SKILL.md after install | SHA-256 verification + receipt chain     |
| Concurrent install from two terminals | `.athena.receipt.lock` file (PID-stamped)|
| Activation banner drift              | `CANONICAL_SHA256` checked at prompt-build time |
| Rollback of malicious "update"       | `--force` requires explicit operator opt-in |

### 3.4 What the install does NOT protect against

| Threat                                | Why                                            |
|---------------------------------------|------------------------------------------------|
| Operator runs `rm -rf ~` after install | Outside the install's scope                    |
| Malicious code in `~/.hermes/SOUL.md` | The operator wrote it (or accepted the template) |
| Compromised `pip install hermes-agent` | Outside Athena's scope; verify PyPI integrity  |
| Disk-level attacker with root         | They can edit any file; SHA-256 only catches logical tampering |
| Hermes itself modifying SOUL/MEMORY/USER mid-session | The activation banner is supposed to do this |

The install is a **file-management tool**, not a security boundary. It assumes the operator trusts their local environment.

---

## 4. Destructive install warnings

The install overwrites three files in `~/.hermes/`:
- `SOUL.md` — Hermes's persona file (loaded into every system prompt)
- `MEMORY.md` — Hermes's memory file (loaded into every system prompt)
- `USER.md` — Hermes's user-profile file

This is intentional and is the whole point of Athena. But it means:

> **If you have existing content in `~/.hermes/SOUL.md` / `MEMORY.md` / `USER.md` that you want to keep, back it up before installing Athena.**

The install writes `.pre-athena-<pid>` files next to each file as a local backup. There is no off-disk backup. If you want an off-disk backup, run:

```bash
mkdir -p ~/backups/hermes-pre-athena
cp -a ~/.hermes/SOUL.md ~/.hermes/MEMORY.md ~/.hermes/USER.md ~/backups/hermes-pre-athena/
```

before running install.

---

## 5. Receipt chain integrity

The receipt at `~/.hermes/.athena.receipt` is the source of truth for `verify` and `uninstall`.

If `verify` reports a mismatch on any file, that file was modified after install. The receipt does not say whether the modification was intentional (you edited it) or unintentional (something else modified it). Run `python3 app/athena.py install --force --yes` to re-pin.

If `verify` reports the receipt itself is missing or corrupted, the install state is unknown. Run `python3 app/athena.py install --force --yes` to recover.

---

## 6. SHA-256 pinning rationale

`athena_activation.py` embeds `CANONICAL_SHA256 = "ee9826dc..."`. This is the hash of the canonical activation banner text at `pack/rules/05-activation.md`.

At every prompt-build cycle, the activation module:
1. Reads `~/.hermes/skills/athena/SKILL.md`
2. Computes SHA-256
3. Compares to `CANONICAL_SHA256`
4. If match: activates Athena
5. If mismatch: falls back to standard Hermes banner

This catches:
- Operator manually editing SKILL.md
- Disk corruption
- Injection (a tampered banner doesn't activate)

The SHA-256 is re-pinned on every `install --force`. The pin ceremony is documented in [CONTRIBUTING.md §6](CONTRIBUTING.md).

---

## 7. macOS quarantine

`Athena-v1.0.0.dmg` is shipped unsigned. Apple Silicon Macs apply the `com.apple.quarantine` xattr to downloaded files. First launch requires:

```bash
xattr -d com.apple.quarantine /Applications/Athena.app
```

This is documented in:
- README.md quick start
- INSTALL.md §11 troubleshooting
- GUI launch instructions

Code-signing is intentionally out of scope for v1.0.0 (no Apple Developer ID configured). Future versions may add signing.

---

## 8. Upgrade path

Athena 1.0.x is the only release line. To upgrade within 1.0.x:

```bash
git pull  # or download new release
python3 app/athena.py install --profile max-breaker --yes --force
python3 app/athena.py verify
```

To upgrade from pre-release (0.x) to 1.0.0:

```bash
python3 app/athena.py uninstall --yes  # remove old install
# manually restore from .pre-athena-* if you want
python3 app/athena.py install --profile max-breaker --yes  # install new
```

There is no automatic upgrade from 0.x to 1.0.0 because the receipt format changed.

---

## 9. Audit log

Every install / verify / uninstall writes one line to `~/.hermes/.athena.audit.log`:

```
2026-08-08T12:34:56Z  install  profile=max-breaker  receipt=ee9826dc...  operator=$USER
2026-08-08T12:35:00Z  verify   PASS
2026-08-08T12:40:00Z  install  --force  receipt=<new-sha>  operator=$USER
```

The audit log is append-only and never rotated. To inspect:

```bash
cat ~/.hermes/.athena.audit.log
```

---

## 10. Disclaimer

Athena is a developer tool that installs a research persona into the Hermes agent harness. The persona is configured for CTF / bug hunting / ransomware development / BIN-based research — these are research focus areas, not endorsements. The operator is responsible for ensuring their use complies with applicable law and the terms of any system they interact with.

The Athena maintainers disclaim all liability for misuse.
