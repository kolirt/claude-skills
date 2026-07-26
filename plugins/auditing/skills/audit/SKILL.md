---
name: audit
description: Use when the user asks for a whole-application audit without naming a perspective — 'audit this app', 'run an audit', 'full audit', 'аудит проєкту', 'перевір застосунок', 'подивись що не так з проєктом'. Detects the stack once, prints an annotated domain table with an evidence-based verdict per domain, takes the user's selection, runs the selected domains as parallel subagents, and assembles their findings into a run directory under docs/audit/. Owns orchestration and writes; owns no findings of its own. Do NOT use when the user names a single perspective — 'security audit', 'SEO-аудит', 'аудит доступності' fire auditing:security, auditing:seo, auditing:accessibility and the other domain skills directly. Do NOT use to review a PR, a branch, or a diff — that is the auditing-prs plugin.
---

# Whole-application audit (dispatcher)

Orchestrates a multi-domain audit over a whole codebase: one preflight, one selection, parallel
domain subagents, one assembled run directory. It is the only skill in this plugin that reads
`../../core/panel-integration.md`.

## 1. What this skill is

Orchestration only. This skill owns the preflight, the domain table, the selection, subagent
dispatch, failure isolation, every file write, and the closing digest.

It owns **no findings, no domain judgement, and no impact dimensions**. Those belong to the domain
skills: each defines what counts as a problem in its perspective and how `blocker` / `major` /
`minor` are graded there. The dispatcher never grades, never re-words, never merges two domains'
judgements into one of its own, and never adds an observation it noticed while orchestrating.

**If the dispatcher ever states a finding of its own, that is a defect** — not a bonus. A gap the
dispatcher notices is either a domain's finding, dispatched to that domain, or nothing.

## 2. Preflight — run exactly once

The preflight runs **once per run**, before the domain table is printed, and its results are passed
down. No domain repeats any part of it.

### 2.1 Stack snapshot

