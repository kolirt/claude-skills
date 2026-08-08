---
name: conventions
description: Use on demand to audit whether a WHOLE codebase obeys the conventions the project itself wrote down — 'conventions audit', 'аудит конвенцій', 'чи дотримуємось власних правил', 'does the code match our CLAUDE.md', 'is our CONVENTIONS.md still true', 'документація розходиться з кодом', 'наші правила ще актуальні'. Static read of the project's own prose documents (CLAUDE.md, AGENTS.md, CONVENTIONS.md, CONTRIBUTING.md, docs/, ADRs, README) against the code they describe — reports rules the code contradicts, statements the codebase has outgrown, and documents that contradict each other. Judges declared-versus-actual only: never whether a rule is a good one, and never anything a formatter or a linter settles. Read-only — reports findings, never fixes them and never edits a document. Not a structural-harm review (auditing:code-quality), not a product-intent review (auditing:business-analysis), not an API-contract review (auditing:api-contracts). Conventions codified in knowledge-* marketplace plugins belong to code-quality's tier 3, not here. Audits of a PR diff or a set of changes belong to the auditing-prs plugin.
---

# Conventions audit

Judges **declared versus actual**. A finding here is a divergence between what the project wrote down
about itself and what its code does. Nothing else qualifies.

The rule is taken as given. Whether it is a *good* rule — whether the mandated wrapper is worth
having, whether the layer split was wise — is not audited here and is not a finding. This domain
asks one question: the project said this; is it true?

Anything a formatter or a linter settles — indentation, quote style, import order, line length — is
**out of scope** even when a document mandates it, exactly as in `auditing:code-quality`: not a
finding, not even a `minor`. A rule a machine already enforces on every commit needs no audit.

The separating sentence: this domain owns **the project's own written rules versus its code** — not
whether the structure is safe to change (`auditing:code-quality`), whether the product is coherent
(`auditing:business-analysis`), or whether the API does what its document says (`auditing:api-contracts`).

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. Under the dispatcher the **snapshot** arrives as an input:
detection is not repeated and this domain does not disagree with it. Invoked directly, it runs
detection itself first.

| Fact needed | Used for | When absent |
|---|---|---|
| `convention_docs` | Whether the project declared anything at all — the corpus this domain judges against | `skipped: not applicable` wholesale in that unit, recorded in coverage with the missing fact named |
| `framework` | Reading a descriptive claim in the idiom it was written in — what "a store", "a route", "a migration" means in this project | Descriptive claims are checked against the code alone; a claim whose vocabulary cannot be resolved caps at `confidence: low` |
| `architecture` (`fsd` / `flat`) | Resolving a rule that names layers or placement | A placement rule is judged on the paths it names literally; no layer order is assumed |
| `convention_plugins` | Resolving a rule that defers to a `knowledge-*` plugin by name instead of stating its content | The deferring rule is read on its own text; coverage names the missing tier |

`convention_docs` absent means the project declared nothing this domain could hold it to, so there is
nothing to audit — not a thin run, a skip. A `README.md` alone does not set that fact (see
`../../core/stack-detection.md`), though a README that IS present is read as part of the corpus once
the domain runs.

## 1. What this domain judges

### What counts as a rule

A document is prose, and most of its sentences are not rules. Two tests decide, and a sentence that
passes neither is not audited:

- **The imperative test.** The sentence tells someone what to do or not do: "always", "never",
  "must", "do not", "use X for Y", "X goes in Z". It is checked against the code for **violation**.
- **The descriptive test.** The sentence asserts a fact about this codebase: "stores are
  module-reactive", "all requests go through the http wrapper", "the app is server-rendered". It is
  checked against the code for **truth**.

Not a rule, and never audited: rationale ("because it keeps imports shallow"), examples and code
samples illustrating a rule stated elsewhere, historical notes ("we used to…"), and intentions
("we plan to", "eventually", "TODO"). An aspiration the project has not adopted cannot be violated.

**Scope is part of the rule.** "All requests go through the wrapper" read literally covers tests,
scripts and migrations too. When the document does not say, the rule's scope is ambiguous — that
lowers `confidence`, and it never licenses inventing a violation in the area the document never
addressed.

**Inactive documents are not rules.** An ADR marked `superseded`, `deprecated`, `rejected` or
`draft` states no active rule: it neither produces violations nor contradicts the document that
replaced it. Where a document carries no status at all, say so in `assumptions` rather than
assuming it is live.

