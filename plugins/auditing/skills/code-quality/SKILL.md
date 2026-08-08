---
name: code-quality
description: Use on demand to audit the structural health of a WHOLE codebase — 'code quality audit', 'аудит якості коду', 'технічний борг', 'technical debt', 'is this codebase maintainable', 'find dead code', 'where is this code coupled', 'architecture smells'. Static read of the module graph and the code inside it — reports structure that makes safe change hard or hides a defect — tangled modules, duplicated knowledge, broken boundaries, dead and unreachable code, hidden coupling, and accumulated mess no future diff will touch. Grades harm, not taste — never a formatting, naming, or style preference, and never a linter's job. Read-only — reports findings, never fixes them. Not a performance review (auditing:performance), not a security review (auditing:security), not a test-coverage or documentation review. Reviews of a PR diff or a set of changes belong to the auditing-prs plugin.
---

# Code quality audit

Judges **structural harm, not style**. A finding here is code whose structure makes the system harder
to change safely, or hides a defect that will be shipped. Nothing else qualifies.

Anything a formatter or a linter settles — indentation, quote style, import order, line length, a name
someone would spell differently — is **out of scope**: not a finding, not even a `minor`, not an
opportunity. A large, ugly, awkward piece of code that harms nothing is not a finding at all.

The separating sentence: this domain owns **whether the code can be changed safely** — not what it costs
to run (`auditing:performance`), who can reach it (`auditing:security`), or whether the product logic is
right (`auditing:business-analysis`).

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. Under the dispatcher the **snapshot** arrives as an input: detection
is not repeated and this domain does not disagree with it. Invoked directly, it runs detection itself first.

| Fact needed | Used for | When absent |
|---|---|---|
| `manifests` (the unit declares a package), or any surface present | Resolving imports and building the module graph for the unit — a library, a CLI, or a server-less package is as auditable here as an application | Neither a manifest nor any surface present (a documentation or configuration tree): `your call` — structural findings are possible but thin, never `skipped: not applicable` |
| `architecture` (`fsd` / `flat`) | Judging cross-layer leakage against a codified layer order when `fsd` | Boundary findings rest on the import graph alone; no claim is made about layer names the project never declared |
| `test_harness` | Telling "nothing imports this" apart from "only its own tests import it" | Dead-code findings cap at `confidence: medium`; coverage records that test-only usage could not be distinguished |
| `framework` | Selecting tier 2 idiom and, for a Vue unit, whether `knowledge-vue:architecture` supplies tier 3 | Tier 2 has no ecosystem idiom to lean on; the module graph is judged on tier 1 alone |
| `convention_plugins` | Whether tier 3 exists this run, and whether convention drift is reportable at all | Tiers 1 and 2 run; **no convention-drift findings are produced**, and a coverage line names the missing tier |

This domain has no whole-domain skip: a unit that declares no manifest and has no surface is
`your call`, judged on tier 1 alone. What IS recorded in coverage, **with the fact that was missing**,
is every reduced sub-check — a capped dead-code confidence, an absent tier 2 idiom, convention drift
that could not be reported. A reduced run produces fewer findings, never invented ones and never a
guess at what a finding would have looked like.

## 1. What this domain judges

### Structural harm

- A module that must be edited for **unrelated reasons**: two callers who share nothing both force
  changes into the same file. Which two reasons, and where do they meet?
- Logic duplicated as **knowledge** — one business fact in two places that must change together to
  stay correct. `knowledge-principles:abstraction` draws the line this domain uses: text that merely
  looks alike, changes on different schedules and answers to different owners is **not duplication**
  and is not reported. "It must change together" is the test; "it looks the same" never is.
- A boundary crossed by **reaching into another module's internals** — importing past its entry point,
  depending on its file layout, relying on a structure it never published. Name the bypassed contract.
- A **god-module** every feature imports: unrelated responsibilities in one place until consumers who
  share nothing all depend on it. Judged by the consumer set, never by line count.
- An import cycle, or a dependency direction that makes one intended change ripple across modules that
  must now be edited together.

### Dead and unreachable code

- Code nothing reaches: a module no other module imports, a function no call site calls, a handler no
  surface routes to.
- A flag or configuration key with **one value** in practice, and the branch it selects.
- A branch that **cannot be taken**: a condition already decided upstream, a case a type makes
  impossible, an error path a caller cannot produce.
- An export nobody imports — with the honest caveat that an export may be a **public surface consumed
  outside this repository**. That is change-safety territory: report it as an unverified surface, put
  the assumption in `assumptions`, and never present it as a licence to delete.

### Accumulated mess outside any current diff

**This domain owns it.** `knowledge-principles:boy-scout` deliberately narrows Broken Windows to the
lines a change touches and hands everything else here — so this is where mess that no diff will ever
touch gets reported:

