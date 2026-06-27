# knowledge plugins — design spec (Vue domain, first slice)

## Problem

The developer has documented Vue conventions in the reference project
(`reference monorepo`): an app-level `CLAUDE.md` plus ~15 per-layer `CONVENTIONS.md`.
The AI agent **does not follow them**. Other skills the developer uses work as
intended; the passive-conventions approach does not.

The root cause is **delivery, not content**. `CONVENTIONS.md` sit in the repo
passively — nothing reliably pulls them into context at the moment code is being
written. The agent never reads them at the right time, or reads them once at
start and "forgets," or they are too long / not path-targeted. Skills, by
contrast, are **actively surfaced by the harness** via their `description` when
the work matches — so they fire at the right moment.

Concrete symptoms (all one underlying broken discipline — primitives must be
wrapped, never inlined at the call site):
- uses native form elements instead of reusing the shared wrappers;
- when a new form element is needed, inlines it natively at the usage site
  instead of creating + registering a shared wrapper and reusing it;
- when asked to use a reka-ui component, inlines the reka-ui primitive at the
  call site instead of wrapping it in `shared/ui`.

## Goal & success criterion

A set of Claude Code plugins that encode the developer's conventions as
**intent-triggered skills**, so the agent writes code the way he would — without
being re-told.

**Three plugins, split by concern:**
- **`knowledge`** (base) — the **stack-independent** mechanism: the `capture`
  skill (interactive loop + human-gated codification) and the proactive observer
  design. Lives once; every domain reuses it.
- **`knowledge-vue`** (domain) — the Vue conventions: umbrella + pattern skills +
  Vue core modules. Declares a `dependencies` on `knowledge` so enabling
  `knowledge-vue` auto-installs/enables the base (Claude Code honours
  `plugin.json` `dependencies`, v2.1.110+).
- **`knowledge-laravel`** (domain, later) — same shape, Laravel content.

**Why split (not one plugin with subfolders):** independent enable/version per
stack; a Vue-only project never surfaces Laravel skill descriptions; the base
mechanism is authored **once** and shared via the dependency, not duplicated.

**Plugin-boundary facts that shape the design (verified against Claude Code docs +
changelog):**
- `plugin.json` supports a `dependencies` field; enabling a dependent auto-pulls
  its base (live since v2.1.110, though currently under-documented).
- There is **no supported cross-plugin file access** — a skill cannot `Read` a
  file in another plugin's directory.
- A plugin's skills are surfaced when that plugin is enabled; the dependency keeps
  the base enabled, so the base's `capture` skill is invocable **by name** from a
  domain plugin. The cross-plugin link is **skill-by-name only**, never a file path.

Success: when the developer says "add a modal" / "create a product card" in a Vue
project (with `knowledge-vue` enabled), the agent follows his exact discipline
(packages, registration, wrappers, placement, usage). Built **incrementally**;
completeness of captured knowledge is an explicit **non-goal** — knowledge is
recalled during real work, not enumerable upfront.

## Core model — heterogeneous intent-triggered skills

A domain plugin is a **growing library of skills**, each triggered by developer
intent (surfaced by the harness via the skill's `description`; there is **no
glob/file-watch mechanism**, only description-based self-activation). There is
**no forced internal template**: each skill takes the shape its knowledge needs.
Observed shapes (open set, not exhaustive):

- **Capability skills** (e.g. modals): a full lifecycle —
  *detect project state → bootstrap (install + register the package if missing)
  → scaffold (wrappers) → usage rules*. State-aware: no modals in the project →
  nothing changes; "add a modal" → the agent runs the whole sequence.
- **Composition skills** (e.g. product card): no install — "make a universal
  wrapper, pass data through slots."
- **Placement skills** (FSD): where files go, dependency direction, slice shape
  (`api/model/ui` + barrel). **FSD is one optional concern, not the backbone** —
  the plugin works without it; the other disciplines apply regardless.

Skills **compose / reference** each other: registering a modal package uses the
plugin-registration skill. Cross-cutting invariants and shared placement rules
live in **core modules within the same plugin**, never duplicated into each skill
(the `detection-core` lesson: reference, never inline — otherwise the copies
drift).

