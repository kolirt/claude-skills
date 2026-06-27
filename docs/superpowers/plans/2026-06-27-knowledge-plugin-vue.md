# knowledge plugins (Vue domain, increment 1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the base `knowledge` plugin (stack-independent capture mechanism) and the `knowledge-vue` plugin (Vue domain scaffolds + modals pilot), so the developer's Vue conventions can be captured and replayed by the agent.

**Architecture:** Three sibling plugins under `plugins/`. `knowledge` (base) holds the `capture` skill + `core/*` mechanism. `knowledge-vue` (domain) holds Vue skills + `core/*` and declares a `dependencies` on `knowledge` so enabling it auto-pulls the base. `knowledge-laravel` is a later slice. Skills are intent-triggered; same-plugin core modules are referenced by `Read \`../../core/<module>.md\`` (reference-never-inline); the only cross-plugin link is invoking the base `capture` skill **by name** (never a file path — cross-plugin file refs are unsupported). The actual Vue rule *content* is filled at runtime by the interactive capture loop with the developer — increment 1 builds structure + scaffolds, not the captured rules.

**Tech Stack:** Markdown (SKILL.md + core modules), JSON (plugin manifests + marketplace), Python 3 (structural validator). No application runtime.

## Global Constraints

- Plugin names exactly `knowledge` and `knowledge-vue`; version `0.1.0`; author `kolirt` (match existing `plugins/*/.claude-plugin/plugin.json` shape).
- `knowledge-vue/.claude-plugin/plugin.json` MUST declare `"dependencies": ["knowledge"]` — an ARRAY (the Claude Code schema rejects the npm-style object map). Bare-string form tracks latest in the same marketplace and needs no git tags; the object form `{"name":"knowledge","version":">=0.1.0"}` would require `knowledge--v0.1.0` tags, which we do not publish. Base `knowledge` declares no dependencies.
- Skill files are `<plugin>/skills/<name>/SKILL.md` with YAML frontmatter `name:` + `description:` only. Core modules are `<plugin>/core/<module>.md` (plain markdown).
- Reference-never-inline, **within the same plugin only**: a skill opens by reading the core module it depends on via `Read \`../../core/<module>.md\``. Never restate a core rule inline. Never `Read` a file in another plugin (unsupported) — to use the base mechanism, invoke the `capture` skill **by name**.
- Rule tag grammar (verbatim): `[<type> · <provenance>]`, `type ∈ {invariant, preference, anti-pattern}`, `provenance ∈ {desired, legacy}`, separator middot `·`. Do/don't lines use `✅ do:` / `❌ don't:`.
- The plugin never edits itself; the observer never writes anything; codification is an explicit **owner** action run inside the plugin repo.
- **No commits during this plan** (project rule). The working tree accumulates all changes until the developer asks to commit. Every task omits the commit step deliberately.
- TDD adapted to a no-runtime project: each authoring task is verified by `python3 plugins/knowledge/test/validate.py` (validates all `knowledge*` plugins) and targeted `grep`, plus the manual pilot in Task 12.

---

### Task 1: Base `knowledge` plugin manifest + marketplace registration

**Files:**
- Create: `plugins/knowledge/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json` (append the `knowledge` entry)

**Interfaces:**
- Produces: the base plugin root `plugins/knowledge/` and a valid manifest.

- [ ] **Step 1: Create the base manifest**

Create `plugins/knowledge/.claude-plugin/plugin.json`:

```json
{
  "name": "knowledge",
  "version": "0.1.0",
  "description": "Stack-independent base for the developer's coding-knowledge plugins: an intent-triggered capture loop + human-gated codification + a notify-only pattern observer. Domain plugins (knowledge-vue, knowledge-laravel) depend on this and reuse its capture skill.",
  "author": {
    "name": "kolirt"
  }
}
```

- [ ] **Step 2: Register it in the marketplace**

In `.claude-plugin/marketplace.json`, append to the `plugins` array (after `auditing-prs`):

```json
    {
      "name": "knowledge",
      "source": "./plugins/knowledge",
      "description": "Stack-independent base for the developer's coding-knowledge plugins: capture loop + human-gated codification + notify-only pattern observer.",
      "version": "0.1.0"
    }