### Rule contradicted by code

- A **mandated mechanism bypassed**: the document requires a wrapper, a helper, a factory, or a
  single entry point, and code reaches past it to the thing underneath.
- A **mandated placement ignored**: the document says a kind of file belongs in a named location,
  and instances of that kind live elsewhere.
- A **forbidden construct present**: the document names something as never to be used, and it is
  used.
- A **mandated sequence skipped**: the document requires a step before another, and a call site
  omits it.

Cite the sentence, cite the code, and name the mechanism connecting them. A finding that quotes the
rule but not a contradicting call site is not a finding.

### Statement contradicted by the codebase

The document's claim about the project is false — the code has moved and the document has not.

- A **named dependency or tool the project does not use**: the document says the project is built on
  something that is absent from the manifests and from the code.
- A **mechanism described that no longer exists**: the document explains how a thing works, and that
  thing was replaced or removed.
- A **claim that is true in part**: the document states something universally and the code has
  undeclared exceptions. Reportable only when the exception is undeclared — a documented exception is
  the document being accurate.

This shape is what makes a convention document dangerous rather than merely stale: an agent or a new
contributor reads it as truth and writes code against a mechanism that is not there.

### Rules that contradict each other

Two of the project's own documents give incompatible instructions on one subject, so no reader can
satisfy both. Cite both sentences and both documents, and state what a reader is left unable to
decide. Where one document is the more specific or the more recent and says so explicitly, that is
resolution, not contradiction — report it only when nothing in the documents settles it.

## 2. Impact dimensions

Graded by **how far the project's real state has drifted from the state it declared** — that is this
domain's impact. Two things measure it: the **force** of the sentence (an absolute rule outranks a
preference) and the **spread** of the divergence (systematic outranks isolated). The scale itself
lives in `../../core/report-model.md`; these are its meanings here.

- **blocker** — an absolute rule ("never", "always", "must") is contradicted systematically across
  the codebase, or a descriptive claim is false about a **central** mechanism, or two documents
  mandate opposite things on one subject. In each case the document actively misleads whoever reads
  it before writing code.
- **major** — an absolute rule is contradicted in isolated places, or a descriptive claim is false
  about a peripheral mechanism, or two documents conflict on a narrow subject.
- **minor** — a softly worded rule ("prefer", "usually", "where possible") is not followed, or a
  stale detail that changes nothing a reader would do differently.

**Confidence** follows the text, not the code: a rule stated unambiguously and contradicted
explicitly is `high`; a rule whose scope the document leaves open is `medium` at best; a rule whose
subject cannot be resolved in this project's vocabulary is `low`.

A rule followed everywhere except one legacy file is `minor` unless the rule is absolute. A single
false sentence about the central data-access mechanism is `blocker` even though it is one sentence.

## 3. What this domain does NOT cover

- **Whether the rule itself is any good.** A badly chosen convention, obeyed by the code, is not a
  finding here and is not an opportunity. This domain has no opinion on the project's rules.
- **Anything a formatter or a linter settles** — mirroring `auditing:code-quality`'s own exclusion.
  A documented formatting preference is enforced by a machine or it is not; either way it is not
  audited here.
- **Process, workflow and git rules.** "Commit only when asked", "never add a co-author trailer",
  "run lint before pushing", "open a PR per task" — these are not auditable rules for this domain
  **by definition**, because no static read of the code can establish whether they were followed.
  They are outside the domain's subject, not excluded from a particular run, so the report does not
  enumerate them.
- **Conventions codified in `knowledge-*` marketplace plugins** — those are `auditing:code-quality`'s
  tier 3. This domain reads only what the audited repository itself wrote down.
- **Undocumented de-facto conventions.** Code that consistently does something the documents never
  mention is not a divergence. "The documentation should say more" is not a finding.
- **Documentation quality** — accuracy is judged here, but readability, completeness, structure and
  tone are not, and no sibling domain owns them either. Say so in coverage rather than filing it.
- **Structural harm** — `auditing:code-quality`. The seam runs both ways: a bypassed wrapper is
  `CONV` when the project's own document mandates it, and `CQ` when the bypass harms safe change
  regardless of any document. Both sides may file on one call site, each stating its own axis; a
  `CONV` finding never claims structural harm and a `CQ` finding never cites a project document as
  its authority.
