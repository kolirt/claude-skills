---
name: remediate
description: Use to turn an existing audit report into a fix plan — 'remediate', 'turn the audit into a plan', 'fix the findings', 'plan the remediation', 'план по аудиту', 'виправити знайдене', 'план по звіту'. Reads a report out of docs/audit/ and writes exactly one plan under docs/plans/ that planning:implement can execute. Does NOT audit: a request to audit, review, or check a project belongs to the auditing domain skills or the auditing:audit dispatcher. Does NOT plan new features or refactors — planning:brainstorm owns that; this skill plans only from findings that already exist in a written report.
---

# remediate — from audit report to fix plan

The bridge between an audit and a fix. It reads findings that already exist, has the user choose
which ones to act on, and writes one plan. It diagnoses nothing, changes no code, and touches no
report.

This is the only skill in the `auditing` plugin that writes outside `docs/audit/`, and it writes
exactly one place: `docs/plans/`.

## 0. Input — the report to plan from

| Input | Scope |
|---|---|
| A run directory — `docs/audit/YYYY-MM-DD-<scope>/` | Every `<domain>.md` inside it. |
| A single `<domain>.md` file | That domain's findings only. |
| Nothing named | Resolve with the user before reading anything. |

To resolve an unnamed input: read `docs/audit/INDEX.md` if it exists, list what is actually present
under `docs/audit/`, and ask which run. Never silently assume "the newest" — a stale run plans stale
work. If `docs/audit/` holds no runs, say so and stop; this skill does not run an audit to create one.

`summary.md` is a reading aid, never the source. Findings are taken from the `<domain>.md` files,
which carry the ids, evidence, severity and confidence.

Read `../../core/report-model.md` for the run-directory layout and for the finding fields this skill
consumes.

### The report is immutable input

A report is never edited here: not annotated, not re-scored, not marked as fixed, not appended to
with a pointer at the plan. Findings that the resulting work closes are recorded by a **later audit
run**, whose run comparison reports them as `closed`. That is the mechanism — read
`../../core/report-model.md`; do not invent a second one.

## 1. Selection — what goes into the plan

Present the findings grouped by severity — `blocker`, `major`, `minor` — one short line each: `id`,
`problem`, `confidence`, and the `remediating skill` the report named, if any. Then offer:

- **blockers only**
- **blockers and majors**
- **manual pick** — the user names the finding ids

Opportunities and recommendations are a separate section of the report and are **not** offered by
default. They are judgment, not defects; include one only if the user asks for it by name.

A finding whose `confidence` is `low` is shown with that fact visible, so the user can drop it. Say
plainly that it is unverified and inferred: a plan built on an unverified finding spends the
executor's time on work that may not be needed. This skill does not re-check it (see section 5) — the
user decides whether it stays in.

**Selection is confirmed with the user before any file is written.** No plan file, no `INDEX.md`
line, nothing on disk until the set is agreed.

## 2. What the plan contains

The plan follows the plan-document shape that `planning:brainstorm` defines — Goal, Context,
Approach, Steps, Out of scope, Risks / open questions — and must be self-contained enough for
`planning:implement` to execute without having seen the report or this conversation.

For each selected finding, the plan states:

- the **finding id** it comes from, so every step is traceable back to the report;
- **what must change** — the work, concretely, at real paths taken from the finding's `evidence`;
- the **fully-qualified remediating skill** the report named, if any, so the executor uses the
  project's own convention rather than improvising a fix.

The plan does **not** re-derive the diagnosis. The report is the evidence; the plan is the work. Copy
across only what the executor needs to act — problem, location, remediating skill — and cite the
finding id for the rest. Restating `mechanism` and `impact` at length turns a work order back into an
audit.

Where a fix depends on a decision only the user can make — a product choice, a trade-off between two
conventions, which of two contradicting sources is authoritative — the plan **states the open
question** under Risks / open questions rather than picking silently. A finding whose fix is entirely
gated on such a decision goes in as a decision item, not as a step pretending to be executable.

Where a finding's `evidence` is `expected surface absent`, the step says where the surface must be
created; there is no line to edit.

Order the steps by severity first, then group by area so an executor touches a given part of the
codebase once.

## 3. Output conventions — follow `planning`, with one exception

- The plan is written to `docs/plans/` under the dated-slug filename convention that
  `planning:brainstorm` defines, including its collision handling.
- Its line is added to `docs/plans/INDEX.md` under the same idempotent upkeep rule
  `planning:brainstorm` defines — one line per plan, keyed by the link target.

Follow those two by reference. Do not restate the slug or index rules here; `planning:brainstorm` is
their single source.

**The exception: the root `CLAUDE.md` pointer is NOT written.** `planning:brainstorm` appends a plans
pointer to the repository's root `CLAUDE.md`; this skill does not, ever, even when `CLAUDE.md` has no
such pointer yet and adding one would be a single line. `CLAUDE.md` is persistent agent-instruction
state — a write there changes how every future session in this repository behaves — and the
`auditing` plugin's write carve-out excludes it in every skill, for audit output and plan output
alike. Read `../../core/report-model.md` for the carve-out itself.

The consequence is accepted and stated to the user: if the pointer does not already exist, a future
session is not told `docs/plans/INDEX.md` exists. So name the plan's full path in the closing message,
and mention that `docs/plans/**` now shows as uncommitted changes in the working tree.

## 4. When the `planning` plugin is unavailable

The dependency on `planning` is **soft**, as every dependency in this plugin is. There is no hard
abort.

If `planning:brainstorm` is not available in the session, still produce the plan document. Recover
the conventions from the repository's existing `docs/plans/` files — filename pattern, plan section
headings, `INDEX.md` line format — and follow what is actually there. Where a convention cannot be
established from the repo (no existing plans, or inconsistent ones), pick a reasonable shape and
**state in the plan itself which conventions could not be confirmed**, so a later session can
reconcile it. The `CLAUDE.md` exception above still holds; a missing `planning` plugin does not
license the write.

## 5. What this skill never does

- Never edits code, configuration, dependencies, or tests — it plans the fix, it does not apply it.
- Never edits, annotates, re-scores or supersedes a report, and never writes anything under
  `docs/audit/`.
- Never writes the repository's `CLAUDE.md`, or any file outside `docs/plans/`.
- Never re-runs an audit, or re-reads the codebase to "verify" a finding. If a finding looks wrong,
  say so with the reason and let the user drop it or order a fresh audit.
- Never invents findings not present in the report, and never widens the selection the user confirmed.
- Never commits, branches, or pushes.
- Never starts implementing the plan. Hand the path to `planning:implement`.

Answer in the user's language; the plan document itself is written in the user's language too.
