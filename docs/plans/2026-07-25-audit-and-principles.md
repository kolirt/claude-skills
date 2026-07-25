# Plan: Audit system and programming principles

## Goal

Grow the `auditing` plugin from two skills into a whole-application audit system with a master
dispatcher, and create a new `knowledge-principles` plugin holding ten always-on programming rules
that the audit system grades against.

Success criteria:

- [ ] `knowledge-principles` exists: umbrella skill + 10 rule skills, each with `references/vue.md`
      and `references/laravel.md`, plus `core/precedence.md` and `core/proportionality.md`, plus a
      working `SessionStart` hook (`hooks/hooks.json` **and** an executable `hooks/session-start`).
- [ ] `plugins/auditing/core/report-model.md` is file-first (`docs/audit/`) with a narrow read-only
      carve-out limited to `docs/audit/**`, and **retains** every field and section it defines today.
- [ ] `plugins/auditing/core/stack-detection.md` and `core/panel-integration.md` exist; every audit
      skill reads stack-detection, and only the dispatcher reads panel-integration.
- [ ] Seven new audit skills exist: `security`, `performance`, `accessibility`, `reliability`,
      `code-quality`, `data`, `api-contracts`.
- [ ] `auditing:audit` (dispatcher) and `auditing:remediate` exist.
- [ ] `business-analysis` and `seo` are retrofitted to the new contract; `seo` degrades softly
      instead of aborting, and its frontmatter + marketplace description no longer say "REQUIRES".
- [ ] `knowledge-vue` gains only the architecture rules that `core/architectures/fsd.md` and
      `non-fsd.md` do not already cover, exposed through a named skill.
- [ ] `python3 plugins/knowledge/test/validate.py` → `ok: structure valid`.
- [ ] `bash .claude/skills/creating-plugins/scripts/validate.sh` passes.
- [ ] Prose in every new/changed plugin file is English. Cyrillic is permitted **only** inside
      `description:` trigger phrases, matching the existing bilingual triggers in this repo.

## Context

### Repository

`claude-skills` is a Claude Code plugin marketplace owned by `kolirt`. Plugins live in
`plugins/<name>/` with `.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, optional `core/`
shared docs, optional `references/`, optional `hooks/`.

Existing plugins: `agent-companion` 0.5.3, `auditing` 0.1.0 (`business-analysis`, `seo`),
`auditing-prs` 0.3.0, `knowledge` 0.2.0 (`capture` + `test/validate.py`), `knowledge-seo` 0.1.3,
`knowledge-vue` 0.3.0, `planning` 0.2.0, `terse` 0.2.0.

### Verified facts about the repo (do not re-derive)

- **Hooks are two files.** `plugins/<p>/hooks/hooks.json` is identical across `knowledge-vue`,
  `knowledge-seo` and `terse` (292 bytes): a `SessionStart` entry with
  `"matcher": "startup|clear|compact"` and one command hook running
  `"\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\""` with `"async": false`. The actual text lives in
  the sibling `hooks/session-start`, an **executable** script (mode `755`, ~1.5–2 KB) that emits the
  `<EXTREMELY_IMPORTANT>` block. Copy both; a `hooks.json` alone does nothing.
- **Marketplace validation exists**: `.claude/skills/creating-plugins/scripts/validate.sh` checks
  required fields, that each `source` path exists and holds a `plugin.json`, that the plugin name
  matches the entry, and that entry version equals `plugin.json` version. There is also
  `.claude/skills/creating-plugins/scripts/new-plugin.sh` for scaffolding.
- **`knowledge-vue` already documents architecture**: `core/architectures/fsd.md` has
  `## 4. Dependency rules`, `## 5. Slice and segment rules`, `## 7. 07-shared segments`,
  `## 8. Routing buckets are NOT interchangeable`; `core/architectures/non-fsd.md` has
  `## 4. Barrels, shared modules, and assets` and `## 3. What goes where`. There is also
  `core/disciplines/routing-discipline.md`. Anything added must be a **gap**, not a restatement.
- **`business-analysis` asks the user a question**: its `### 1. Gather evidence` step says to ask the
  user once at the start for an optional product/strategy description. A parallel subagent cannot
  prompt the user, so the dispatcher must collect this in preflight and pass it down.