- **Product intent** — `auditing:business-analysis`. The seam is the audience of the sentence: a
  document promising **behaviour to a user** that the code does not implement is `BA`; a document
  stating an **engineering rule** the code does not follow is `CONV`.
- **The documented API contract** — `auditing:api-contracts`. A contract document contradicted by
  the implementation is `API`, whichever file it lives in.
- **The closing ownership rule.** When a divergence is about a subject another domain owns —
  authorisation, storage invariants, failure handling, response shape, indexing — that domain files
  it on its own axis and this domain does not duplicate it. `CONV` files only where the axis is
  "the project's own written rule versus its code".
- **Delta-scoped review of a diff or a PR** — the separate **`auditing-prs`** plugin. This domain
  reads the codebase as it stands and is not scoped to changed lines.

## 4. How to audit

Static reading only: nothing is run, nothing is refactored, and **no document is edited** — a stale
sentence is reported, never corrected in place. Read the documents before the code: the corpus of
rules is what makes any part of the code worth looking at.

1. Collect the corpus from the `convention_docs` marker outward: the named convention files, the
   ADR tree, the documentation tree, and the README. Record which documents were read.
2. Split each document into candidate sentences and classify each one — imperative, descriptive, or
   neither — by the tests in section 1. Discard the "neither" bucket and the inactive documents.
3. For each imperative rule, locate the code it governs and look for the contradicting call site.
   Absence of a violation is not a finding; say nothing.
4. For each descriptive claim, verify the fact it asserts against manifests and code.
5. Compare rules across documents last, once the corpus is classified, for the contradiction shape.

**A finding cites the sentence.** Quote the document text verbatim with its file and line, quote or
locate the contradicting code, and state the mechanism between them. A finding that paraphrases the
rule is not verifiable by the reader and is not filed.

**Do not invent a rule to find drift from it.** Where the documents are silent, the code is correct
by definition for this domain. Where a rule's scope is ambiguous, lower confidence rather than
resolving the ambiguity in the direction that produces a finding.

**For a rule about something absent** — a mandated wrapper that does not exist anywhere — use the
`expected surface absent` locator from `../../core/report-model.md`.

## 5. Knowledge tiers

- **Tier 1 — universal invariants.** Everything in section 1: a written imperative is checkable
  against the code it governs, a factual claim is either true of this codebase or it is not, two
  incompatible mandates cannot both be satisfied, an inactive document states no rule. Always
  applied. This domain's core work needs nothing else.
- **Tier 2 — ecosystem general practice.** Knowing the detected framework well enough to resolve
  what a descriptive claim refers to and to recognise the mechanism it names. Without it a claim can
  still be checked literally, but a claim written in framework vocabulary caps at lower confidence.
- **Tier 3 — codified project conventions.** The matching `knowledge-*` plugin, **soft**, exactly as
  everywhere else in this plugin. It has one job here: a project document may **defer** to such a
  plugin by name rather than restating its content ("modals follow `knowledge-vue:modals`"), and the
  plugin is what resolves that sentence into a checkable rule. Absent, the deferring rule is read on
  its own text, the finding caps at `confidence: low`, and coverage names the missing tier —
  `tier 3 unavailable — knowledge-vue not present in this session`. Never an abort, and a missing
  tier is a **coverage fact, not a finding**.

**The audited repository's own documents are not a tier.** They are this domain's subject and its
evidence. Their absence is settled by the `convention_docs` fact in preflight, not by tier
degradation, and no tier is ever hard-required here.

## 6. Report

Read `../../core/report-model.md` and follow it exactly — output location, finding fields, evidence
locators, severity and confidence, opportunities, run comparison, coverage. Nothing from it is restated.

- **Finding-id prefix: `CONV`** — `CONV-1`, `CONV-2`, … stable within the report.
- **Evidence is two-sided.** Every finding carries a document locator (file and line of the quoted
  sentence) alongside the code locator. A finding with only one side is incomplete.
- **Remediating skill.** Usually empty: the fix is either a code change or a document correction,
  and no skill owns the project's own prose. Name a skill only where the project's rule defers to
  one, and then name the specific skill, fully qualified — never an umbrella index.
- **Coverage records the corpus**: which documents were read, which were treated as inactive and
  why, and any document that could not be classified. It does not enumerate the project's process
  rules — those are outside this domain's subject, not an exclusion from this run.
- The bridge to fixing is `auditing:remediate`. This audit names findings and stops.
