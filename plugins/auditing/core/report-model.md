# Audit report model (shared contract)

Every skill in the `auditing` plugin produces its report against this contract. The domain skill
supplies the domain — what counts as a problem, which impact dimensions grade severity — while this
document fixes the shape: where reports are written, what a finding is, what evidence it must carry,
how coverage is disclosed, and what an audit is forbidden to do.

## Hard rule: audits write only `docs/audit/**`

An audit performs **no repository mutations** outside its own output tree. The permitted set is a
**closed list**, not an illustration:

- `docs/audit/YYYY-MM-DD-<scope>/` — the run directory and the report files inside it.
- `docs/audit/INDEX.md` — the run index.

Nothing else. Explicitly forbidden, in every case, including when the change would be trivial:

| Forbidden | Notes |
|---|---|
| Source files | No edits, no fixes, no refactors, no new modules. |
| Configuration | Build config, env files, CI definitions, editor or tool config. |
| Dependency manifests | No adds, removals, upgrades, or lockfile regeneration. |
| Tests | An audit does not write a failing test to prove a finding. |
| Branches and commits | No branch, checkout, stash, commit, tag, or remote operation. |
| Formatters and codemods | Not even in check-and-write mode, not on files it just read. |
| The repository's `CLAUDE.md` | Never appended to, never pointed at the audit output. |

`CLAUDE.md` is named explicitly because it is persistent agent-instruction state: a write there
changes how every future session behaves. Naming it keeps the rule from being read as an oversight
that a helpful agent may fill in.

If a finding is trivially fixable, still do not fix it. Name the remediating skill and stop. The
user decides what gets changed.

Because the audit does write files, its closing digest **warns the user** that `docs/audit/**` now
shows up as uncommitted changes in the working tree and could be committed by accident along with
unrelated work.

## Output: the file contract

A run writes a **run directory**:

```
docs/audit/YYYY-MM-DD-<scope>/
```

- `<scope>` is `full` (every domain), a single domain name (`security`), or `custom` (an explicit
  subset the user named).
- Same-day collisions get a numeric suffix: `-2`, `-3`. An existing run directory is never reused.

Inside it:

- One `<domain>.md` per domain that actually ran — `security.md`, `performance.md`, and so on.
- `summary.md` **only when two or more domains ran**. A single-domain run does not get one; its one
  domain file is the whole report.

Reports are **immutable** once written. A later fix is never recorded by editing an old report, and
an old report is never corrected, annotated, or re-scored. A new run records the new state; run
comparison (below) is what connects the two.

Chat still returns a **short digest plus the path to the run directory**: headline counts, the
blockers, the uncommitted-files warning. Never only a path, and never the whole report pasted back
into the conversation.

Write the report in **the user's language**. The skill documents themselves are English; the report
content is not.

## `INDEX.md` upkeep

`docs/audit/INDEX.md` is the only index the audit maintains.

- One line per run, keyed by the run directory name, recording date, scope, and domains covered.
- The operation is **idempotent**: re-running against an existing index updates the matching line in
  place and never appends a duplicate.
- If the file is absent it is created with a `# Audits` heading plus the single line for this run.

Nothing outside `docs/audit/` is ever pointed at, updated, or created to advertise the index. In
particular the repository's root `CLAUDE.md` is never given a pointer to it.

The honest consequence: a future session is **not** told the index exists. So the dispatcher names
the full path in its closing digest, and prior runs are found by reading `docs/audit/` directly.

## Scope and evidence sources (declare before findings)

Open every report by stating, in two or three lines:

- **Audit unit** — the whole application by default. If the user supplied a focus (a domain, a
  flow, an area), name it and state that the audit is bounded to it.
- **Evidence sources actually used**, in priority order:
  1. an explicit product/context description supplied by the user in this session,
  2. repository documentation (README, `docs/`, specs, ADRs),
  3. reconstruction from the code itself.

  Where sources conflict, the higher-priority source wins, and the conflict itself is reported as
  a finding (an implementation contradicting a stated intent is a real problem, not noise).

Stack facts are not evidence sources of their own — they come from the detection snapshot. Read
`stack-detection.md` for how a fact is established and what a domain does when one is unavailable.

## Knowledge tiers

Every finding rests on one of three tiers, and the report states which knowledge it actually had:

| Tier | Source | Availability |
|---|---|---|
| 1 — universal invariants | Holds in any stack; always applied. | Always. |
| 2 — ecosystem general practice | The model's own knowledge of the detected stack. | Always. |
| 3 — codified project conventions | The matching `knowledge-*` plugin's documented rules. | Only when that plugin is available in the session. |

Every dependency on a knowledge plugin is **soft**. An absent plugin means tiers 1 and 2 run
normally and the missing tier is **named in the coverage section**. There is no hard abort anywhere
in this plugin.

A missing tier is disclosed, never silently skipped. "Tier 3 unavailable — `knowledge-<x>` not
present in this session" is a **coverage fact, not a finding**: it carries no severity, blames no
code, and never appears among the defects.

## Finding model

Each finding carries these fields. Present them as a table, a list, or headed blocks — whatever
reads best for the volume — but never drop `evidence`, `severity`, or `confidence`.