```

- [ ] **Step 3: Verify both JSON files parse**

Run: `python3 -c "import json; json.load(open('plugins/knowledge/.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('ok')"`
Expected: `ok`

---

### Task 2: Structural validator (all `knowledge*` plugins)

**Files:**
- Create: `plugins/knowledge/test/validate.py`

**Interfaces:**
- Produces: `validate.py` — run as `python3 plugins/knowledge/test/validate.py`; exit 0 + `ok: structure valid`, else exit 1 + `FAIL:` lines. Validates EVERY `plugins/knowledge*` plugin. Each later authoring task uses it.
- Checks per plugin: (a) `.claude-plugin/plugin.json` parses; (b) every `skills/**/SKILL.md` has `name:`+`description:` frontmatter; (c) every `` Read `<rel>.md` `` reference resolves AND stays **within the same plugin** (a cross-plugin ref is a failure); (d) `core/shared-wrapper-discipline.md`, if present, has a tagged rule.

- [ ] **Step 1: Write the validator**

Create `plugins/knowledge/test/validate.py`:

```python
#!/usr/bin/env python3
"""Structural validator for all knowledge* plugins (no app runtime to test)."""
import json, re, sys, pathlib

plugins_dir = pathlib.Path(__file__).resolve().parents[2]  # .../plugins
fail = []
ref = re.compile(r"Read `([^`]+\.md)`")
tag = re.compile(r"\[(invariant|preference|anti-pattern) · (desired|legacy)\]")

for root in sorted(p for p in plugins_dir.glob("knowledge*") if p.is_dir()):
    rootr = root.resolve()
    # (a) manifest parses
    mf = root / ".claude-plugin/plugin.json"
    if not mf.exists():
        fail.append(f"{root.name}: missing .claude-plugin/plugin.json")
        continue
    try:
        json.load(open(mf))
    except Exception as e:
        fail.append(f"{root.name}: plugin.json: {e}")
    # (b) frontmatter on every SKILL.md
    for sk in sorted(root.glob("skills/**/SKILL.md")):
        parts = sk.read_text().split("---")
        fm = parts[1] if len(parts) >= 3 else ""
        if "name:" not in fm or "description:" not in fm:
            fail.append(f"{root.name}: frontmatter missing in {sk.relative_to(root)}")
    # (c) references resolve AND stay within this plugin
    for md in sorted(list(root.glob("skills/**/*.md")) + list(root.glob("core/**/*.md"))):
        for m in ref.finditer(md.read_text()):
            target = (md.parent / m.group(1)).resolve()
            if not target.exists():
                fail.append(f"{root.name}: broken ref `{m.group(1)}` in {md.relative_to(root)}")
            elif rootr not in target.parents:
                fail.append(f"{root.name}: cross-plugin ref `{m.group(1)}` in {md.relative_to(root)} (must stay within the plugin)")
    # (d) tagged rule present in the shared-wrapper invariant once it exists
    swd = root / "core/shared-wrapper-discipline.md"
    if swd.exists() and not tag.search(swd.read_text()):
        fail.append(f"{root.name}: no tagged rule in core/shared-wrapper-discipline.md")

if fail:
    print("\n".join("FAIL: " + x for x in fail))
    sys.exit(1)
print("ok: structure valid")
sys.exit(0)
```

- [ ] **Step 2: Run it on the current tree**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid` (only the base manifest exists so far; check (a) passes).

---

### Task 3: Tag-schema core module (base)

**Files:**
- Create: `plugins/knowledge/core/tag-schema.md`

**Interfaces:**
- Produces: the canonical tag grammar referenced by the capture skill and by every authored rule.

- [ ] **Step 1: Author the tag-schema module**

Create `plugins/knowledge/core/tag-schema.md`:

```markdown
# Tag schema (stack-independent)

Every captured rule is one bullet with a machine-greppable tag, so a later
verifier can parse rules without NLP.

## Grammar

```
- [<type> · <provenance>] <rule sentence>
  - ✅ do: <inline code block, or link to an example file>
  - ❌ don't: <inline code block, or link> — why: <one clause>
