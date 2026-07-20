---
description: Choose the agent that consolidates multi-verifier reports (show | set <name> | off).
argument-hint: "[show | set <claude|adapter|none> [--model <name>] [--effort <tier>] | off]"
---

# /agent-companion:synthesizer

Run and show the output of:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/synthesizer.sh" $ARGUMENTS
```

When 2+ verifiers run, their full reports can flood the session. A **synthesizer** agent
consolidates them into ONE report off-context, so only the merged result returns. Candidates:
`claude` (headless, uses Claude limits), any verifier adapter (`agy`, `codex`, `grok`, `kimi`), or
`none` (just list reports compactly). Consolidation is a deep-reasoning task, so pinning a
strong model + high effort here is often worthwhile.

Examples:
- `/agent-companion:synthesizer` — show current choice + candidates
- `/agent-companion:synthesizer set grok` — consolidate with grok's frontier default
- `/agent-companion:synthesizer set codex --model gpt-5.6-sol --effort high` — pin model + effort
- `/agent-companion:synthesizer off` — disable (compact listing instead)

## Syntax

`set <claude|adapter|none> [--model <name>] [--effort <tier>]`

Same flags and the same add-time model resolution as `/agent-companion:verifiers add`: a loose
model name is resolved to the adapter's canonical spelling, and an unknown or ambiguous one is
rejected with the candidate list rather than guessed.

`show` never fails on a stale choice — if the configured adapter no longer exists it reports
the value and flags it as `STALE`, which is also warned about on stderr during a review.

## Config

The choice lives in the panel document `${CLAUDE_PLUGIN_DATA}/panel.json` alongside the
verifiers (since 0.3.0; the old `synthesizer.conf` is not read and not migrated). Reading it
requires `jq` or `python3` on PATH. Synthesis runs only when 2+ verifiers produce reports —
a single report is returned as-is.