| Field | Meaning |
|---|---|
| `id` | Stable short id within the report (`BA-3`, `SEO-7`) so the user can refer to it. |
| `area` | Which part of the product/project it belongs to. |
| `problem` | What is wrong, in one sentence, stated as an observable fact. |
| `mechanism` | Why it is wrong — the causal chain from this code/absence to the impact. |
| `evidence` | See "Evidence locators" below. Mandatory. A finding without evidence is not a finding. |
| `impact` | Concrete consequence in the domain's own impact dimensions. |
| `severity` | `blocker` \| `major` \| `minor` — see "Severity". |
| `confidence` | `high` \| `medium` \| `low` — see "Confidence". |
| `assumptions` | What had to be assumed for this to hold. Empty is allowed; hidden assumptions are not. |
| `remediating skill` | Optional. One **or more** fully-qualified skill names that own the fix, e.g. `knowledge-seo:meta-tags`, or `knowledge-seo:javascript-seo · knowledge-seo:url-structure`. Always fully qualified — a bare `robots` is ambiguous across plugins. Leave empty when no skill owns the fix. |

### Evidence locators

Three forms are valid:

- `path/to/file.ext:123` — the ordinary case, pointing at the code that demonstrates the problem.
- A **flow id** — when the problem is a property of a multi-step path rather than one line; define
  the flow in the report (its steps and where each lives) so the id is resolvable.
- `expected surface absent` — when the problem is that something is **missing**. Missing code has
  no `file:line`. State where it was expected and how you established it is not elsewhere.

Never invent a line number to satisfy the field. `expected surface absent` exists precisely so that
absence does not get dressed up as a citation.

## Severity

One shared scale for all domains:

- **blocker** — the product is broken along this path: users lose access, money is lost, or the
  thing cannot function as evidently intended.
- **major** — significant harm or loss that does not break the path outright.
- **minor** — a real but low-impact gap.

Severity is graded by **domain impact, never by code shape**. A one-line omission can be a blocker;
a large tangle of code that harms nothing is not a finding at all. Each domain skill declares its
own impact dimensions (money loss, user lockout, indexing harm, and so on) and grades against those.

## Confidence

Tied to evidence strength and source priority:

- **high** — corroborated by an explicit user statement or repo documentation, and visible in code.
- **medium** — clear in code, with no external source confirming the intent.
- **low** — inferred, or resting on assumptions that could not be checked. Findings that exist only
  because of a reconstruction from code, with nothing external to confirm the intent, are `low` or
  `medium` — never `high`.

State missing evidence rather than lowering ambition silently: if a check could not be performed,
that belongs in Coverage, not in a quietly omitted finding.

## Opportunities / recommendations (separate section)

Proactive ideas — things that are not broken but could be better — go in their own section, after
the findings, never mixed into them.

Every item here is explicitly marked as **judgment, not fact**. It carries no severity (it is not a
defect) and should say what it assumes about goals or priorities that were not stated. The reader
must be able to tell at a glance which part of the report is "this is wrong" and which is "I think
you could".

## Run comparison

A run reads the **most recent prior run of comparable scope** and reports every prior finding as
`closed` or `still open`, and each finding this run adds as `new`.

Comparability is strict. A prior run is comparable for a domain only when both hold:

1. that prior run **covered the same domain**, and
2. that domain **completed successfully** in it.

A domain that was excluded, failed part-way, or ran under a different scope is reported as **`not
comparable`** — never as `closed`. Absence of a finding in an incomparable run is not evidence that
the problem is gone.

Findings are matched on **domain + location + substance**. An exact match is asserted as the same
finding. An uncertain match is labelled **probable** and says why (the file moved, the surrounding
code changed) — never asserted.

**Run comparison is not consolidation.** These are two different mechanisms and the terms never
interchange:

- **run comparison** — this run against a previous run of comparable scope: closed / still open /
  new / not comparable.
- **consolidation** — this run's own findings merged with the verifier panel's independent pass.
  Owned by `panel-integration.md` and available to the dispatcher only; read that document for it,
  and do not restate it here.

## Coverage and blind spots (mandatory closing section)

No report is complete without it. State:

- **Inspected** — what was actually read and checked.
- **Excluded** — what was deliberately not covered (out of the requested focus, out of the domain's
  scope, or a stack fact that made the check not applicable).
- **Tiers available** — which knowledge tiers were in play, and every tier 3 that was unavailable.
- **Comparison basis** — which prior run this one was compared against, and every domain reported
  `not comparable`.
- **Blind spots** — what could not be seen from here. Name them concretely rather than as a
  disclaimer: one repository is not the whole system, so backend services, infrastructure,
  third-party behaviour, runtime data and anything decided outside this codebase are invisible to a
  static audit and may invalidate or add findings.

An audit that quietly implies full coverage it did not have is worse than one that found less.

## Closing hand-off

The report ends by naming the bridge to fixing: **`auditing:remediate`** reads a report out of a run
directory and produces a plan under `docs/plans/`. The audit itself changes nothing — it names the
findings, names their remediating skills, and hands the decision to the user.