```

- `type` ∈ `invariant` (never violate) · `preference` (default, overridable) ·
  `anti-pattern` (a thing to avoid).
- `provenance` ∈ `desired` (the developer wants this) · `legacy` (merely how the
  old repo was — not to be cemented as an invariant).
- The separator between type and provenance is the middot `·` (U+00B7).

## Example

- [invariant · desired] reka-ui primitives are wrapped in the project's shared UI
  location, never inlined at the call site.
  - ✅ do: `import { Checkbox } from '@/shared/ui/form'`
  - ❌ don't: `import { CheckboxRoot } from 'reka-ui'` in a feature component — why: bypasses the shared wrapper, so styling/validation delegation is lost.

## do/don't expectation

Every `invariant` and every `anti-pattern` SHOULD carry a do/don't pair where one
sharpens the rule. Omit only when it adds nothing over the prose. `preference`
rules carry an example when helpful. Small examples inline; large ones as files.

## Grep grammar (for tooling)

A tagged rule line matches: `\[(invariant|preference|anti-pattern) · (desired|legacy)\]`
```

- [ ] **Step 2: Verify the grep grammar matches the example**

Run: `grep -nE '\[(invariant|preference|anti-pattern) · (desired|legacy)\]' plugins/knowledge/core/tag-schema.md`
Expected: at least one match.

- [ ] **Step 3: Run the validator**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid`

---

### Task 4: Codification action core module (base)

**Files:**
- Create: `plugins/knowledge/core/codification.md`

**Interfaces:**
- Consumes: `tag-schema.md` (same dir).
- Produces: the single write-path contract — owner-invoked, in the plugin repo, with accept/reject + overlap check + umbrella-index update.

- [ ] **Step 1: Author the codification module**

Create `plugins/knowledge/core/codification.md`:

```markdown
# Codification action (stack-independent)

The **only** path that writes plugin content. Run **by the owner, deliberately,
inside the relevant plugin repo** (`knowledge` / `knowledge-vue` / …). Stack-neutral:
it writes Vue or Laravel content identically.

Read `tag-schema.md` for the rule format this action emits.

## Inputs
- An approved rule/pattern description (from the capture loop, or an observer
  notification the owner chose to act on).

