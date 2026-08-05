---
description: Show what each verifier has actually been worth (quality metrics per adapter).
argument-hint: "[--since <days>] [--repo <key>] [--mode <mode>] [--by-model]"
---

# /agent-companion:stats

Run and show the output of:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/stats.sh" $ARGUMENTS
```

Examples:
- `/agent-companion:stats` — every retained month, all repos, one row per adapter
- `/agent-companion:stats --by-model` — split `codex/gpt-5.5` from `codex/gpt-5.6-sol`
- `/agent-companion:stats --since 30` — the last 30 days only
- `/agent-companion:stats --mode review` — ignore consult/audit/diagnose/research runs
- `/agent-companion:stats --repo 4c843370d7c8a3e0` — one repository

## What the columns mean

Every panel run records one row per verifier entry; after `collect` the manager scores each
report it read. The table joins the two.

- `runs` / `reports` — how often the entry was dispatched, and how often it actually answered.
- `fail/sk` — dispatches where its CLI was unavailable or the probe failed. A subscription that
  is frequently unusable costs the same as one that is not.
- `waived` — runs recorded as deliberately unscored (`score --skip`). High `waived` means the
  numbers next to it rest on a thin sample.
- `accept` / `reject` / `duplicate` — findings the manager acted on, dismissed, and ones another
  verifier had already reported.
- `acc/run` — accepted findings per scored report. The blunt "is it earning its keep" number.
- `unique%` — `accept / (accept + duplicate)`. Separates an entry that finds things nobody else
  did from one that only ever seconds another's report.
- `useful%` (printed under the table) — share of its scored reports the manager called useful.
- `n` — scored reports behind the row. Below the threshold the footer names the entry explicitly;
  a small `n` is not evidence.

## Reading it honestly

The rates are confounded by task difficulty, the order the manager read the reports in, and which
modes the entry happened to be used for. Verifiers within one run share a prompt, so comparing
them against each other is meaningful; comparing one entry's absolute rate across periods is much
weaker. Treat the table as evidence for a cancellation decision, never as the decision.

## Storage

Metrics live in `${CLAUDE_PLUGIN_DATA}/metrics/` as per-month TSV files and are rotated
automatically — the current month plus the two preceding ones are kept. Nothing here reaches the
network, and no run content is stored: only counts, adapter/model names, and the manager's labels.
