---
name: authoring-knowledge-skills
description: Use when authoring, capturing, or editing a skill in plugins/knowledge-vue/ (or any knowledge-* domain plugin) — the checklist for a well-formed knowledge skill so nothing is forgotten (especially the full setup/install lifecycle, placement tokens, disciplines, tags, deferral, validation, versioning, and project-neutrality).
---

# Authoring knowledge-* skills

The checklist for capturing a developer convention into a `plugins/knowledge-vue/`
skill. Follow it every time so captures are consistent and complete. Source the
content via the `knowledge:capture` flow (public docs + the reference as an
elicitation SOURCE only — decontaminate `desired` vs `legacy`; the developer confirms).

## 1. File + frontmatter
- New skill at `plugins/knowledge-vue/skills/<name>/SKILL.md`; core module at
  `plugins/knowledge-vue/core/<name>.md` (cross-cutting invariants under
  `core/disciplines/`).
- Frontmatter is `name:` + `description:` only. The `description` is the **trigger** —
  make it broad and intent-shaped ("Use when …").

## 2. Cover the FULL lifecycle — do not stop at "usage"
The most common miss. For a capability backed by a package/tool, capture **all** of:
1. **Install** — `yarn add <pkg>`.
2. **Setup / registration** — how it is wired (factory file via `plugin-registration`,
   `app.use(...)`, config, type augmentation, default options). ← easy to forget.
3. **Scaffold defaults** — anything created up front (e.g. ConfirmModal, DefaultLayout
   + ErrorLayout, the QueryClient).
4. **Usage** — how a consumer uses it.
5. **Teardown / cleanup** — for data: invalidation/eviction by key; for auth: logout.

## 3. Tag every rule
- `[<type> · <provenance>]` — `type ∈ {invariant, preference, anti-pattern}`,
  `provenance ∈ {desired, legacy}` (middot `·`). Add a `✅ do:` / `❌ don't:` pair to
  every invariant/anti-pattern where it sharpens the rule.
- Flag backend/stack-coupled bits (e.g. Laravel-specific: `_method`, `419`, csrf endpoint)
  and project-specific examples — capture as `desired` only when the developer confirms.

## 4. Placement via TOKENS, never hard-coded paths
- Use the `placement.md` tokens (`{plugins}`, `{shared-ui}`, `{shared-lib}`, `{entity}`,
  `{routes}`, `{layouts}`, `{feature}`, …). Open the skill with
  `Read \`../../core/placement.md\``.
- If a needed location is missing, **add a token row** to `placement.md` (FSD + non-FSD).

## 5. Disciplines (cross-cutting invariants)
- Put a `Read \`../../core/disciplines/<x>.md\`` line where the discipline applies:
  in the **scoped skills** for a scoped discipline (e.g. routing-discipline → the routing
  skills); in the **`vue-work` umbrella** for a universal one (applies to all Vue work).

## 6. Compose — never duplicate
- Defer to another skill **by name** ("defer to the `plugin-registration` skill"); never
  `Read` a file in another plugin (unsupported), and never restate another skill's steps.
- Same-plugin core/ modules are referenced via `Read \`../../core/<module>.md\`` —
  reference, never inline.
- **No conflicts**: every new skill COMPLEMENTS the knowledge base — it must not
  contradict, override, or overlap the rules another skill owns. Before writing, check
  the sibling skills that touch the same territory; where topics border each other,
  the specialized skill keeps precedence and the new skill defers to it by name
  (e.g. a general component skill defers form controls to `form-elements`, dialogs
  to `modals`, placement to `core/placement.md` + the active `core/architectures/<a>.md`).

## 7. Reference-first: full-file etalons, never "directions"
A skill that makes the agent **write code** MUST ship a full-file etalon in
`references/` — a partial snippet is a *direction*, and the agent re-interprets a
direction slightly differently every run. The SKILL.md body keeps the rules and says
"read `references/<artifact>.md` and reproduce it"; the etalon carries the code.

Etalon contract (checked by `validate.py`):
- One file per artifact: `references/<artifact>.md`, English.
- A `## Files` inventory at the top — one line per generated file, `` - `{token}/path/to/file.ext` ``.
- Then, for each file: a `**File:** \`{token}/path/to/file.ext\`` line **outside** any code
  block, immediately followed by exactly ONE fenced block with a language
  (```ts / ```vue / ```json / …) holding the file's **complete** content.
- The inventory and the `**File:**` markers must be the same set — no file listed but
  unwritten, none written but unlisted.
- Paths use placement tokens (§4). Project-root files (`package.json`, `vite.config.ts`,
  `.env.*`, robots files) use `{project-root}`.
- Every etalon passes a **human gate**: draft → the developer approves or corrects →
  only then integrate. Same discipline as `knowledge:capture`; never merge an
  unapproved etalon.

**Where an etalon ends.** An etalon reproduces ONE artifact, not the whole application, so it is
self-contained only within its own module:
- A **relative** import (`./x`, `../x`) points inside the etalon's own module — the etalon MUST ship
  that file. A relative import with no `**File:**` entry behind it is a defect: the reader cannot
  reproduce a working module.
- A **token** import (`{shared-lib}/toast`, `{widget}/header`) points at another bucket the project
  owns — an external reference. The etalon does NOT ship it, and must not: duplicating it would
  create a second, drifting copy of a file another etalon (or the consumer project) owns.
Two etalons that both need the same file: exactly one ships it, the other imports it by token and
says so in prose.

**The one exception — VARIANTS.** Two etalons may ship the same path when they are mutually
exclusive alternatives chosen by a project-model constant (`projectType`, `architecture`,
`runtime` — fixed by `vue-work` step 0), so a reader reproduces exactly one of them, never both.
A CSR scaffold and an SSR scaffold both shipping `{project-root}/package.json` is correct; two
etalons of the same project type both shipping it is not. A variant etalon MUST declare itself in
its header, on its own line:

    Variant: projectType=csr

Anything else that ships a path another etalon already ships is a defect, and the worse form is
**divergence**: two copies with different content, where the reader silently gets whichever they
happened to read last.

Deliberately empty skeleton skills (awaiting a capture session) are exempt until filled.

## 8. Plugin vs consumer repo — the boundary
A plugin carries **conventions**, the consumer repo carries **facts**. Stack versions,
build/test commands, real directory paths, env names, deploy specifics belong to the
consumer project's `CLAUDE.md` — never to a plugin file. If a rule cannot be stated
without naming a concrete project's path or command, it is a project fact, not a
convention: leave it out of the plugin.

**Carve-out — SCAFFOLD etalons may pin a baseline version set.** A `project-init`-style
etalon that reproduces a generated `package.json` (or other scaffold manifest) necessarily
writes concrete dependency versions and build scripts — that is the thing being
scaffolded, not a claim about any consumer project's stack. Pinning a baseline version set
in a SCAFFOLD etalon is a point-in-time snapshot the developer approved at the human gate
(§7), not a violation of this section. This carve-out is narrow: it covers the etalon's
**file content** only. The **prose** of a skill (the rules body, outside `references/`)
must still never assert project-specific stack facts — it states the convention, not a
version number, and defers the concrete pin to the etalon.

## 9. Register + finish
- Add the new pattern skill's row to the `vue-work` umbrella **index**.
- **Project-neutral**: NO project names or absolute paths in any plugin file — generic
  names/tokens only (numbered FSD layers like `01-app` are structure, not a project name).
- **Validate**: `python3 plugins/knowledge/test/validate.py` → `ok: structure valid`.
- **Version**: bump `knowledge-vue` `version` only **at push time** (not per change),
  syncing `plugin.json` + `marketplace.json`.
