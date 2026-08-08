# Panel integration (optional)

Optional verifier-panel pass for an audit run, via the `agent-companion` plugin.

**Dispatcher-only.** Only `skills/audit/SKILL.md` reads this file and feeds the panel. No
domain skill (`security`, `performance`, `accessibility`, `reliability`, `code-quality`,
`data`, `api-contracts`, `conventions`, or any other) invokes the panel, directly or through
this document.
A domain skill run on its own — outside the dispatcher — never touches this mechanism.

## Default: no panel is normal

Everything in this plugin works unchanged when `agent-companion` is not installed, or is
installed with manager mode off. That is the default assumption, not a degraded fallback.
When the panel does not run, the coverage section records its absence as a plain fact —
the same way a missing knowledge-tier plugin is recorded — never as an apology or a
limitation to explain away.

## Feeding the run to the panel

When manager mode is on, the dispatcher submits the run under `MODE: audit` — defined in
`agent-companion/MANAGER.md`, which owns dispatch mechanics, effort, and verdict collection.
This document only states what goes into that submission and what it is for.

The panel receives:

- the audit's scope (`full`, a single domain, or `custom`, with its stated boundaries);
- the stack snapshot the dispatcher already gathered from `stack-detection.md`;
- the list of domains that ran.

The panel is not asked to review the audit's text. It does not see the dispatcher's own
findings before producing its own. It is asked for an INDEPENDENT pass over the same
scope: its own discovery of defects, from the same stack facts, blind to what the
dispatcher already found. Per `MANAGER.md`, `MODE: audit` is non-gating — the panel returns
findings, never a pass/fail verdict, and its output is never re-fed to `MODE: audit` as if
it were itself a reviewable artifact.

Independence is the entire value of this step. A panel that only grades the dispatcher's
report duplicates the final `MODE: review` gate below and adds nothing. A panel that runs
its own scan against the same scope catches what one pass misses.

## Consolidation

**Consolidation** is the term for merging the audit's own findings with the panel's
independent pass. It is not **run comparison** — comparing this run's findings against a
previous run of comparable scope (closed / still-open / new). The two terms name different
mechanisms and are never interchanged in this document or any other in the plugin.

Applied per finding:

- **Both sides raised it** — merge into one finding; keep the stronger evidence and the
  higher of the two severities.
- **Only the panel raised it** — add it, marked panel-originated.
- **Only the audit raised it** — keep it as written; the panel's silence on a finding never
  weakens or removes it.
- **Genuine disagreement** — about whether something is a defect at all, or about its
  severity — mark the finding `disputed` in the report and state both positions in full,
  not just the side that prevailed.
- **Every `disputed` item carries a "Decision after synthesis" record** — what the
  synthesis concluded and the basis for the conclusion. An unresolved dispute is recorded
  as unresolved; it is never silently dropped toward either side.

## Final gate: MODE: review

After consolidation, the completed run passes through `MODE: review` before the report is
presented to the user. This gate checks the report's honesty, not the findings' content a
second time: that coverage claims are accurate, severity grading holds up, and the cited
evidence actually supports the finding it is attached to.

`MODE: review` can send the run back for correction — a `CHANGES_REQUESTED` verdict returns
to the dispatcher, which corrects and resubmits. It never rewrites a finding on its own
authority; the dispatcher remains the sole writer of the report at every stage.

## What the panel never does

- **Never writes files.** The dispatcher owns every write, under the `docs/audit/**`
  carve-out (Read `report-model.md`). The panel returns findings as text; nothing it
  produces lands on disk directly.
- **Never fixes code.** A panel finding is discovery only, bound by the same "audits never
  fix" rule that governs the rest of this plugin.
- **A panel failure or timeout never aborts the run.** The run proceeds without the panel
  and records the gap in coverage, exactly as a missing knowledge-tier plugin is recorded.

## Cost note

Running the panel roughly doubles the work over the audited scope — it is a second full
independent pass, not a quick cross-check. Offer it; do not assume it. It earns its cost
most reliably on a `full` scope, or on the `security` and `data` domains, where a finding
missed by a single pass is the most expensive one to have missed.
