---
description: Manage the active verifier panel (list | add <name> | remove <name>).
argument-hint: "[list | add <name> | remove <name>]"
---

# /agent-companion:verifiers

Run and show the output of:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/verifiers.sh" $ARGUMENTS
```

Examples:
- `/agent-companion:verifiers` — list active agents + available adapters
- `/agent-companion:verifiers add codex` — enable an agent (frontier default, dispatch effort)
- `/agent-companion:verifiers add codex:gpt-5.6-sol@high` — pin a model + reasoning effort
- `/agent-companion:verifiers add grok@high` — frontier model at a specific effort
- `/agent-companion:verifiers remove grok` — disable an agent

An entry is `cli[:model][@effort]`: `cli` is the adapter basename (codex/gemini/grok), `:model`
pins a model (omitted → the CLI's own frontier default), `@effort` is one of
low|medium|high|xhigh|max (omitted → the dispatch effort; gemini has no effort knob and ignores
it). Entries are matched **exactly** — `codex` and `codex:gpt-5.5@high` are distinct and can
coexist, so `remove codex` removes only the bare entry.

This edits the persistent panel config under `${CLAUDE_PLUGIN_DATA}` (no need to find plugin
paths by hand). `add` requires a matching `adapters/<cli>.sh` to exist (see the
creating-plugins skill).
