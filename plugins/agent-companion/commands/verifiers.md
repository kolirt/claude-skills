---
description: Manage the active verifier panel (list | add <adapter> [flags] | remove <index>).
argument-hint: "[list | add <adapter> [--model <name>] [--effort <tier>] | remove <index>]"
---

# /agent-companion:verifiers

Run and show the output of:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/verifiers.sh" $ARGUMENTS
```

Examples:
- `/agent-companion:verifiers` — list active agents (numbered) + available adapters
- `/agent-companion:verifiers add codex` — enable an agent (its own frontier default, dispatch effort)
- `/agent-companion:verifiers add codex --model gpt-5.6-sol --effort high` — pin a model + reasoning effort
- `/agent-companion:verifiers add grok --effort high` — frontier model at a specific effort
- `/agent-companion:verifiers add agy --model "Gemini 3.5 Flash (Medium)"` — a model name with spaces
- `/agent-companion:verifiers remove 2` — disable entry #2 (the number from `list`)

## Syntax

`add <adapter> [--model <name>] [--effort <tier>]`

- `<adapter>` — the adapter basename (`agy`, `codex`, `grok`); requires a matching
  `adapters/<adapter>.sh` to exist (see the creating-plugins skill).
- `--model` — optional. Omitted → the CLI's own default. The name is stored **verbatim**,
  so names containing spaces and parentheses are fine (just quote them in the shell).
- `--effort` — optional, one of `low|medium|high|xhigh|max`. Omitted → the dispatch effort.
  `agy` has no effort knob (the tier is baked into its model names) and ignores it.

When the user names a model loosely ("gemini 3.5 flash medium"), pass it as-is to `--model`:
adapters that can enumerate their models resolve it to the canonical spelling once, at add
time. If the input is unknown or ambiguous the command **fails and prints the candidates** —
ask the user which one they meant, then re-run. Nothing is ever guessed or silently stored.

Entries are addressed by **index**, never by name: two entries may share an adapter and model
and still be distinct, so `remove 2` removes exactly the second one shown by `list`.

## Config

This edits the persistent panel config `${CLAUDE_PLUGIN_DATA}/panel.json` (no need to find
plugin paths by hand). Reading it requires `jq` or `python3` on PATH.

Since 0.3.0 the panel is one JSON document. Old `verifiers.conf` / `synthesizer.conf` files
are **not read and not migrated** — if they are still present the plugin says so on stderr and
runs on the bundled default until the panel is rebuilt with `add`.
