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

## 7. Register + finish
- Add the new pattern skill's row to the `vue-work` umbrella **index**.
- **Project-neutral**: NO project names or absolute paths in any plugin file — generic
  names/tokens only (numbered FSD layers like `01-app` are structure, not a project name).
- **Validate**: `python3 plugins/knowledge/test/validate.py` → `ok: structure valid`.
- **Version**: bump `knowledge-vue` `version` only **at push time** (not per change),
  syncing `plugin.json` + `marketplace.json`.