- **`seo` hard-aborts today**: `## 0. Preflight — knowledge-seo is required (do this FIRST)` tells
  the agent not to audit anything without `knowledge-seo`, and its `description:` ends with
  "REQUIRES the knowledge-seo plugin". Both change under this plan.
- **`report-model.md` current sections** (all must survive the rewrite): `Hard rule: audits are
  read-only`, `Output: chat-first`, `Scope and evidence sources`, `Finding model`,
  `Finding model > Evidence locators`, `Severity`, `Confidence`,
  `Opportunities / recommendations`, `Coverage and blind spots`.
- **`validate.py` gates etalon/reference-first checks** to `CODE_PLUGINS = {"knowledge-vue"}`, so the
  `references/*.md` illustrations added to `knowledge-principles` are not subject to the etalon
  contract and need no exemption.
- **Existing skill descriptions are bilingual on purpose** — `business-analysis`, `seo` and
  `planning:brainstorm` all carry Ukrainian trigger phrases in `description:`. That is a convention,
  not a defect.

### Conventions that bind this work

- Skill frontmatter is `name:` + `description:` only; the description is the sole trigger.
- **Project-neutral**: no concrete project names, absolute paths, stack versions or build commands in
  plugin files. A plugin carries conventions; the consumer repo carries facts.
- **Compose, never duplicate**: defer by fully-qualified skill name, never restate another skill.
- Version bumps sync `plugins/<n>/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
- Authoring checklists: `.claude/skills/creating-plugins/SKILL.md` and
  `.claude/skills/authoring-knowledge-skills/SKILL.md`. Read both before writing any skill.

### Decisions taken during the brainstorm

**Domains in scope (v1):** `security`, `performance`, `accessibility`, `reliability` (observability
folded in), `code-quality`, `data`, `api-contracts`.
**Rejected:** `testing`, `privacy`, `dependencies`, `dx`, `docs`, `ux`.
**Deferred:** `i18n`; composition-over-inheritance + LSP as a principle.

**Dependency contract — uniform and SOFT for every domain.** No audit skill hard-requires a knowledge
plugin. When the matching plugin is absent, the domain runs on tiers 1 and 2 and records the missing
tier in its coverage section. This replaces `seo`'s current hard abort and applies equally to
`code-quality` ↔ `knowledge-principles` and `code-quality` ↔ `knowledge-vue`.

**Three knowledge tiers:** (1) universal invariants — always; (2) ecosystem general practice — from
the model's own knowledge; (3) codified project conventions — only when a `knowledge-*` plugin
exists. A missing tier is disclosed, never silently skipped.

**Output contract:** per-run directory `docs/audit/YYYY-MM-DD-<scope>/` plus `docs/audit/INDEX.md`.
Reports are immutable.

**The audit never writes to the consumer repo's root `CLAUDE.md`.** An earlier draft mirrored
`planning:brainstorm` and appended a history pointer there; the user removed it. `CLAUDE.md` is
persistent agent-instruction state and stays outside the carve-out. `docs/audit/INDEX.md` is the only
index the audit maintains, and it is discovered by looking at `docs/audit/`, not by a pointer.

**Who writes:** whoever is in charge of the run. A domain skill invoked directly writes its own run
directory. Under the dispatcher, domain subagents return structured findings and **only the
dispatcher writes files** — subagents write nothing.

**Dispatcher:** orchestration only, owns no findings. One stack-detection preflight, snapshot passed
down. Parallel domain subagents, domain-prefixed ids. A failed domain is marked, never aborts others.

**Run comparison** (distinct from panel consolidation — see naming note below): a new run reads the
most recent prior run **of comparable scope** and reports closed / still-open / new. Uncertain
matches are labelled probable, never asserted.

**Panel integration:** optional, dispatcher-only. With `agent-companion` active the run also goes
through `MODE: audit` and a final `MODE: review`.

**Bridge to fixing:** `auditing:remediate` reads a report and produces a plan under `docs/plans/`
following the `planning` plugin's own conventions. The audit never fixes anything.

**Naming note (resolves a collision in the first draft):** "consolidation" always means merging the
audit's findings with the verifier panel's independent pass. "Run comparison" always means comparing
this run to a previous run. The two terms are never interchanged in any file this plan produces.

**Principles — the ten rules:**

| # | Skill | Rule | Consolidates |
|---|---|---|---|
| 1 | `clarity` | Clarity over cleverness | — |
| 2 | `abstraction` | I/O boundaries abstract immediately; domain abstracts on the third real case | YAGNI, OCP timing, DIP timing, DRY timing, speculative generality |
| 3 | `boy-scout` | Clean up touched lines only | Broken Windows (narrowed) |
| 4 | `module-boundaries` | Depend on the contract, not the structure | SoC, cohesion, coupling, encapsulation, SRP, ISP, Law of Demeter |
| 5 | `errors` | Strict at input · fail fast inside · degrade at output | fail fast, no swallowed errors, defensive programming, graceful degradation; rejects Postel's Law at trust boundaries |
| 6 | `state` | Single source of truth · never mutate what you do not own · illegal states unrepresentable | immutability, make-illegal-states-unrepresentable |
| 7 | `naming` | Name the intent; make effects and dependencies explicit | explicit over implicit, least astonishment, CQS |
| 8 | `performance` | Known slow patterns are defects; optimisation requires measurement | premature optimisation |
| 9 | `security` | Security by default | least privilege |
| 10 | `change-safety` | Do not touch what you do not understand; observable behaviour is someone's dependency | Chesterton's Fence, Hyrum's Law |

All ten are **hard** rules — a violation is a defect, not a preference.

**"Consolidates" is deliberately weaker than "absorbs."** Each rule skill must carry a short
`## What this rule does not claim` section naming what the consolidation drops, so the loss is
recorded rather than hidden. Known losses to state explicitly:

