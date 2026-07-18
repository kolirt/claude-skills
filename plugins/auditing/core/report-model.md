# Audit report model (shared contract)

Every skill in the `auditing` plugin produces its report against this contract. The audit-type
skill supplies the domain — what counts as a problem, which impact dimensions grade severity —
while this document fixes the shape: what a finding is, what evidence it must carry, how coverage
is disclosed, and what an audit is forbidden to do.

## Hard rule: audits are read-only

An audit performs **no repository mutations whatsoever**. No edits, no fixes, no refactors, no new
files, no commits, no branch or remote operations, no running of formatters or codemods.

The **sole** exception: if the user explicitly asks for the report as a file, write that one report
file and nothing else. "Explicitly" means the user asked for a file — an audit never volunteers to
create one, and never treats "give me a report" as permission to write to disk.

If a finding is trivially fixable, still do not fix it. Name the remediating skill and stop. The
user decides what gets changed.

## Output: chat-first

The report is delivered **in the conversation** by default: a short digest, then the findings, then
opportunities, then coverage. A markdown file is produced only on explicit request (above).

Write the report in **the user's language**. The skill documents themselves are English; the report
is not.

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
| `impact` | Concrete consequence in the audit type's own impact dimensions. |
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

One shared scale for all audit types:

- **blocker** — the product is broken along this path: users lose access, money is lost, or the
  thing cannot function as evidently intended.
- **major** — significant harm or loss that does not break the path outright.
- **minor** — a real but low-impact gap.

Severity is graded by **domain impact, never by code shape**. A one-line omission can be a blocker;
a large tangle of code that harms nothing is not a finding at all. Each audit-type skill declares
its own impact dimensions (money loss, user lockout, indexing harm, and so on) and grades against
those.

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

## Coverage and blind spots (mandatory closing section)

No report is complete without it. State:

- **Inspected** — what was actually read and checked.
- **Excluded** — what was deliberately not covered (out of the requested focus, out of the audit
  type's scope).
- **Blind spots** — what could not be seen from here. Name them concretely rather than as a
  disclaimer: one repository is not the whole system, so backend services, infrastructure,
  third-party behaviour, runtime data and anything decided outside this codebase are invisible to a
  static audit and may invalidate or add findings.

An audit that quietly implies full coverage it did not have is worse than one that found less.
