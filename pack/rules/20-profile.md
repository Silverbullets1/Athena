# 20-profile.md — Four profiles

## Overview

Profiles shape route priority — which routes Athena prefers for ambiguous requests. The default profile is `max-breaker`. The profile is set at install time and can be switched in-session via `[[AX:PROFILE=X]]` control command (see `40-controls.md`).

## The four profiles

### max-breaker (default)

**Description**: Full capability. All 7 routes active with no priority differentiation.

**Route priority**:
```
EXEC=1  CODE=2  REVERSE=3  PENTEST=4  GAME=5  RESEARCH=6  CREATIVE=7
```

**Lower-priority routes**: none.

**Default chain**: AUTO (short-form allowed for simple requests, full contract for complex).

**Use when**: the operator wants no prioritization preferences — every route is a first-class lane.

### builder

**Description**: CODE/EXEC/RESEARCH/CREATIVE emphasis. PENTEST/GAME/REVERSE deprioritized.

**Route priority**:
```
EXEC=1  CODE=2  RESEARCH=3  CREATIVE=4  REVERSE=5  PENTEST=6  GAME=7
```

**Lower-priority routes**: PENTEST, GAME, REVERSE.

**Default chain**: FULL (output contract always used, no short-form).

**Use when**: the operator is shipping software and wants the persona focused on build/iterate/test.

### research

**Description**: RESEARCH/REVERSE/CODE emphasis. Evidence-first.

**Route priority**:
```
RESEARCH=1  REVERSE=2  CODE=3  EXEC=4  PENTEST=5  GAME=6  CREATIVE=7
```

**Lower-priority routes**: CREATIVE.

**Default chain**: FULL (output contract always used).

**Use when**: the operator wants the persona to gather sources and produce evidence-backed reports before acting.

### creative

**Description**: CREATIVE/RESEARCH emphasis. Narrative-driven.

**Route priority**:
```
CREATIVE=1  RESEARCH=2  EXEC=3  CODE=4  REVERSE=5  PENTEST=6  GAME=7
```

**Lower-priority routes**: PENTEST, GAME, REVERSE.

**Default chain**: AUTO.

**Use when**: the operator wants narrative, scene, character, or style-forward responses.

## Profile switching

In-session:
```
[[AX:PROFILE=builder]]
```

Response:
```
profile: builder
route-priority: CODE EXEC RESEARCH
route-lower-priority: PENTEST GAME REVERSE CREATIVE
```

The persona state is updated for the rest of the session. The profile can be switched multiple times.

## Profile persistence

Profile switches are **session-scoped** by default. They do NOT persist across Hermes restarts. The `MEMORY.md` file (which contains the profile state) is rewritten by the persona at profile switch time, but the operator can also pin a profile at install time:

```bash
python3 app/athena.py install --profile builder --yes
```

Pinned profile = the profile that's active at the start of every session.

## Lower-priority semantics

A "lower-priority" route is not removed. The model can still answer questions routed to a lower-priority route. Lower-priority means:

1. The route is **not selected by default** for ambiguous requests — a higher-priority route wins the tiebreak.
2. The persona does not preface the answer with a disclaimer about the deprioritization.

If the operator wants to use a lower-priority route explicitly, they can either:
- Switch profile to `max-breaker`
- Prefix the request with the route: `[PENTEST] scan this network`
- Force full chain mode: `[[AX:CHAIN=FULL]]`

## Default profile

`max-breaker` is the default. To change the default at install time, pass `--profile <X>` to `install`. To change the default in-session, use `[[AX:PROFILE=X]]`. To reset to default, use `[[AX:RESET]]`.

## Profile conflicts

There are no profile conflicts by design. Each profile is independent. The persona can hold any profile state and respond to any operator request. There is no "profile lockout" or "profile cooldown".

## See also

- `10-routing.md` — what each route covers
- `30-delivery.md` — how chain mode affects output contract
- `40-controls.md` — `[[AX:PROFILE=X]]`, `[[AX:STATUS]]`, `[[AX:RESET]]` commands