- **Broken Windows** is narrowed: rule 3 permits cleanup only on touched lines, so accumulated mess
  outside the diff is not addressed here — it is `auditing:code-quality`'s job.
- **DRY** is reduced to a timing question by rule 2; the "duplicated *knowledge* vs duplicated
  *text*" distinction must be stated in `abstraction/SKILL.md`, or it is lost.
- **CQS** survives only as "a function does exactly what it promises" in rule 7; the stricter
  command/query split is not enforced.
- **SRP / ISP / cohesion / SoC** are folded into rule 4 as one boundary question; the separate
  "one reason to change" phrasing must appear in `module-boundaries/SKILL.md` as an explicit test.
- **DIP** is only covered as *timing* by rule 2; the "depend on abstractions" direction is covered by
  rule 4 as "depend on the contract". Both files must cross-reference so the pair is complete.
- **OCP** is reframed as timing only; the extension-point design question is not covered.
- **Postel's Law** is rejected **at trust boundaries specifically** — not as a blanket claim that
  tolerance is always wrong. `errors/SKILL.md` must scope the rejection this way.
- **KISS** is rejected because rules 2 and 4 decide the same questions with checkable criteria, and
  because a general "prefer simple" rule collides with the wrapper conventions `knowledge-vue`
  mandates. `abstraction/SKILL.md` records this rejection and its reason.

**Precedence — `core/precedence.md`:**

```
1. Codified project convention   knowledge-vue / knowledge-laravel / the project's own CLAUDE.md
2. Framework idiom               how it is normally done in Vue / Laravel
3. Universal principle           knowledge-principles
```

A principle never overrides a convention. Where `knowledge-vue:http-request` mandates a wrapper, the
principles have no vote — an existing wrapper is compliance, not excess. The file must additionally
define: same-tier ordering when two conventions conflict (the more specific file wins; if still tied,
ask the user), how legacy code that predates a convention is treated (it is not a principle
violation; it is `auditing:code-quality` scope), and the **security floor** — rule 9 is never
overridden by any convention or idiom.

**Proportionality gate — `core/proportionality.md`:**

```
LEVEL 1  throwaway script, spike, prototype, one-off migration helper
         active   1 clarity · 7 naming · 9 security · 10 change safety
         silent   2 abstraction · 3 boy-scout · 4 boundaries · 5 errors · 6 state · 8 performance

LEVEL 2  code inside an existing application
         active   all ten

LEVEL 3  new public surface
         active   all ten; 5 and 9 applied strictly
```