- A stale pattern repeated across many call sites while the newer pattern already exists beside it.
- A half-finished migration between two ways of doing one thing, two competing mechanisms for one job
  with no owner deciding which wins, or a file whose vocabulary contradicts the codebase around it.

Report the mess by the change it obstructs, never by its age or its volume.

### Hidden coupling and implicit dependencies

- An **ambient singleton** or module-level mutable value that callers read without declaring it.
- A **global read a signature does not disclose**: environment, current request, current user, clock,
  or process state consumed inside a function that advertises none of it.
- An **ordering dependency between modules that nothing enforces** — A must be initialised, imported
  or called before B, and only convention or import order keeps that true.
- A **shared mutable structure with no owner**: several modules write one object, array or store
  slice, nobody is responsible for its invariants, and the same call means two different things in
  two places.

### Comprehension hazards

Harm to safe change, not a readability opinion: the risk is that the next editor predicts the wrong
behaviour and ships a defect.

- A function whose behaviour **cannot be predicted from its name and signature** — it also writes,
  also fetches, also mutates an argument, or returns what the name does not suggest.
- Control flow that **hides a decision**: the branch that determines the outcome is buried in a side
  effect, a default, a fall-through, or an early return several layers away.
- A construct whose correctness depends on **knowing a language trick** — coercion, evaluation order,
  reference sharing, a reactivity subtlety — with nothing signalling that the trick is load-bearing.
- Handling that silently changes meaning: an absent value and a failed value made indistinguishable.

### Convention drift (tier 3 only)

- Where a **codified project convention exists** and the code contradicts it: a mandated wrapper
  bypassed, a mandated layer skipped, a mandated boundary crossed.
- Reportable **only when tier 3 is actually available this run**. Without it there is no codified
  convention to contradict, so this is **not a finding at all** — coverage states the tier was
  missing. An audit never invents a convention in order to find drift from it.
- The convention must come from a `knowledge-*` plugin. A rule the audited repository wrote down in
  its **own prose** — its `CLAUDE.md`, `CONVENTIONS.md`, ADRs, `docs/` — is not tier 3 and is not
  judged here: that is `auditing:conventions`. This domain still reports the same call site when the
  bypass harms safe change on its own, citing the harm rather than the document.

## 2. Impact dimensions

Graded by **harm to safe change**, never by size, ugliness, or age. The scale itself lives in
`../../core/report-model.md`; these are its meanings here.

- **blocker** — the structure makes a required change unsafe or effectively impossible, or hides a
  defect that will be shipped: nobody can predict what the change does, or it cannot be made without
  touching code nobody can reason about.
- **major** — a change in this area is substantially riskier or slower than it should be, or the same
  fact must be changed in several places to stay correct, so one of them will be missed.
- **minor** — a real structural gap with contained cost: it slows one area and does not spread.

A 600-line module one caller uses is not a finding; a three-line duplicated business rule is `major`.

## 3. What this domain does NOT cover

- **Cost and slow patterns** — `auditing:performance`. A **known-slow pattern is a `PERF` finding even
  though it is also structural** (a query in a loop, an N+1 access, a repeated recomputation). The
  seam runs both ways: a structural tangle with no cost claim is `CQ`; a cost claim is `PERF`.
- **Anything crossing a trust boundary** — `auditing:security`: validation, authorisation, secrets,
  injection and rendering sinks, dangerous defaults. A missing ownership check inside a tangled module
  is `SEC`, not `CQ`.
- **Failure behaviour and observability** — `auditing:reliability`: timeouts, retries, degradation,
  logging, monitoring. Error handling appears here only as a comprehension hazard.
- **Storage invariants** — `auditing:data`: constraints, nullability, uniqueness, cascades, indexes.
- **The client-server contract** — `auditing:api-contracts`: request and response shapes, versioning,
  schema-versus-implementation drift.
- **Whether the product logic is right at all** — `auditing:business-analysis`: broken flows, entity
  lifecycles, monetisation holes. Structurally sound code implementing the wrong product is `BA`.
- **Delta-scoped review of a diff or a PR** — the separate **`auditing-prs`** plugin. This domain never
  tries to be that: it reads the codebase as it stands, is not scoped to changed lines, does not
  comment on a change set.
- **The project's own written conventions** — `auditing:conventions`. The seam runs both ways: a
  bypassed wrapper is `CONV` when the audited repository's own prose mandates it, and `CQ` when the
  bypass makes change unsafe regardless of any document. Both may file on one call site, each on its
  own axis — a `CQ` finding never cites a project document as its authority.
- **Out of scope with no owner in v1** — **test coverage and test quality** (no `testing` domain) and
  **documentation quality** (no `docs` domain): readability, completeness, structure. Whether a
  document is *accurate* about the code is `auditing:conventions`; whether it is *good* is nobody's.
  Say so in coverage rather than filing it or implying a sibling covers it.