## Procedure
1. **Locate target.** Decide whether this belongs in an existing skill/core module
   or a new one. Run an **overlap check** against existing skills (by intent and by
   the rule's subject): if it overlaps, the action is **update**, not create —
   duplicates cause drift.
2. **Pick the domain plugin.** A Vue pattern lands in `knowledge-vue`, a Laravel
   pattern in `knowledge-laravel`. The owner is working in that repo; place it there.
   There is **no automatic cross-project or cross-plugin write** — the agent only
   edits the repo the owner is in.
3. **Draft.** Produce the exact file edit: a tagged rule bullet (per tag-schema),
   or a new skill scaffold, with `desired`/`legacy` set from what the owner said.
4. **Show + gate.** Present the precise diff/draft. **No write without an explicit
   owner accept.** Accept or reject.
5. **On accept, write.** Apply the edit.
6. **Index upkeep.** If a **new** pattern skill was created, append its row to that
   domain's umbrella index (e.g. `knowledge-vue/skills/vue-work/SKILL.md`): name +
   one-line intent + skill path.

## Who initiates vs who gates
- The agent **may open** this action on its own (e.g. inline during the capture loop).
- The **write** needs the owner's explicit accept on the shown draft.
- The agent never writes plugin content silently. A non-owner cannot codify — there
  is no plugin repo for them to write to.
```

- [ ] **Step 2: Run the validator**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid` (the same-directory `` Read `tag-schema.md` `` reference resolves).

---

### Task 5: Capture skill (base, stack-neutral)

**Files:**
- Create: `plugins/knowledge/skills/capture/SKILL.md`

**Interfaces:**
- Consumes: `core/tag-schema.md`, `core/codification.md`.
- Produces: the intent-triggered entry point for capturing/teaching a convention. Invoked by name from any domain plugin.

- [ ] **Step 1: Author the capture skill**

Create `plugins/knowledge/skills/capture/SKILL.md`:

```markdown
---
name: capture
description: Use when the developer wants to teach, capture, document, or update a coding convention or pattern (e.g. "remember how I do modals", "capture this approach", "document this pattern", "you did X wrong, here's how I want it"). Runs the human-gated capture loop and codifies the result into the relevant knowledge plugin. Stack-independent — works for any domain (Vue, Laravel, …).
---

# Capture (stack-independent)

Turn the developer's tacit/contextual conventions into tagged rules and skills.
Stack-neutral; the examples below are Vue (increment-1) illustrations only — the
mechanism is identical for any stack and any domain plugin.

Read `../../core/tag-schema.md` first (rule format).
Read `../../core/codification.md` first (the only write path; owner-invoked, in the plugin repo).

## Interactive capture loop
1. Do the real work on a small **greenfield** project (greenfield = the owner
   dictates the *ideal*, so nothing from a non-ideal repo gets cemented).
2. At each decision point, **ask** the owner how they want it (e.g. "how do you
   want the modal wrapper?"). Do not guess.
3. **Draft** a tagged rule (type + `desired`/`legacy` + do/don't) and run it through
   the **codification action** right there — the owner accepts or rejects before
   anything is written. "Immediately" = without leaving the session, NOT without the
   gate.
4. **Validate**: in a clean context, re-issue the same intent; the captured skill
   should now drive it correctly.
5. **Grow**: a genuinely new pattern becomes a new skill (codification creates it in
   the right domain plugin and updates that plugin's umbrella index).

## What this skill must not do
- Never write plugin content without the owner's explicit accept (codification gate).
- Never capture a `legacy` habit as an `invariant`.
- Never inline a core rule's content into a skill — reference the core module.
- Never write outside the plugin repo the owner is in.
```

- [ ] **Step 2: Run the validator**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid` (frontmatter present; both `../../core/*` references resolve within `knowledge`).

---

### Task 6: Observer design doc (base, design-only, notify-only)

**Files:**
- Create: `plugins/knowledge/core/observer.md`

**Interfaces:**
- Produces: the design of the **notify-only** proactive observer for a LATER increment. Increment 1 builds NO observer behavior — documentation only.

- [ ] **Step 1: Author the observer design doc**

Create `plugins/knowledge/core/observer.md`:

```markdown
# Proactive observer — DESIGN ONLY (not built in increment 1)

> Status: design intent for a later increment. Nothing in increment 1 activates
> this. **Notify-only**: read-only, advisory, conservative. It runs while the
> developer works in ANY project and **never writes anywhere** — not the current
> project, not another project, not the plugin repo. It only TELLS the developer.

## Mode A — novel pattern
Notice a repeated, deliberate pattern not yet captured. Say "I noticed this
pattern" + a written description. Write nothing. The developer later carries the
description into the codification action **in the plugin repo**, or discards it.

## Mode B — conflict with an existing skill
When the developer's request contradicts a documented skill, do NOT comply
silently. Stop and ask which it is:
- **knowledge progression** → the approach evolved, the skill is stale → the
  developer may later update the skill (codification, in the repo);
- **mistaken / one-off** → **defend the skill** ("your documented approach is X —
  skill `<name>` says Y") and stay on the skill until the developer confirms.

Guard strength is graduated: `invariant` → strong guard; `preference` → lighter.

## Non-owner use
A non-owner gets the read-only benefit (rules drive the agent) and may receive
these notifications, but cannot codify — there is no repo for them to write to.

## Conservatism
Propose only on a repeated, deliberate, not-yet-captured pattern — never on every
micro-decision (noise risk).
```

- [ ] **Step 2: Run the validator**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid`

---

### Task 7: `knowledge-vue` plugin manifest (with dependency) + marketplace registration

**Files:**
- Create: `plugins/knowledge-vue/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json` (append the `knowledge-vue` entry)

**Interfaces:**
- Produces: the domain plugin root `plugins/knowledge-vue/` with a `dependencies` on `knowledge`, so enabling it auto-pulls the base.

- [ ] **Step 1: Create the domain manifest with the dependency**

Create `plugins/knowledge-vue/.claude-plugin/plugin.json`:

```json
{
  "name": "knowledge-vue",
  "version": "0.1.0",
  "description": "The developer's Vue conventions as intent-triggered skills: an umbrella plus pattern skills (modals, forms, reka-ui wrappers, plugin registration, page middlewares, product card) over shared Vue core rules (shared-wrapper discipline, dual-mode placement). Depends on the knowledge base plugin for the capture mechanism.",
  "author": {
    "name": "kolirt"
  },
  "dependencies": [
    "knowledge"
  ]
}
```

- [ ] **Step 2: Register it in the marketplace**

In `.claude-plugin/marketplace.json`, append to the `plugins` array (after the `knowledge` entry):

```json
    {
      "name": "knowledge-vue",
      "source": "./plugins/knowledge-vue",
      "description": "The developer's Vue conventions as intent-triggered skills over shared Vue core rules. Depends on the knowledge base plugin.",
      "version": "0.1.0"
    }
```

- [ ] **Step 3: Verify the manifest parses and declares the dependency**

Run: `python3 -c "import json; m=json.load(open('plugins/knowledge-vue/.claude-plugin/plugin.json')); print('dep ok' if m.get('dependencies',{}).get('knowledge') else 'NO DEP')"`
Expected: `dep ok`
Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid`

---

### Task 8: Vue core — shared-wrapper invariant + placement module

**Files:**
- Create: `plugins/knowledge-vue/core/shared-wrapper-discipline.md`
- Create: `plugins/knowledge-vue/core/placement.md`

**Interfaces:**
- Produces: `shared-wrapper-discipline.md` (cross-cutting invariant referenced by the umbrella and pattern skills) and `placement.md` (single stable, dual-mode placement reference).

- [ ] **Step 1: Author the shared-wrapper invariant**

Create `plugins/knowledge-vue/core/shared-wrapper-discipline.md`:

```markdown
# Shared-wrapper discipline (Vue) — cross-cutting invariant

The single most-violated rule. Referenced by the Vue umbrella and by pattern
skills that introduce UI primitives.

- [invariant · desired] UI primitives (native form elements, reka-ui components)
  are NEVER inlined at the call site. They are wrapped once in the project's shared
  UI location, registered there, and reused.
  - ✅ do: create/keep a wrapper in the shared UI location and import it:
    `import { Checkbox } from '@/shared/ui/form'`
  - ❌ don't: inline the primitive in a feature/widget component:
    `import { CheckboxRoot } from 'reka-ui'` then markup at the call site — why:
    bypasses the shared wrapper, duplicating styling and losing form-field
    delegation; the next usage diverges and the codebase fragments.

- [invariant · desired] When a needed wrapper does not exist yet, CREATE it in the
  shared UI location (and reuse it), rather than inlining a one-off at the call site.
  - ✅ do: add `Switch.vue` to shared UI, then use `<Switch v-model=… />`.
  - ❌ don't: paste `<SwitchRoot>` markup directly into the page — why: the wrapper
    never gets created, so the discipline silently erodes.
```

- [ ] **Step 2: Author the placement module (single stable, dual-mode)**

Create `plugins/knowledge-vue/core/placement.md`:

```markdown
# Placement (Vue) — where files go

The single stable reference for "where does this file belong". **Dual-mode and
project-aware**: it holds the developer's placement rules for BOTH FSD and non-FSD
projects, as a matrix of *artifact type* (page / component / store / wrapper / …)
× *architecture* (FSD / non-FSD). Placement is **decoupled from FSD** — a skill
references THIS module, never a hard-coded path.

## How a skill uses it
1. Determine the current project's architecture: the project declares it (a marker
   or convention), else detect the FSD layout. If it cannot be determined, ASK the
   developer.
2. Look up the artifact type in the branch for that architecture and place the file
   there. Example: a new page → FSD project: the pages layer per the FSD rules;
   non-FSD project: that project's pages location.

## FSD branch
<!-- CAPTURE SLOT: FSD placement rules (layers, dependency direction, slice shape,
     composition), tagged. Filled via the capture loop. -->

## Non-FSD branch
<!-- CAPTURE SLOT: non-FSD placement rules (e.g. "shared UI lives in src/shared/ui",
     "pages live in src/pages"), tagged. Filled via the capture loop. -->

> The pilot fills only the cells the test project exercises (e.g. the modal wrapper
> location for that project's architecture); the rest of the matrix grows later.
```

- [ ] **Step 3: Verify the invariant is tagged + validator passes**

Run: `grep -nE '\[(invariant|preference|anti-pattern) · (desired|legacy)\]' plugins/knowledge-vue/core/shared-wrapper-discipline.md | head`
Expected: at least two tagged lines.
Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid`

---

### Task 9: Seed skeleton skills (named Vue patterns, not yet filled)

**Files:**
- Create: `plugins/knowledge-vue/skills/forms/SKILL.md`
- Create: `plugins/knowledge-vue/skills/form-elements/SKILL.md`
- Create: `plugins/knowledge-vue/skills/plugin-registration/SKILL.md`
- Create: `plugins/knowledge-vue/skills/page-middlewares/SKILL.md`
- Create: `plugins/knowledge-vue/skills/product-card/SKILL.md`

**Interfaces:**
- Produces: titled placeholder skills for the named patterns. Valid frontmatter + intent + a "filled via capture loop" marker. No rules yet.

- [ ] **Step 1: Author each seed from this template**

Use this exact template, substituting `<NAME>`, `<DESCRIPTION>`, `<INTENT>` from the table below:

```markdown
---
name: <NAME>
description: <DESCRIPTION>
---

# <NAME> (Vue) — skeleton

> Skeleton: the rules for this pattern are filled by the `capture` skill's loop
> (human-gated codification). Until then, this skill states the intent and, when
> invoked, MUST ask the developer for the convention rather than guessing. To
> capture, invoke the `capture` skill by name (provided by the `knowledge` base plugin).

Read `../../core/shared-wrapper-discipline.md` first (applies to any UI primitive this pattern introduces).

## Intent
<INTENT>

## Status
Not yet captured. When invoked, run the `capture` loop for this pattern.
```

Rows to instantiate (exact strings):

| `<NAME>` | `<DESCRIPTION>` | `<INTENT>` |
|---|---|---|
| `forms` | `Use when building or editing a Vue form. Captures the developer's form discipline (single validation mechanism, ValidationForm/ValidationField wrappers). Skeleton — rules filled via the capture loop.` | `Every form uses the developer's single validation mechanism: each field wrapped by the project's ValidationField wrapper; each form wrapped by the project's wrapper over ValidationForm.` |
| `form-elements` | `Use when adding or changing a Vue form input/control (checkbox, select, switch, etc.). Captures the reka-ui-wrapper discipline. Skeleton — rules filled via the capture loop.` | `Form elements are wrappers around reka-ui primitives, created and registered in the shared UI location and reused — never inlined at the call site.` |
| `plugin-registration` | `Use when wiring a Vue plugin into the app (installing + registering a package the developer's way). Skeleton — rules filled via the capture loop.` | `Each plugin gets a registration file in the app-init location; registration files are invoked + registered at the root. Other skills (e.g. modals) defer to this skill for package registration.` |
| `page-middlewares` | `Use when adding route/page middleware or guards in a Vue app. Skeleton — rules filled via the capture loop.` | `Page middlewares follow the developer's middleware mechanism for the pages layer (per-route + global).` |
| `product-card` | `Use when building a card-style component (e.g. a product card) via a universal wrapper and slots. Skeleton — rules filled via the capture loop.` | `Build a universal card wrapper and pass data through slots — no install; a composition pattern, not a capability.` |

- [ ] **Step 2: Verify all five exist with valid frontmatter**

Run: `for p in forms form-elements plugin-registration page-middlewares product-card; do test -f plugins/knowledge-vue/skills/$p/SKILL.md && echo "ok $p" || echo "MISSING $p"; done`
Expected: `ok` for all five.

- [ ] **Step 3: Run the validator**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid`

---

### Task 10: Modals skill scaffold (pilot capability skill)

**Files:**
- Create: `plugins/knowledge-vue/skills/modals/SKILL.md`

**Interfaces:**
- Consumes: `core/shared-wrapper-discipline.md`, `core/placement.md`; defers to the `plugin-registration` skill (same plugin) and the `capture` skill (base, by name).
- Produces: the capability-skill structure for modals (detect → bootstrap → scaffold → usage) with explicit capture slots. Filled in Task 12.

- [ ] **Step 1: Author the modals scaffold**

Create `plugins/knowledge-vue/skills/modals/SKILL.md`:

```markdown
---
name: modals
description: Use when the developer asks to add a modal/dialog in a Vue project. A capability skill — detects whether the modal package is present, installs + registers it the developer's way if not, scaffolds the shared modal wrapper, and shows correct usage.
---

# Modals (Vue) — capability skill

Read `../../core/shared-wrapper-discipline.md` first (modals introduce UI that must
live in the shared wrapper, not inline).
Read `../../core/placement.md` first (where the modal wrapper file goes).
For package registration, DEFER to the `plugin-registration` skill (by name) — do
not restate registration steps here. To capture/refine any rule below, invoke the
`capture` skill by name (from the `knowledge` base plugin).

## Lifecycle
1. **Detect state.** Is the developer's modal package already installed in this
   project? If yes, skip install. No modal solution → continue.
2. **Bootstrap.** Install the modal package, then register it by deferring to the
   `plugin-registration` skill.
   <!-- CAPTURE SLOT: exact package name (e.g. vue-modal) + install/registration
        specifics — filled by the capture loop, tagged in this file. -->
3. **Scaffold.** Create the shared modal wrapper that all modals inherit, in the
   location `placement.md` dictates — never a one-off inlined dialog.
   <!-- CAPTURE SLOT: wrapper shape (base component, inheritance/contract, props/slots)
        — filled by the capture loop, tagged. -->
4. **Usage.** Show how to define and open a modal using the wrapper.
   <!-- CAPTURE SLOT: usage convention — filled by the capture loop, tagged. -->

## Status
Scaffold. Capture slots are filled via the `capture` loop (Task 12 / pilot). When
invoked before capture, ask the developer for each slot rather than guessing.
```

- [ ] **Step 2: Run the validator (all references resolve)**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid` (the two `../../core/*` references resolve within `knowledge-vue`).

- [ ] **Step 3: Verify all six Vue pattern skills now exist**

Run: `for p in modals forms form-elements plugin-registration page-middlewares product-card; do test -f plugins/knowledge-vue/skills/$p/SKILL.md && echo "ok $p" || echo "MISSING $p"; done`
Expected: `ok` for all six (so the umbrella index built in Task 11 will have real targets).

---

### Task 11: Vue umbrella skill (`vue-work`)

**Files:**
- Create: `plugins/knowledge-vue/skills/vue-work/SKILL.md`

**Interfaces:**
- Consumes: `core/shared-wrapper-discipline.md`; indexes the six pattern skills from Tasks 9–10 (all exist now).
- Produces: the self-activating Vue entry skill carrying the invariant (by reference) and the pattern-skill index.

- [ ] **Step 1: Author the umbrella skill**

Create `plugins/knowledge-vue/skills/vue-work/SKILL.md`:

```markdown
---
name: vue-work
description: Use whenever doing any Vue work — creating or editing a Vue component, composable, page, store, SSR code, form, modal, or UI element. Surfaces the developer's cross-cutting Vue invariants and indexes the available Vue pattern skills. Self-activating; no manual inclusion.
---

# Vue work (umbrella)

The entry point for Vue work. It surfaces the cross-cutting invariants (by
reference) and points to the specific pattern skill for the task at hand.

Read `../../core/shared-wrapper-discipline.md` first — it applies to ALL Vue UI work
and is the most-violated rule.

## Pattern index
Pick the skill that matches the intent; it carries the specifics.

| Pattern | When | Skill |
|---|---|---|
| modals | "add a modal" / dialog work | `../modals/SKILL.md` |
| forms | building a form | `../forms/SKILL.md` |
| form elements | a new input/control | `../form-elements/SKILL.md` |
| plugin registration | wiring a Vue plugin | `../plugin-registration/SKILL.md` |
| page middlewares | route guards/middleware | `../page-middlewares/SKILL.md` |
| product card / slots | a card via universal wrapper + slots | `../product-card/SKILL.md` |

> The index is maintained by the capture/codification action: when a new Vue pattern
> skill is added, its row is appended here.
```

- [ ] **Step 2: Run the validator + confirm every index target exists**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid` (the `shared-wrapper-discipline.md` reference resolves within `knowledge-vue`).
Run: `for p in modals forms form-elements plugin-registration page-middlewares product-card; do test -f plugins/knowledge-vue/skills/$p/SKILL.md && echo "ok $p" || echo "MISSING $p"; done`
Expected: `ok` for all six (every umbrella index link resolves to a real skill).

---

### Task 12: Pilot — capture modals end-to-end + validate DoD (INTERACTIVE, developer-owned)

> **This task requires the developer.** It runs the live capture loop and a manual
> acceptance run. Do NOT mark it complete from automated checks — report its outcome
> as observed with the developer. This is the increment's definition-of-done.

**Files:**
- Modify (via the codification action, with owner accept): `plugins/knowledge-vue/skills/modals/SKILL.md`, `plugins/knowledge-vue/skills/plugin-registration/SKILL.md`, `plugins/knowledge-vue/core/placement.md` — fill their capture slots with tagged rules.

**Interfaces:**
- Consumes: all prior tasks (base mechanism + Vue scaffolds).
- Produces: a filled modals pattern that passes the acceptance run.

- [ ] **Step 1: Set up a greenfield test project**

With the developer, create a throwaway greenfield Vue project (or worktree) with no
modal solution. Record whether it is FSD or non-FSD (this selects which `placement.md`
branch the capture loop fills for the modal wrapper location).

- [ ] **Step 2: Run the capture loop for modals**

Invoke the `capture` skill (base plugin). Working the intent "add a modal", ask the
developer at each decision point (package name; registration specifics; wrapper shape
+ inheritance contract; placement; usage). For each answer, draft a tagged rule and
run the codification gate — developer accepts/rejects. Fill the capture slots in
`modals/SKILL.md`, the registration specifics in `plugin-registration/SKILL.md`, and
the relevant branch of `placement.md`.

- [ ] **Step 3: Run the validator after capture**

Run: `python3 plugins/knowledge/test/validate.py`
Expected: `ok: structure valid`
Run: `grep -RnE '\[(invariant|preference|anti-pattern) · (desired|legacy)\]' plugins/knowledge-vue/skills/modals/SKILL.md plugins/knowledge-vue/skills/plugin-registration/SKILL.md plugins/knowledge-vue/core/placement.md`
Expected: at least one tagged rule in each of the three files (all capture slots filled).

- [ ] **Step 4: Acceptance run (clean context) — the pilot DoD**

In a FRESH Claude Code session (no prior conversation about modals), with only the
`knowledge` + `knowledge-vue` plugins enabled, acting on the greenfield project, issue
exactly: "add a modal". With the developer, confirm the agent — without further
instruction —:
1. installs the captured modal package (it was absent);
2. registers it via the developer's plugin-registration discipline (registration file
   in the app-init location + root wiring) — i.e. composed the plugin-registration skill;
3. creates the modal wrapper in the project's shared location that modals inherit (not
   an inlined one-off);
4. shows correct usage of that wrapper.

**Fails** if any primitive is inlined at the call site, the package is left
unregistered, or the developer has to restate a rule already captured.

- [ ] **Step 5: Report outcome**

Report to the developer: pass/fail against the four DoD points, with what the agent
produced. If it failed, the gap is a missing/weak captured rule — re-run the capture
loop for that slot and repeat Step 4. (Do not claim the pilot "done" until the
developer confirms the acceptance run passed.)