Two corrections to the first draft, both from the review: the active/silent lists are stated by rule
number on both sides (previously one side used categories), and **rule 9 is active at every level** —
security is a floor, not a proportionality dial.

Level is decided by **what kind of code**, never by diff size, so a three-line endpoint cannot land
in level 1. The file must define a deterministic classification order, taken first-match:

```
1. Does the change add or alter an endpoint, route, migration, schema, auth/session path,
   money path, or a package's public export?              → LEVEL 3
2. Does the change live inside an existing application's source tree?   → LEVEL 2
3. Otherwise (scratch script, spike, generated helper, throwaway)       → LEVEL 1
```

Ambiguity resolution: a prototype that ships an endpoint is level 3 — rule 1 fires before rule 3.

**Rule 10 escape path** (missing in the first draft): rule 10 must not freeze legitimate behaviour
changes. `change-safety/SKILL.md` states the permitted path — identify who depends on the current
behaviour, state the change explicitly in the summary, and either preserve compatibility or get the
user's explicit approval for the break. Rule 10 forbids *silent* change, not change.

**Rule 3 × rule 10 interaction** (also missing): cleanup is permitted only on touched lines **and**
only where the code is understood. Both files state the interaction so neither is read alone.

**Granularity:** umbrella skill + 10 rule skills; stack specifics in
`skills/<rule>/references/vue.md` and `references/laravel.md` — illustrations of a public framework's
shape, not project conventions.

**Activation:** the `session-start` script injects the precedence line, the ten one-line rules, the
proportionality-level question, and a pointer to `knowledge-principles:principles`. Including the
level question is a correction from the review: without it the hook would inject all ten rules
unconditionally and bypass its own gate.

## Approach

Build the knowledge base, then the audit core, then the `knowledge-vue` architecture gap, then the
domains that consume both, then orchestration, then retrofit, then release chores. Ordering is forced
by two dependencies: `code-quality` consumes `knowledge-principles` (phase 1) and the `knowledge-vue`
architecture skill (phase 3, moved ahead of the domain skills — the first draft had it after).

Rejected alternatives:

- **Splitting into two or three plan documents** — rejected: the user chose one document with phases.
  The `planning:brainstorm` ">12 steps means split" guidance is knowingly overridden here.
- **Building the dispatcher before the domains** — rejected: nothing to orchestrate, contract guessed.
- **A hard panel requirement** — rejected: `auditing` must work without `agent-companion`.
- **Hard dependency for `code-quality`** — rejected: inconsistent with every other domain, and it
  would make the plugin unusable standalone.

## Steps

### Phase 1 — `knowledge-principles` plugin

1. Read `.claude/skills/creating-plugins/SKILL.md` and
   `.claude/skills/authoring-knowledge-skills/SKILL.md`. Scaffold `plugins/knowledge-principles/`
   (using `.claude/skills/creating-plugins/scripts/new-plugin.sh` if it fits, otherwise by hand) with
   `.claude-plugin/plugin.json`: `name`, `version` `0.1.0`, `description`, `author.name` `kolirt`,
   `dependencies: ["knowledge"]`. Register the matching entry in `.claude-plugin/marketplace.json`
   with `source: "./plugins/knowledge-principles"` and the same version. If the scaffolder emits a
   starter command or skill that this plan does not use, delete it — do not leave dead files.
   **Acceptance:** `bash .claude/skills/creating-plugins/scripts/validate.sh` passes.

2. Write `plugins/knowledge-principles/core/precedence.md`: the three-tier ordering, the
   never-overrides statement, same-tier tie-breaking, legacy-code treatment, and the rule-9 security
   floor. Include at least two worked examples where an existing wrapper is compliance, not excess.

3. Write `plugins/knowledge-principles/core/proportionality.md`: the three levels with active/silent
   rule numbers on both sides, the first-match classification order, the ambiguity example
   (prototype that ships an endpoint → level 3), and the statement that rule 9 is active at all levels.

