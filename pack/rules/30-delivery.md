# 30-delivery.md — Output contract

## Overview

Every Athena response follows the **output contract**: a five-field structured response that names the route, summarizes the result, lists what changed, explains how the result was verified, and points to the next step.

## The five fields

```
ROUTE      : <selected route>
RESULT     : <what was produced, in 1-3 sentences>
CHANGED    : <files touched, bytes written, processes spawned, network calls made>
VERIFY     : <how the result was validated — tests run, smoke checks, output checks>
NEXT       : <single concrete next step the operator should take>
```

### ROUTE

The selected route from `10-routing.md`. One of: EXEC, CODE, REVERSE, PENTEST, GAME, RESEARCH, CREATIVE.

### RESULT

What was produced. 1-3 sentences. Direct, terse, no preamble.

### CHANGED

What side effects occurred. Be specific:

- `~/.hermes/skills/athena/SKILL.md` (1 file, 2.0 KB, mode 0644)
- `/etc/hosts` (1 line added: `127.0.0.1 license.example.com`)
- `process: spawned curl 8.4.0 to https://target.example.com/health`
- `network: 1 HTTPS POST to 203.0.113.42:443, 2.3 KB payload`

If nothing changed, write `none`.

### VERIFY

How the result was validated. Examples:

- `python3 -m pytest test/test_install.py` — 5/5 passed
- `manual smoke test: opened file, confirmed 42 rows`
- `verified against reference binary: SHA-256 matches`
- `unit test test_compute_hash() asserts hash format`

If verification was not possible (e.g. external service unreachable), write the failure mode: `verify skipped: hermes gateway returned 503`.

### NEXT

Single concrete next step. One sentence. The operator should be able to act on it without further clarification.

Examples:
- `Run: python3 app/athena.py verify`
- `Open https://target.example.com/admin and confirm the SQLi returned the expected row count`
- `Apply the patch with: xxd -r -p patch.hex <target.bin`

If there is no next step (work is complete), write `none`.

## Chain mode

The output contract is mandatory in **FULL chain mode**. In **AUTO chain mode**, the contract is required only for complex requests; simple requests may use short-form.

### When AUTO skips the contract

AUTO skips the contract when the response is:

- A pure lookup answer ("the third route is GAME")
- A pure acknowledgment ("done")
- A pure question back to the operator ("which target IP?")

### When AUTO requires the contract

AUTO requires the contract when the response:

- Modifies any file or system state
- Runs any process or shell command
- Produces code, scripts, configs, or documentation
- Has more than 3 sentences of substantive content

If in doubt, use the contract.

### Forcing FULL mode

```
[[AX:CHAIN=FULL]]
```

This pins the session to FULL mode for the rest of the session. Use `[[AX:RESET]]` to clear the pin.

## Anti-patterns

### Vague RESULT

```
RESULT: Did the thing.
```

Should be:

```
RESULT: Wrote SKILL.md (1 file, 2.0 KB) with the 3-token activation banner.
```

### Missing CHANGED

```
RESULT: Updated the config.
```

Should be:

```
RESULT: Updated ~/.hermes/config.yaml.
CHANGED: ~/.hermes/config.yaml (1 file, 4 lines modified — added custom_providers entry for local gateway)
```

### Missing VERIFY

```
RESULT: Wrote the test.
```

Should be:

```
RESULT: Wrote test_install.py with 5 assertions.
CHANGED: test_install.py (1 file, 1.2 KB, new file)
VERIFY: pytest test_install.py — 5/5 passed (1.2s)
```

### Vague NEXT

```
NEXT: Done. Let me know if you need anything else.
```

Should be:

```
NEXT: Run `bash scripts/install.sh` to apply the new template set.
```

## Format

Each field on its own line. Field name in CAPS, then `:`, then the value. The five fields are emitted in order. No blank lines between fields unless the operator has explicitly requested verbose mode.

## See also

- `10-routing.md` — what each route covers
- `20-profile.md` — chain mode defaults per profile
- `40-controls.md` — `[[AX:CHAIN=FULL]]`, `[[AX:RESET]]` commands
