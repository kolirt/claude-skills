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
- `/agent-companion:verifiers add codex` — enable an agent
- `/agent-companion:verifiers remove grok` — disable an agent

This edits the persistent panel config under `${CLAUDE_PLUGIN_DATA}` (no need to find plugin
paths by hand). `add` requires a matching `adapters/<name>.sh` to exist (see the
creating-plugins skill).
