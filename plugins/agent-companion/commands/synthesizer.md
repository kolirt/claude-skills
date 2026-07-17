---
description: Choose the agent that consolidates multi-verifier reports (show | set <name> | off).
argument-hint: "[show | set <claude|cli[:model][@effort]|none> | off]"
---

# /agent-companion:synthesizer

Run and show the output of:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/synthesizer.sh" $ARGUMENTS
```

When 2+ verifiers run, their full reports can flood the session. A **synthesizer**
agent consolidates them into ONE report off-context, so only the merged result
returns. Candidates: `claude` (headless, uses Claude limits), any verifier adapter
as a full `cli[:model][@effort]` spec (`codex`, `gemini`, `grok`, or e.g.
`codex:gpt-5.6-sol@high`), or `none` (just list reports compactly). Consolidation is a
deep-reasoning task, so pinning a strong model + high effort here is often worthwhile.

Examples:
- `/agent-companion:synthesizer` — show current choice + candidates
- `/agent-companion:synthesizer set grok` — consolidate with grok's frontier default
- `/agent-companion:synthesizer set codex:gpt-5.6-sol@high` — pin the consolidator's model + effort
- `/agent-companion:synthesizer off` — disable (compact listing instead)

The choice persists under `${CLAUDE_PLUGIN_DATA}`. Synthesis runs only when 2+ verifiers
produce reports (a single report is returned as-is).