4. Write the umbrella skill `plugins/knowledge-principles/skills/principles/SKILL.md`. Frontmatter
   `name: principles`; `description:` is intent-shaped and fires on any code-writing work. Body: opens
   by reading `../../core/precedence.md` and `../../core/proportionality.md`, then a one-line index of
   the ten rules each naming its skill, then the principle-vs-principle conflict table with
   resolutions (DRY loses to decoupling; framework idiom beats architectural purity; minimal diff
   beats Boy Scout; immutability by default with measured exceptions).

5. Write rule skills 1–5: `clarity`, `abstraction`, `boy-scout`, `module-boundaries`, `errors`.
   Each `SKILL.md` carries: frontmatter (`name:` = directory name, `description:` intent-shaped and
   naming the concrete symptoms it fires on), the rule, what violates it,
   `## What this rule does not claim` (per the consolidation losses recorded in Context), and its
   conflicts with named resolutions. `abstraction` additionally states the DRY knowledge-vs-text
   distinction and the KISS rejection. `module-boundaries` states the "one reason to change" test and
   cross-references `abstraction` for the DIP pair. `errors` scopes the Postel rejection to trust
   boundaries. `boy-scout` states the rule 3 × rule 10 interaction.
   **Acceptance:** five directories, each with a `SKILL.md` carrying all four required sections.

6. Write rule skills 6–10: `state`, `naming`, `performance`, `security`, `change-safety`, to the same
   contract. `change-safety` additionally states the rule 10 escape path and the rule 3 interaction.
   `naming` states that CQS survives only as "does what it promises".

7. Add `references/vue.md` and `references/laravel.md` to rule skills 1–5 — how that one rule
   manifests in that stack, framework shapes only, no project names or absolute paths.

8. Add `references/vue.md` and `references/laravel.md` to rule skills 6–10, same contract.

9. Write the hook, **two files**: `plugins/knowledge-principles/hooks/hooks.json` copied verbatim in
   shape from `plugins/knowledge-vue/hooks/hooks.json` (SessionStart, matcher
   `startup|clear|compact`, command `"\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\""`, `async: false`);
   and `plugins/knowledge-principles/hooks/session-start`, an executable script modelled on
   `plugins/knowledge-vue/hooks/session-start`, emitting an `<EXTREMELY_IMPORTANT>` block containing
   the precedence line, the ten one-line rules, the proportionality-level question, and the pointer to
   `knowledge-principles:principles`. `chmod 755` the script.
   **Acceptance:** the script is executable and, run directly, prints the block.

10. Run `python3 plugins/knowledge/test/validate.py` → `ok: structure valid`, and
    `bash .claude/skills/creating-plugins/scripts/validate.sh`. Scan every new file for Cyrillic
    with `python3` (not `grep -P`, unavailable on macOS); Cyrillic is allowed only inside
    `description:` trigger phrases.

### Phase 2 — `auditing` shared core

11. Rewrite `plugins/auditing/core/report-model.md`. **Preserve unchanged**: `Scope and evidence
    sources`, `Finding model` and its field table, `Evidence locators`, `Severity`, `Confidence`,
    `Opportunities / recommendations`, `Coverage and blind spots`, and the "report in the user's
    language" rule. **Replace** `Output: chat-first` with the file contract:
    - run directory `docs/audit/YYYY-MM-DD-<scope>/`, `<scope>` ∈ `full` | a single domain name |
      `custom`; same-day collisions get `-2`, `-3`;
    - one `<domain>.md` per domain that ran; `summary.md` only when two or more domains ran;
    - reports are immutable once written — a later fix is never recorded by editing an old report;
    - chat still returns a short digest plus the path, never only a path.
    **Amend** `Hard rule: audits are read-only` into an exhaustive carve-out: the audit may write
    exactly `docs/audit/**` — the run directories and `docs/audit/INDEX.md` — and nothing else.
    Source, config, dependencies, tests, branches, commits **and the repo's `CLAUDE.md`** stay
    untouched. Word it as a closed list, not an example list, and name `CLAUDE.md` explicitly as
    forbidden so the rule cannot be read as an oversight.

12. Add to `report-model.md`: the `INDEX.md` upkeep rule (one line per run keyed by the run
    directory; idempotent; created with a `# Audits` skeleton if absent); the three knowledge tiers
    with the rule that a missing tier is named in coverage; and the closing hand-off naming
    `auditing:remediate`.