**Mandated mechanical form (not just an assertion):** a `SKILL.md` that depends on
a shared rule MUST open by reading the relevant core module **by its concrete
relative path within the same plugin** (a skill at `skills/<pattern>/SKILL.md`
reads ``Read `../../core/<module>.md` ``), exactly as `auditing-prs` adapters open
by reading `../../core/detection-core.md`. A skill may **never** restate a core
rule inline. A skill that uses **another skill** (modal → plugin-registration, or
any domain skill → the base `capture` skill) names that skill and defers to it —
it does **not** reference the other skill's files (cross-plugin file refs are
unsupported; same-plugin skill refs still go by name, not by `Read`).

### Two axes of knowledge

- **Vertical disciplines** — forms, modals, plugin registration, page
  middlewares, reka-ui wrapping, SSR, HTTP/API, etc. Each is self-contained,
  usually backed by a package + a wrapping convention, and **orthogonal to FSD**.
- **Horizontal architecture** — FSD placement (layers, dependency direction,
  slice shape, the custom `composition` layer). Optional.

## On-disk structure

Three sibling plugins under `plugins/`, mirroring the `auditing-prs` layout
(skills + `core`, with `SKILL.md` opening by reading `../../core/<module>.md`):

```
plugins/knowledge/                      # BASE — stack-independent mechanism
  .claude-plugin/plugin.json            # no dependencies
  skills/
    capture/SKILL.md                    # interactive capture loop + codification (stack-neutral)
  core/
    tag-schema.md                       # rule tag grammar
    codification.md                     # the human-gated write action (owner-only)
    observer.md                         # proactive observer — DESIGN ONLY (notify-only)
  test/validate.py                      # structural validator for all knowledge* plugins

plugins/knowledge-vue/                   # DOMAIN — Vue
  .claude-plugin/plugin.json            # dependencies: ["knowledge"]  (array form; bare string tracks latest)
  skills/
    vue-work/SKILL.md                   # Vue umbrella (self-activating)
    modals/SKILL.md                     # pilot capability skill
    forms/ form-elements/ plugin-registration/ page-middlewares/ product-card/  # seed skeletons
  core/
    shared-wrapper-discipline.md        # the cross-cutting invariant
    placement.md                        # dual-mode (FSD + non-FSD) placement

plugins/knowledge-laravel/               # DOMAIN — later increment (same shape)
```

Building-block types:
- **Base mechanism** (`knowledge`) — the `capture` skill + `core/*`. Authored once;
  domain plugins reuse it via the `dependencies` link and skill-by-name calls.
- **Domain skills** (`knowledge-vue/skills/*`) — intent-triggered procedures.
- **Domain core modules** (`knowledge-vue/core/*`) — shared invariants / placement
  rules that the domain's skills reference (same-plugin, drift-proof).

## Trigger model

- A small **umbrella skill `vue-work`** (in `knowledge-vue`) that **self-activates**
  (no manual inclusion): the harness surfaces it whenever its `description` matches
  Vue work (component / composable / SSR / form / etc.). It surfaces the
  cross-cutting invariants **by referencing their core modules** (opens by reading
  ``../../core/shared-wrapper-discipline.md`` — never restating them inline) and
  holds an **index of the available pattern skills**. The index is a simple inline
  list inside `vue-work/SKILL.md` (one row per pattern: name + one-line intent +
  skill path); the codification action appends a row when a new pattern skill is
  added. So once the umbrella loads, the agent knows which sub-patterns exist. The
  umbrella does **not** dictate the internal structure of pattern skills.
- Per-pattern skills carry the specifics and self-activate on their own narrower
  intent (`description`).
- Triggering is **only** description-based self-activation. No glob/file-path
  trigger; "Vue work" is recognized semantically from the description.
- Honest caveat: self-activation relies on the agent recognizing Vue work from the
  `description`. Descriptions must be broad and precise; the umbrella's index is the
  backstop.

This active surfacing is the fix for the original failure: `CONVENTIONS.md` were
dead weight; a skill comes to the agent at the right moment.

## Rule typing inside a skill

Each rule is tagged (grammar defined once in the base `knowledge/core/tag-schema.md`;
domain rules follow it, applied by the base `capture` skill during codification):
- **Type**: `invariant` (never violate) · `preference` (default, overridable) ·
  `anti-pattern` (a thing to avoid).
- **Provenance**: `desired` vs `legacy` — so historical repo habits are not
  cemented as invariants.
