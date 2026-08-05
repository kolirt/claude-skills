---
description: Start agent-companion — Claude acts as manager and consults the verifier panel.
---

# /agent-companion:on

First, record the activation intent so the hooks pick the mode up even if this slash command never
reaches `UserPromptSubmit`:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/state.sh" want-on
```

Then read `${CLAUDE_PLUGIN_ROOT}/MANAGER.md` and act STRICTLY as the MANAGER per it until `/agent-companion:off`.

At each verifier-protocol point defined by **MANAGER.md** (consult / review / audit / diagnose / research), follow it:
`prepare` (freeze + list agents) → spawn each `SPAWN` line as a native background task → `collect`
(gate) → `score` (record what each verifier was worth). Do NOT cd first. `collect` exit codes: `0`
pass/non-gating · `10` review blocked · `64` either env error or — per its stderr token
`INCOMPLETE` — an unfinished run to retry (re-spawn the `MISSING` agents in the same run dir, then
`collect` again).

**Scoring is mandatory.** `collect` prints a `=== scoring required ===` block; run one
`verify.sh score <REQUEST_ID> --label <label> --accepted N --rejected N --duplicate N --report
useful|noise|empty|duplicate` per verifier (rubric in MANAGER.md), or `score <REQUEST_ID> --skip`
to waive it deliberately. This is the only record of whether a paid verifier subscription is
earning its keep — read it back with `/agent-companion:stats`.

**Graceful degrade:** a `64` with `NO_VERIFIER` or "not a git repo" is an environment error, not a
verdict — continue and tell the user the step proceeded without verification. A `65` from
`prepare` (`UNSCORED`) is the OPPOSITE: the tooling is fine and an earlier run was never scored.
Score it, then re-run `prepare` — never route around it by dropping the panel.

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
external CLIs, and that any non-claude choice may be refined to a specific model/effort with
the `--model` / `--effort` flags (e.g. `set codex --model gpt-5.6-sol --effort high`). Then
persist their choice:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/synthesizer.sh" set <choice>
```
Ask only when unset; afterwards it is remembered. It can be changed anytime with
`/agent-companion:synthesizer`.

**Durability.** Plugin hooks persist this mode per session, so it survives compaction and is
re-injected on resume — you do not need to be re-enabled mid-session. `/clear` turns it OFF (run
`/agent-companion:on` again in the new session). Resuming an older session that had the mode on
legitimately restores it. Reminders are best-effort: a user running with `disableAllHooks` (or a
managed-hooks-only policy) gets the pre-0.2.0 behaviour, where the protocol can fade from context
in a long session.

Confirm: "agent-companion enabled — I am the manager."
