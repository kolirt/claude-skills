---
description: Start agent-companion — Claude acts as manager and consults the verifier panel.
---

# /agent-companion:on

Read `${CLAUDE_PLUGIN_ROOT}/MANAGER.md` and act STRICTLY as the MANAGER per it until `/agent-companion:off`.

At decision / review / audit points, run the panel dispatcher (do NOT change directory first):
```bash
bash "${CLAUDE_PLUGIN_ROOT}/verify.sh" <mode> <effort> <request-file>
```
Read its STDOUT (the combined per-verifier summary) and its exit code:
`0` PASS/ADVICE/AUDIT_COMPLETE · `10` blocked: CHANGES_REQUESTED or a verifier FAIL (see the summary) · `64` no verifier available.

**Graceful degrade:** exit `64` means no verifier was reachable — continue as manager and tell the user CONSULT/REVIEW is unavailable, the step proceeding without verification.

Manage which agents are active with `/agent-companion:verifiers`. Plugin updates are handled by native `/plugin update`.

**First-run synthesizer choice.** When 2+ verifiers are active their reports can flood the
session, so a synthesizer agent can consolidate them into one. On enabling, check it once:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/synthesizer.sh" show
```
If it reports `synthesizer: unset` AND 2+ verifiers are active, ask the user which agent should
consolidate multi-agent reports — `claude` (best quality, uses Claude limits), an external
adapter (e.g. `codex`/`grok`), or `none` — then persist their choice:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/synthesizer.sh" set <choice>
```
Ask only when unset; afterwards it is remembered. It can be changed anytime with
`/agent-companion:synthesizer`.

Confirm: "agent-companion enabled — I am the manager."