- **Code examples**: every `invariant` and every `anti-pattern` SHOULD carry a
  do/don't example where one sharpens the rule; omit only when it adds nothing.
  `preference` carries one when helpful. Small examples inline; large ones as files.

### On-disk tag schema

Tags appear in a fixed, greppable form so a later verifier can parse them:

```markdown
- [invariant · desired] reka-ui primitives are wrapped in `shared/ui`, never
  inlined at the call site.
  - ✅ do: <inline code block or link to an example file>
  - ❌ don't: <inline code block or link> — why: …
```

The bracket tag is `[<type> · <provenance>]` (`type ∈ {invariant, preference,
anti-pattern}`, `provenance ∈ {desired, legacy}`, separator is the middot `·`).

## Capture system (the engine that fills the plugins)

Knowledge is tacit, contextual, and **evolving** — it cannot be fully
pre-authored. It is filled through a human-gated capture system that lives in the
base `knowledge` plugin and works identically for any domain. **Hard guardrails:**
the plugin never edits itself; the observer never writes anywhere; codification is
a separate explicit **owner** action performed in the plugin repo.

### 1. Interactive capture loop (primary, build first)
Run by the owner **in the plugin repo** (or a greenfield test project tied to it):
1. Do the real work on a small **greenfield** project (greenfield = the owner
   dictates the *ideal*, so nothing from a non-ideal repo gets cemented).
2. At each decision point, **ask** how the owner wants it. Do not guess.
3. **Draft** a tagged rule and run it through the **codification action** right
   there — the owner accepts or rejects before anything is written. "Immediately"
   = without leaving the session, NOT without the gate.
4. **Validate**: in a clean context, re-issue the same intent; the captured skill
   should now drive it correctly.
5. **Grow**: a genuinely new pattern becomes a new skill (codification creates it
   and updates the domain umbrella index).

### 2. Proactive observer (follow-on increment; design only, build nothing in increment 1)
**Notify-only.** Read-only, advisory, conservative. It runs while the developer
works in **any** project and **never writes anywhere** — not into the current
project, not into another project, not into the plugin repo. It only **tells the
developer**. The first plan/implementation builds **none** of it.

- **Mode A — novel pattern**: notices a repeated, deliberate pattern not yet
  captured, and says *"I noticed this pattern"* + a written description. The
  developer carries that description into the codification action **later, in the
  plugin repo** — or discards it.
- **Mode B — conflict with an existing skill**: when the developer's request
  contradicts a documented skill, the agent **does not comply silently**. It stops
  and asks which it is — **knowledge progression** (the approach evolved; the
  developer may later update the skill) or **mistaken / one-off** (the agent
  **defends the skill**: "your documented approach is X — skill `<name>` says Y").
  Guard strength is graduated: `invariant` → strong guard; `preference` → lighter.

The observer must be **conservative** — propose only on a repeated, deliberate,
not-yet-captured pattern, never on every micro-decision.

**Non-owner use:** someone who does not own the plugin repo still gets the
read-only benefit (the rules drive the agent) and may receive observer
notifications, but **cannot codify** — there is no repo for them to write to.
Codification is inherently an owner action in the plugin repo.

### 3. Codification action (explicit, owner-invoked, in the plugin repo)
The **only** path that writes plugin content. The owner runs it deliberately
**inside the relevant plugin repo**. Given an approved description it scaffolds the
skill / core entry, shows it, and the owner **accepts or rejects**. It first checks
for overlap with existing skills (**update vs new**) to avoid duplicates / drift.
When a **new** pattern skill is added it also updates the domain umbrella index.
The pattern's domain decides which plugin it lands in (a Vue pattern → `knowledge-vue`,
a Laravel pattern → `knowledge-laravel`); the owner, working in that repo, places it
there. There is **no automatic cross-project or cross-plugin write** — the agent
operates only on the repo the owner is in.

The agent **may open** codification on its own (e.g. inline during the capture
loop), but **no write happens without an explicit owner accept**. The agent never
writes plugin content silently.

## Validation

After codifying a skill, run a concrete acceptance check:
- **Clean context** = a fresh Claude Code session (no prior conversation about the
  pattern) acting on a **fresh greenfield project** that does not yet contain the
  pattern, with only the `knowledge` + `knowledge-vue` plugins available — the rules
  must come from the skill, not chat history.