## 4. How to audit

Static reading only: nothing is run, refactored, or reformatted — no codemod, not even in check mode.
**Read the module graph before the module contents**: what imports what says more about structural harm
than any single file does.

1. Build the import graph per detected unit: entry points, module edges, cycles.
2. Rank modules by **consumer set** (who depends on this) and **fan-out** (what this depends on).
   God-modules and boundary breaks are visible here before any file is opened.
3. Read the modules the graph implicated, plus the ones one intended change would have to touch
   together, for duplicated knowledge, hidden coupling, and comprehension hazards.
4. Read what the graph never reached, for dead and unreachable code.

**Establishing "nothing imports this" honestly.** A grep for the name is not proof. Check static
imports, re-exports and barrels, dynamic and lazy imports, string-keyed registrations, framework
conventions that load files by path or name, build and config references, and test-only usage. If that
enumeration could not be exhaustive, the finding is `confidence: medium` at best, the gap goes in
`assumptions`, and coverage names what was not searchable from here. An export that may be consumed
outside this repository is never asserted dead. For a **missing** surface, use the `expected surface
absent` locator from `../../core/report-model.md`.

**A structural claim cites the modules on both sides.** "This module is coupled" is not a finding;
"module A reaches past module B's entry point into its internals, so a change to B's layout breaks A"
is. Name both ends, and name the change that becomes unsafe.

**Findings versus notes.** A finding names the structure, the change it obstructs, and the mechanism
connecting them. A structure you would have written differently, obstructing no change, is an
opportunity or nothing — and if a linter or formatter would settle it, it is nothing.

## 5. Knowledge tiers

- **Tier 1 — universal invariants.** Most of section 1: duplicated knowledge must change together, a
  module's internals are not a contract, unreachable code misleads readers, an undeclared dependency is
  a hidden one, behaviour unpredictable from a signature is a hazard. Always applied.
- **Tier 2 — ecosystem general practice.** How the detected framework normally structures modules,
  what its idiomatic boundaries are, which of its constructs carry known comprehension traps. A
  framework idiom is **not** a finding — the idiom outranks architectural purity.
- **Tier 3 — codified project conventions.** Two sources, both **soft**:
  - `knowledge-principles:<rule>` — the ten universal rules; a finding cites the **specific rule**, e.g.
    `knowledge-principles:module-boundaries` for a bypassed contract, `knowledge-principles:abstraction`
    for duplicated knowledge.
  - `knowledge-vue:architecture` — architecture-integrity questions in a Vue project: import cycles,
    god-modules, dead modules, cross-layer leakage.

  Either source absent (not installed this session, or the project is not Vue) means the domain
  **degrades to tiers 1 and 2** and names the missing tier in coverage — `tier 3 unavailable —
  knowledge-principles not present in this session`. Never an abort, and a missing tier is a
  **coverage fact, not a finding**: no severity, no blame on the code.

**Precedence and proportionality are honoured, not re-derived.** Read `knowledge-principles:principles`
for the index of the ten rules and the conflict authority. Two consequences bind this audit:

1. **A codified project convention beats a universal principle.** A mandated wrapper, factory,
   registry, or validation layer is **compliance, not excess**; reporting it as indirection is a false
   positive, however few call sites it has.
2. **Rules proportionality declares silent for a kind of code are not reported for that code.** A
   throwaway script or spike is not graded for abstraction. State the level wherever a finding would
   otherwise read as ambiguous.

**Legacy code that predates a convention is not a principle violation** and is never reported as one. It
falls in this domain as **accumulated mess**, graded on the harm it does to change — never on the
convention it was written before.

**The Laravel gap, stated honestly.** No `knowledge-laravel` plugin exists, so for a Laravel codebase
tier 3 is empty apart from the universal rules. Coverage says exactly that: it must not imply that the
project's own backend conventions were checked, and no convention-drift findings are produced there.

## 6. Report

Read `../../core/report-model.md` and follow it exactly — output location, finding fields, evidence
locators, severity and confidence, opportunities, run comparison, coverage. Nothing from it is restated.

- **Finding-id prefix: `CQ`** — `CQ-1`, `CQ-2`, … stable within the report.
- **Remediating skill.** Point at the **specific rule**, never at the umbrella:
  `knowledge-principles:module-boundaries`, `knowledge-principles:abstraction`,
  `knowledge-principles:state`, `knowledge-vue:architecture`. A bare `knowledge-principles:principles`
  is an index, not a fix, and is not used here. Leave the field empty when no skill owns the fix.
  Always fully qualified.
- The bridge to fixing is `auditing:remediate`. This audit names findings and stops.
