---
description: Start agent-companion — Claude acts as manager and consults the verifier panel.
---

# /agent-companion:on

Read `${CLAUDE_PLUGIN_ROOT}/MANAGER.md` and act STRICTLY as the MANAGER per it until `/agent-companion:off`.

At each verifier-protocol point defined by **MANAGER.md** (consult / review / audit / diagnose / research), follow it:
`prepare` (freeze + list agents) → spawn each `SPAWN` line as a native background task → `collect`
(gate). Do NOT cd first. `collect` exit codes: `0` pass/non-gating · `10` review blocked · `64`
either env error or — per its stderr token `INCOMPLETE` — an unfinished run to retry (re-spawn the
`MISSING` agents in the same run dir, then `collect` again).

**Graceful degrade:** a `64` with `NO_VERIFIER` or "not a git repo" is an environment error, not a
verdict — continue and tell the user the step proceeded without verification.

Manage which agents are active with `/agent-companion:verifiers`. Plugin updates are handled by native `/plugin update`.

**First-run synthesizer choice.** When 2+ verifiers are active their reports can flood the
session, so a synthesizer agent can consolidate them into one. On enabling, check it once:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/synthesizer.sh" show
```
If it reports `synthesizer: unset` AND 2+ verifiers are active, ask the user which agent should
consolidate multi-agent reports. Offer **exactly** the candidates printed on the `candidates:`
line of `synthesizer.sh show` — present EACH one as its own distinct option (do NOT merge,
drop, or abbreviate any). Note only that `claude` uses Claude limits while the rest are
external CLIs, and that any non-claude choice may be refined to a specific model/effort as
`cli:model@effort` (e.g. `codex:gpt-5.6-sol@high`). Then
persist their choice:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/synthesizer.sh" set <choice>
```
Ask only when unset; afterwards it is remembered. It can be changed anytime with
`/agent-companion:synthesizer`.

Confirm: "agent-companion enabled — I am the manager."