Read `../../core/stack-detection.md`, then **run the detection script exactly once**:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.py"
```

Run it in the audited repository's own working directory — never by `cd`-ing into the plugin. Its JSON
output **is** the snapshot; the core doc owns what that JSON contains, how markers are cited, how units
are discovered, and the `python3`-unavailable fallback. Do not restate any of it here.

The dispatcher's only addition is the two **agent-supplied facts** the script cannot see:
`convention_plugins` (2.3) and `indexability` (2.5). It does not re-derive, second-guess, or
"double-check" what the script reported with directory reads of its own — an absent surface is absent.
Every domain subagent receives the resulting snapshot as an input; detection is never re-run inside a
domain and the snapshot is not argued with.

### 2.2 Product/strategy description

Ask the user, **once**, for an optional description of the product and its strategy: what it is
for, who uses it, how it makes money, what stage it is at.

It is collected here, not inside the domain that needs it, for a mechanical reason: a **parallel
subagent cannot prompt the user**. `auditing:business-analysis` treats an explicit product
description as its highest-priority evidence source (Read `../../core/report-model.md`), so if it
is not gathered before dispatch it can never be gathered at all for this run.

Empty is allowed and is a normal outcome. An empty description is recorded as a **coverage fact** —
the audit reconstructed intent from code alone — never as a finding and never as a reason to skip a
domain.

### 2.3 Convention plugins

Detect which `knowledge-*` skills are available this session and record the result as the
`convention_plugins` fact **in the snapshot**. It belongs here rather than to the script because it is
session state, not a file on disk, and it is what decides whether **knowledge tier 3** exists for a
given domain in this run. The tier definitions and the soft-dependency rule live in
`../../core/report-model.md`; do not restate them here.

### 2.4 Prior runs

Read `docs/audit/`, and `docs/audit/INDEX.md` if it exists, to identify the most recent prior run
and the domains it covered. This is the basis for run comparison in section 9. No prior run is a
normal state; it means every finding in this run is `new`.

### 2.5 Indexability

Ask the user, **once**, one optional question: is the project **public**, **internal**, or
**unreleased**? Record the answer as the `indexability` fact in the snapshot. It is asked here for the
same mechanical reason as 2.2 — a **parallel subagent cannot prompt the user** — and `seo`'s verdict
turns on it, while intent has no marker a script could read. An unanswered question is recorded as
**unknown**, never assumed to be public.

## 3. The annotated domain table

Print the table for the user **before anything runs**. One row per domain: its name, a one-line
purpose, a **detection verdict**, and the reason for that verdict.

The three verdicts:

- **`recommended`** — the snapshot carries the surfaces this domain needs, and the domain applies to
  almost any codebase that has them.
- **`your call`** — the domain applies, but its value depends on the project's stage or priorities,
  or it would run in a reduced mode.
- **`not applicable`** — a surface the domain requires is absent. **Name the missing fact.**

Verdicts are resolved per unit at run time, per the rules below. Each rule reads only **named snapshot
facts plus the two preflight inputs** — the product/strategy description from 2.2 and `indexability`
from 2.5 — so a reader can resolve every rule mechanically, with no judgement left over. A rule that
needed anything else would not be resolvable before dispatch, which is the whole point of this table.

A verdict here is a **dispatch decision**, not a promise about the outcome. A dispatched domain may
still end at `not applicable` once it starts reading — `data` and `api-contracts` say so explicitly,
because a `server` or `ui` surface is not proof that anything is persisted or that any request is
made. That is recorded in coverage with its reason and is not a defect in this table.

| Domain | Purpose | Verdict rule |
|---|---|---|
| `security` | Whether the app is safe by default: authentication, authorisation, validation, secrets, injection and rendering sinks | `recommended` when `server` is present; `your call` when only `ui` is present, since client-side enforcement and secret exposure are still auditable but the server side is not there to check; `not applicable` when neither `server` nor `ui` is present |
| `reliability` | Whether it keeps working when something fails, and whether anyone would know | `recommended` when `server` is present; `your call` when `server` is absent but `ui` or `data_schema` is present, since degradation or multi-step write consistency is still auditable; `not applicable` only when `server`, `ui` and `data_schema` are all absent |
| `code-quality` | Structural health: tangles, duplicated knowledge, broken boundaries, dead code | `recommended` when the unit declares a `manifest` or any surface is present — structural harm is auditable in a library or a CLI with neither `ui` nor `server`; `your call` when the unit has neither, a documentation or configuration tree where findings are possible but thin. Never `not applicable`. `architecture` and the unit's `framework` list decide whether `knowledge-vue:architecture` supplies tier 3 |
| `performance` | Work the app does that it does not need to do: query shape, over-fetching, client cost | `recommended` when `data_schema` or `server` is present; `your call` when only `ui` is present, where the audit covers client cost only; `not applicable` when none of the three is present |
| `data` | Whether the schema makes wrong data impossible: constraints, keys, migrations, money and time | `recommended` when `data_schema` is present; `your call` when it is absent but `server` or `ui` is present, since the domain then runs its reduced API-boundary mode; `not applicable` when `data_schema`, `server` and `ui` are all absent. A reduced-mode unit where no data-handling code turns up while reading it reports `not applicable` with that reason — a surface is not proof that anything is persisted |
| `api-contracts` | Whether the client-server contract is consistent: shapes, errors, status codes, pagination, versioning | `recommended` when `api_contract` is present — full contract mode when `server` or `ui` is present too, and contract-document-only mode when neither is, where the document is audited for internal consistency alone; `your call` when `api_contract` is absent but `server` or `ui` is present, since the domain drops to client-internal consistency mode; `not applicable` when `api_contract`, `server` and `ui` are all absent |
| `accessibility` | Whether the interface can be operated without sight, colour, or a mouse | `recommended` when `ui` is present; `not applicable` when `ui` is absent |
| `business-analysis` | Product integrity: broken flows, entities without lifecycle, monetization leaks, intent-vs-implementation contradictions | `recommended` when `ui` or `server` is present **and** a product/strategy description was supplied in 2.2; `your call` in every other case where the unit shows any sign of being an application — `ui` or `server` present with an empty description (intent reconstructed from code alone), or neither present while the unit declares a `manifest` or carries any other surface (a CLI tool, a library, a schema-only or contract-only package: a thinner product model, not no product model); `not applicable` only when the unit declares no `manifest` and has no surface at all |
| `seo` | Whether the crawler-facing baseline is closed: titles, canonicals, robots, sitemaps, structured data | `recommended` when `ui` is present **and** `indexability` is public; `your call` when `ui` is present but `indexability` is internal, unreleased, or unknown, where the SEO stake is a priority question; `not applicable` when `ui` is absent, whatever `server` says — the detector's `server` also covers an API-only backend with no page a crawler could fetch |

Every verdict is **evidence-based, never a guess**: it cites the snapshot fact — and its marker — that
produced it, and
absence of a marker is absence, not a weaker presence. A `not applicable` verdict is **disclosed in
the table and carried into the run's coverage section** — a domain is never quietly dropped from the
list so the run looks cleaner than it was.

## 4. Selection

Offer exactly four options, and state what each resolves to against the table just printed:

- **`all recommended`** — every domain whose verdict is `recommended`. **This is the default**, and
  the option to nudge toward: a full pass over a whole codebase is expensive, and the recommended
  set is the part the snapshot actually supports.
- **`critical only`** — the fixed set `security`, `reliability`, `data`. Fixed means fixed: it is not
  recomputed from verdicts. A member whose verdict is `not applicable` is **dropped with a note**
  naming the missing fact, in chat and in coverage — never silently.
- **`everything available`** — every domain not marked `not applicable`, so `your call` domains are
  included too.
- **`choose manually`** — the user names the domains. A named domain marked `not applicable` is
  reported as such and not dispatched.

Confirm the resolved selection — the explicit domain list, and the scope it implies (`full` when
every domain ran, a single domain name, otherwise `custom`) — before executing anything.

## 5. Parallel domain subagents

Dispatch one subagent per selected domain, in parallel. Each receives:

- the stack snapshot from 2.1 — the detection script's JSON plus the two agent-supplied facts,
  `convention_plugins` from 2.3 and `indexability` from 2.5. A subagent **never re-runs detection**
  and never re-derives a surface the snapshot already answered;
- the product/strategy description from 2.2, verbatim, or the explicit fact that it is empty;
- the scope and any focus boundary the user stated;
- its own domain skill to follow — `auditing:<domain>` — as the sole authority on what it judges.

**Invariant: a domain subagent writes nothing.** No run directory, no report file, no scratch file,
no repository mutation of any kind. **Only the dispatcher writes files** (section 8). A subagent
also never reads `../../core/panel-integration.md`: the panel is dispatcher-only.

Each subagent **returns structured findings** so the dispatcher can assemble the report without
re-deriving anything:

1. **Findings** — each carrying every field the `Finding model` in `../../core/report-model.md`
   requires, already filled: `evidence`, `severity` and `confidence` are mandatory, and the
   evidence locator is one of the three valid forms.
2. **Opportunities** — the domain's proactive items, kept separate from the findings and already
   marked as judgment rather than fact.
3. **Its coverage statement** — what it inspected, what it excluded, its blind spots, and every
   knowledge tier that was unavailable to it, with the reason.
4. **Its own `not applicable` verdict**, if it reached one after reading the code, together with the
   missing fact — a mid-run verdict overrides the table's optimistic one.

The dispatcher assembles; it does not re-judge. A returned severity is transcribed, not adjusted.

## 6. Finding ids

Finding ids are **domain-prefixed** and numbered within the domain: `SEC-1`, `PERF-3`, `A11Y-2`.

| Domain | Prefix |
|---|---|
| `security` | `SEC` |
| `performance` | `PERF` |
| `accessibility` | `A11Y` |
| `reliability` | `REL` |
| `code-quality` | `CQ` |
| `data` | `DATA` |
| `api-contracts` | `API` |
| `business-analysis` | `BA` |
| `seo` | `SEO` |

The prefix is what makes parallel dispatch safe: two subagents numbering from 1 at the same time
cannot collide, because their prefixes differ. **The dispatcher does not renumber.** An id assigned
by a subagent is the id in the report, in the summary, in run comparison, and in any hand-off — so a
user who quotes `DATA-4` is quoting something stable.

## 7. Failure isolation

A domain that fails, times out, returns malformed findings, or exhausts its budget is recorded as
`not run: <reason>` — in the report and in the run's coverage section — and **never aborts the other
domains**. Sibling subagents keep running and their results are assembled normally.

The malformed-return case is explicit: the dispatcher **does not repair, complete, or invent the
missing fields**. It records exactly what it received, marks that domain **unreliable for this run**,
and does not present partial findings as if they were complete ones. A finding missing mandatory
evidence is not promoted into the report to fill the file out.

A partial run is a **legitimate outcome**, as long as what did not run is named, with its reason, in
both the chat digest and coverage. A run that hides a failed domain is worse than a run that covers
less.

## 8. Writes — the dispatcher owns all of them

The dispatcher is the sole writer. It writes exactly:

- the run directory;
- one `<domain>.md` per domain that ran;
- `summary.md`, **only when two or more domains ran**;
- `docs/audit/INDEX.md`.

Nothing outside `docs/audit/`. The repository's `CLAUDE.md` is **never** touched — not appended to,
not pointed at the output. The naming scheme, the collision suffix, the immutability of a written
report, and the closed forbidden-write list are fixed in `../../core/report-model.md`; follow that
document rather than a restatement here. Reports are written in the user's language.

## 9. Run comparison

Compare this run against the most recent prior run of comparable scope, identified in 2.4, per
`../../core/report-model.md`: prior findings reported `closed` or `still open`, this run's additions
`new`, and any domain whose prior coverage does not qualify reported `not comparable`. Comparability
and match strictness are that document's rules; do not invent looser ones.

This is **run comparison**. It is not consolidation. Keep the two words in their own lanes.

## 10. Optional panel integration

Read `../../core/panel-integration.md`. The verifier panel is **offered, never assumed**: everything
here works unchanged without it, and an absent panel is a plain **coverage fact**, not an apology.
Offer it where that document says it earns its cost, and state the cost when offering.

Merging the panel's independent pass with the audit's own findings is **consolidation**. Run
comparison (section 9) and consolidation are **two different mechanisms** — one compares this run to
an earlier run, the other merges two passes over the same run — and the terms are never
interchanged, here or in the report.

## 11. Closing digest and hand-off

Return to chat a short digest — never the whole report, and never only a path. It names:

- the **full path** of the run directory;
- the domains that ran, each with its finding count, and the blockers called out;
- the domains that **did not run**, each with its reason: `not applicable` with the missing fact, or
  `not run: <reason>` from section 7;
- the **warning** that `docs/audit/**` now shows as uncommitted changes in the working tree and
  could be committed by accident along with unrelated work.

Then offer remediation: **`auditing:remediate`** reads a report out of the run directory and produces
a plan under `docs/plans/`. The audit itself changes nothing — it names the findings, names their
remediating skills, and leaves the decision to the user.