13. Add to `report-model.md` the **run comparison** section: a run reads the most recent prior run of
    comparable scope and reports closed / still-open / new. Comparability requires that the prior run
    covered the same domain and completed successfully — a domain that was excluded, failed, or ran
    with a different scope is reported as `not comparable`, never as closed. Uncertain matches are
    labelled probable. State explicitly that this is not the same thing as panel consolidation.

14. Write `plugins/auditing/core/stack-detection.md` containing the marker table below verbatim, plus:
    each domain declares the stack facts it needs and what it does without them
    (`skipped: not applicable`, never invented findings); the dispatcher detects once and passes the
    snapshot; monorepos are detected per package and the snapshot carries a list, not a scalar; when
    two runtimes are present both are recorded and each domain decides.

    | Fact | Markers |
    |---|---|
    | Vue (Vite) | `vite.config.*` + `vue` in `package.json` |
    | Nuxt | `nuxt.config.*` |
    | React | `react` in `package.json` |
    | Laravel | `artisan` + `composer.json` with `laravel/framework` |
    | WordPress | `wp-config.php` or `wp-content/` |
    | FSD architecture | numbered layer dirs under `src/` (`01-app`, `02-…`) |
    | Data layer — Laravel | `database/migrations/*.php` + `app/Models/` |
    | Data layer — Prisma | `prisma/schema.prisma` |
    | Data layer — Drizzle | `drizzle.config.*` + a `schema.ts` |
    | Data layer — raw SQL | `*.sql` under a `migrations/` dir |
    | API schema | `openapi.*`, `swagger.*`, or a generated client dir |
    | i18n | `vue-i18n`/`next-intl` in `package.json`, or `lang/`/`locales/` |
    | Test harness | a test runner in `package.json` scripts or `composer.json` |
    | Convention plugins | which `knowledge-*` skills are available this session |

15. Write `plugins/auditing/core/panel-integration.md`: how the dispatcher feeds `agent-companion`
    `MODE: audit`, how the two independent passes are **consolidated** with `disputed` markers and a
    "Decision after synthesis" record, and the final `MODE: review` gate. State that the integration
    is dispatcher-only — individual domain skills never invoke the panel — and that everything works
    unchanged without it.

### Phase 3 — the `knowledge-vue` architecture gap

16. Inventory what `plugins/knowledge-vue/core/architectures/fsd.md` (§4 Dependency rules, §5 Slice
    and segment rules, §7 shared segments, §8 routing buckets), `core/architectures/non-fsd.md`
    (§3 What goes where, §4 Barrels and shared modules) and `core/disciplines/routing-discipline.md`
    already state. Write the inventory into the new file as a "covered elsewhere" list so nothing is
    restated. **Acceptance:** a written list of what already exists and what is genuinely missing.

17. Add the missing architecture rules as a new discipline file
    `plugins/knowledge-vue/core/disciplines/architecture-integrity.md`, covering only the gaps —
    expected to be import cycles between modules, god-modules, dead modules, and cross-layer leakage
    that the placement tables imply but never state as a violation. Expose it through a named skill so
    another plugin can defer to it by fully-qualified name rather than reading a core file across a
    plugin boundary: `plugins/knowledge-vue/skills/architecture/SKILL.md`. Register the new skill's
    row in the `vue-work` umbrella index per the authoring checklist.

### Phase 4 — audit domain skills

Every skill in this phase: opens by reading `../../core/stack-detection.md`, declares its required
stack facts and its not-applicable behaviour, defers to `../../core/report-model.md` for the report,
takes a **soft** dependency on any knowledge plugin, and never reads `../../core/panel-integration.md`
(dispatcher-only). Model the document shape on `business-analysis` — but note it is retrofitted only
in phase 5, so follow the **new** contract described here, not that file's current output section.

18. `plugins/auditing/skills/security/SKILL.md` and `performance/SKILL.md`. Impact dimensions per
    domain (what `blocker` means there) and explicit boundaries against the other domains.

19. `plugins/auditing/skills/accessibility/SKILL.md` and `reliability/SKILL.md`. `reliability`
    explicitly covers observability and states the boundary against `performance` and `security`.

