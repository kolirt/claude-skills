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

Read `../../core/stack-detection.md` and build the **snapshot**. Every domain subagent receives it
as an input; detection is never re-run inside a domain and the snapshot is not argued with. For
monorepos the snapshot is the list of units that document defines, not a single scalar.

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

Detect which `knowledge-*` plugins are available this session. This is a row in the marker table
like any other stack fact, and it is what decides whether **knowledge tier 3** exists for a given
domain in this run. The tier definitions and the soft-dependency rule live in
`../../core/report-model.md`; do not restate them here. Pass the result down with the snapshot.

### 2.4 Prior runs

Read `docs/audit/`, and `docs/audit/INDEX.md` if it exists, to identify the most recent prior run
and the domains it covered. This is the basis for run comparison in section 9. No prior run is a
normal state; it means every finding in this run is `new`.

## 3. The annotated domain table

Print the table for the user **before anything runs**. One row per domain: its name, a one-line
purpose, a **detection verdict**, and the reason for that verdict.

The three verdicts:

- **`recommended`** — the snapshot carries the facts this domain needs, and the domain applies to
  almost any codebase.
- **`your call`** — the domain applies, but its value depends on the project's stage or priorities,
  or it would run in a reduced mode.
- **`not applicable`** — a fact the domain requires is absent. **Name the missing fact.**

Verdicts are resolved from the snapshot at run time, per the rules below:

| Domain | Purpose | Verdict rule |
|---|---|---|
| `security` | Whether the app is safe by default: authentication, authorisation, validation, secrets, injection and rendering sinks | `recommended` with any application runtime detected; `not applicable` only when no application surface exists at all |
| `reliability` | Whether it keeps working when something fails, and whether anyone would know | `recommended` with any application runtime detected; `not applicable` when there is no runtime to audit |
| `code-quality` | Structural health: tangles, duplicated knowledge, broken boundaries, dead code | `recommended` with any detected runtime whose module graph can be resolved; `not applicable` when no source unit is readable |
| `performance` | Work the app does that it does not need to do: query shape, over-fetching, client cost | `recommended` when a data layer or a client or server runtime is present; `not applicable` when none of the three is |
| `data` | Whether the schema makes wrong data impossible: constraints, keys, migrations, money and time | `recommended` when a data-layer marker is present; `your call` when none is, since the domain then runs in its reduced API-boundary mode; `not applicable` only with neither a schema nor any data-handling surface |
| `api-contracts` | Whether the client-server contract is consistent: shapes, errors, status codes, pagination, versioning | `recommended` when an API schema is detected (full contract mode); `your call` without one, since the domain drops to client-internal consistency mode; `not applicable` with no request surface at all |
| `accessibility` | Whether the interface can be operated without sight, colour, or a mouse | `recommended` when a UI runtime or server-rendered templates are present; `not applicable` when the unit has no interface surface |
| `business-analysis` | Product integrity: broken flows, entities without lifecycle, monetization leaks, intent-vs-implementation contradictions | `recommended` when a product surface is present **and** a product/strategy description was supplied in 2.2; `your call` when a product surface is present but the description is empty, since intent is then reconstructed from code alone; `not applicable` only for a repository with no discernible product surface — a library, a build tool, infrastructure-only code |
| `seo` | Whether the crawler-facing baseline is closed: titles, canonicals, robots, sitemaps, structured data | `recommended` when a web-delivery surface is present **and** the project is publicly indexable; `your call` when a web-delivery surface exists but the project is internal or unreleased, where the SEO stake is a priority question; `not applicable` when no web-delivery surface was detected |

Every verdict is **evidence-based, never a guess**: it cites the snapshot fact that produced it, and
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

- the stack snapshot from 2.1, including the convention-plugin result from 2.3;
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