- **Stimulus** = the single intent sentence ("add a modal").
- **Pass** = the agent, *without further instruction*, produces output matching the
  developer's discipline.

**Modals pilot — concrete end-to-end acceptance.** Given a greenfield project with
no modal solution and the stimulus "add a modal", a passing run must:
1. install the captured modal package (it was absent);
2. register it via the developer's plugin-registration discipline (registration
   file in the app-init location + root wiring) — i.e. it composed the
   plugin-registration skill;
3. create the modal wrapper in the project's shared location that modals inherit
   (not an inlined one-off);
4. show correct usage of that wrapper.

**Fails** if any primitive is inlined at the call site, the package is left
unregistered, or the developer has to restate a rule already captured. This is the
pilot's definition-of-done. The plugin is **instructive** now, but the core modules
are structured so the **same** rule source can later feed a **corrective verifier**
without a second engine.

## Seed inventory (skeletons in `knowledge-vue`, filled via the capture loop)

Patterns the developer has named, scaffolded as skeleton skills/core (not full
rules yet). **The reference paths below are illustrative, not prescribed** — concrete
paths, packages, and shapes are (re)elicited on the greenfield project and tagged
`desired`/`legacy`:
- **modals** — `vue-modal`; registration; wrappers all modals inherit; usage.
- **forms** — single validation mechanism (the developer's package); `ValidationField`
  per field; a wrapper over `ValidationForm` per form.
- **form elements** — reka-ui wrappers in the shared UI location.
- **plugin registration** — a registration file per plugin, invoked + registered at
  the root.
- **page middlewares** — the pages-layer middleware mechanism.
- **product card / slot composition** — universal wrapper + data via slots.
- **placement** — captured into the single stable `knowledge-vue/core/placement.md`.
  **Dual-mode and project-aware**: holds placement rules for **both** FSD projects
  (layers, dependency direction, slice shape, `composition`) **and** non-FSD
  projects, as a matrix of *artifact type* (page / component / store / wrapper) ×
  *architecture*. At runtime the agent determines the current project's architecture
  (the project declares it, or the agent detects the FSD layout; **if undeterminable,
  it asks the developer**) and applies the matching branch. The matrix grows
  incrementally; the pilot fills only the cells the test project needs.
- **shared-wrapper invariant** (core) — primitives are never inlined at the call
  site; always wrapped in the shared location and reused.

## Scope, build order, non-goals

**This sub-project (first spec):**
- the base `knowledge` plugin: manifest, `skills/capture`, `core/{tag-schema,
  codification,observer}.md`, `test/validate.py`;
- the `knowledge-vue` plugin: manifest (with `dependencies` on `knowledge`), Vue
  core, seed skeletons, the umbrella, and the **modals pilot** filled end-to-end
  (chosen because it has a full lifecycle and forces building its dependencies —
  plugin-registration + placement — validating skill composition);
- both registered in `.claude-plugin/marketplace.json`.

**Follow-on increments (designed here, built later):**
- the **proactive observer** (notify-only, both modes);
- the remaining Vue seed patterns;
- the `knowledge-laravel` plugin;
- a corrective verifier sharing the same core.

**Non-goals:**
- completeness of captured knowledge;
- Laravel content (the `knowledge-laravel` plugin is a later slice; only the
  reusable base mechanism is built now);
- auto-extracting `reference` as runtime truth (the repo is non-ideal — an elicitation
  source only);
- the plugin editing itself / the observer writing anything (codification is always
  an explicit owner action in the plugin repo).

## Risks

- **Trigger reliability** — self-activation depends on the agent recognizing Vue
  work from `description`s; mitigated by broad+precise descriptions and the umbrella
  index.
- **Dependency under-documentation** — `plugin.json` `dependencies` is live but not
  yet in the official schema docs; mitigated by it being shipped (v2.1.110+) and by
  the design degrading to "enable both plugins manually" if the field is ignored.
- **Drift** — if core rules are inlined into skills instead of referenced; mitigated
  by reference-never-inline + the codification overlap check.
- **Observer noise / overreach** — mitigated by the conservative bar AND the
  notify-only guarantee (it cannot write, so the worst case is a redundant message).
- **Cementing legacy** — mitigated by the greenfield loop + the `desired`/`legacy`
  provenance tag.
- **False enforcement** — instructive-only guidance may not hold under large edits;
  mitigated by designing the core to feed a later corrective verifier.