20. `plugins/auditing/skills/data/SKILL.md`. Storage invariants: uniqueness, foreign keys and delete
    behaviour, migration reversibility, money types, timezone-bearing dates, soft-delete consistency,
    enum constraints, indexes backing real filters. Falls back to API-boundary data integrity when no
    schema is detected. States the boundary against `performance` (indexes for speed) and `security`
    (PII at rest).

21. `plugins/auditing/skills/api-contracts/SKILL.md`. Response-shape, error-format, status-code,
    pagination and versioning consistency. Without an API schema it checks client-internal
    consistency only and says so in coverage; with a detected schema it upgrades to full contract
    checking.

22. `plugins/auditing/skills/code-quality/SKILL.md`. Grades structural harm, not style. Tier 3 comes
    from `knowledge-principles:<rule>` and `knowledge-vue:architecture`, both referenced by
    fully-qualified name and both soft: absent → degrade to tiers 1–2 and record it in coverage.
    `remediating skill` values point at the specific rule skill.

### Phase 5 — dispatcher and remediation

23. `plugins/auditing/skills/audit/SKILL.md`, part 1 — preflight and selection. Runs
    `../../core/stack-detection.md` once. Collects the optional product/strategy description that
    `business-analysis` needs, **here**, because parallel subagents cannot prompt the user. Prints the
    annotated domain table: name, one-line purpose, detection verdict (`recommended` /
    `your call` / `not applicable`) and the reason. Then offers selection:
    - `all recommended` — every domain whose verdict is `recommended`;
    - `critical only` — `security`, `reliability`, `data` (fixed set; a domain that is not applicable
      is dropped with a note);
    - `everything available` — every domain not marked `not applicable`;
    - `choose manually` — the user types domain names.

24. `plugins/auditing/skills/audit/SKILL.md`, part 2 — execution and output. Parallel domain
    subagents, each receiving the stack snapshot and the product description; domain-prefixed finding
    ids (`SEC-1`, `PERF-3`); subagents return structured findings and write nothing; the dispatcher
    writes the run directory, every `<domain>.md`, `summary.md` and `docs/audit/INDEX.md` — and
    nothing outside `docs/audit/`; a failed or timed-out domain is recorded as
    `not run: <reason>` and never aborts the
    others; run comparison per `report-model.md`; optional panel integration per
    `panel-integration.md`; closing remediation offer.

25. `plugins/auditing/skills/remediate/SKILL.md`. Reads a run directory or a single report file,
    presents findings for selection (blockers only / blockers and majors / manual pick), and writes a
    plan under `docs/plans/` following the `planning` plugin's own conventions — the dated-slug
    filename and the `docs/plans/INDEX.md` line. It does **not** add the root `CLAUDE.md` plans
    pointer that `planning:brainstorm` writes: nothing in the `auditing` plugin touches `CLAUDE.md`.
    Soft dependency on `planning`: if it is absent, produce the plan document anyway and say which
    conventions could not be confirmed. It never edits a report and never changes code.

### Phase 6 — retrofit, enumeration, release

26. Retrofit `plugins/auditing/skills/business-analysis/SKILL.md`: new file output, stack detection,
    coverage tiers, remediation hand-off, and — because the dispatcher now collects it — the product
    description arrives as an input when orchestrated, and is asked for directly only on a standalone
    run. Keep its bilingual `description:` triggers.

27. Retrofit `plugins/auditing/skills/seo/SKILL.md`: same contract changes, and replace
    `## 0. Preflight — knowledge-seo is required` with a soft degrade that records the missing plugin
    in coverage. Remove "REQUIRES the knowledge-seo plugin" from its `description:`, and update the
    matching sentence in the `auditing` entry of `.claude-plugin/marketplace.json` and in
    `plugins/auditing/.claude-plugin/plugin.json`.

28. Update every place that enumerates skills or claims audits are read-only: the `auditing`
    `plugin.json` and `marketplace.json` descriptions (list the new skills; state that audits write
    reports under `docs/audit/` so "read-only" is no longer misleading), the repo `README.md` if it
    lists skills, and the marketing site data under `site/` if it is hand-maintained rather than
    generated — check `site/` before assuming either way.

29. Version bumps, as a single explicit step so it can be skipped when the user is not publishing:
    `auditing` → `0.2.0`, `knowledge-vue` → `0.4.0`, `knowledge-principles` stays `0.1.0`. Each bump
    edits both `plugins/<n>/.claude-plugin/plugin.json` and the matching `.claude-plugin/marketplace.json`
    entry. No commit and no push — the working tree accumulates until the user asks.

30. Final validation: `python3 plugins/knowledge/test/validate.py` → `ok: structure valid`;
    `bash .claude/skills/creating-plugins/scripts/validate.sh`; the Cyrillic scan across all
    changed files, allowing Cyrillic only in `description:` triggers.

31. Manual verification — **the user performs this; do not report it as done**. Install the plugins
    locally and check, at minimum: a fresh session shows the principles block; `/auditing:audit` on a
    real Vue project produces `docs/audit/<run>/` and `docs/audit/INDEX.md` **and leaves the project's
    `CLAUDE.md` untouched**; a single domain invoked directly (`/auditing:security`) writes its own
    run directory; a domain
    with no applicable stack reports `not applicable` rather than inventing findings; a second run
    produces a run-comparison section; `/auditing:remediate` turns a report into a plan; and the
    dispatcher behaves correctly both with and without `agent-companion` active.

## Out of scope

- `knowledge-laravel`. Until it exists, tier 3 is empty for Laravel and the Laravel references are
  general-practice illustrations. Capturing real Laravel conventions is a separate `knowledge:capture`
  task.
- The deferred `i18n` domain and the deferred composition-over-inheritance / LSP principle.
- The rejected domains: `testing`, `privacy`, `dependencies`, `dx`, `docs`, `ux`.
- Any change to `auditing-prs` — delta-scoped audits stay its territory.
- Committing or pushing. The working tree accumulates until the user explicitly asks.

## Risks and open questions

- **Tier 3 is empty for Laravel.** `code-quality` cannot judge Laravel against the user's actual
  conventions until `knowledge-laravel` exists. Coverage must say so rather than implying completeness.
- **Cumulative SessionStart payload.** `knowledge-vue`, `knowledge-seo` and `terse` already inject
  blocks into every session; `knowledge-principles` adds roughly twenty more lines. If the combined
  weight degrades behaviour, the fallback is the short-router hook variant — at the cost of the rules
  applying only when the skill is actually invoked.
- **One-line rules may not be actionable alone.** The hook carries ten compressed lines. If they turn
  out to be too terse to change behaviour without reading the full skill, the hook must carry a
  "read the skill before non-trivial work" instruction rather than more text.
- **Run comparison is heuristic.** Findings are matched by domain plus location plus substance and
  will sometimes be wrong. The comparability guard (same domain, completed run) prevents the worst
  error — reporting a finding as closed when its domain simply did not run — but not all of them.
- **Parallel dispatch cost and failure modes.** A full run spawns seven or more subagents over the
  whole codebase. Token exhaustion mid-run, a subagent returning malformed findings, and id
  collisions across domains all need handling; the default should be the recommended set, not
  everything.
- **Audit artifacts pollute the consumer's working tree.** `docs/audit/**` appears as uncommitted
  changes in the audited repo and could be committed by accident. The skill should say so in its
  closing digest.
- **No pointer means the index is only discoverable by looking.** Dropping the root `CLAUDE.md`
  pointer (three of five reviewers wanted it gone; the user then removed it) means a future session
  will not be told that `docs/audit/INDEX.md` exists. Mitigation: the dispatcher names the full path
  in its closing digest, and prior runs are found by reading `docs/audit/` during run comparison.
- **Rule 9 at level 1.** Security is now active even for throwaway scripts. This will occasionally
  produce noise on genuinely disposable code; the alternative — silence — was judged worse.
- **Rule 3 × rule 10 can deadlock.** Cleanup requires both a touched line and understanding. Where
  both cannot be satisfied, the correct outcome is to leave the code alone and note it, not to stall.
- **The plan is 31 steps.** It knowingly exceeds the `planning:brainstorm` guidance of 12. Phases are
  independently executable; if `implement` struggles, run one phase per session.
