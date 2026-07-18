---
name: vue-work
description: Use whenever doing any Vue work — creating or editing a Vue component, composable, page, route, store, SSR code, form, modal, or UI element. Indexes the available Vue pattern skills. Self-activating; no manual inclusion.
---

# Vue work (umbrella)

The entry point for Vue work — it establishes the project model first, then points to
the specific pattern skill for the task at hand. Each pattern skill carries its own
rules and expresses file placement in the tokens defined by `core/placement.md`.

## Step 0 — establish the project model (do this FIRST)

- [invariant · desired] Before dispatching to ANY pattern skill, establish
  `{runtime, architecture, projectType}` — or, under `nuxt`, establish `runtime` and
  explicitly settle that `architecture`/`projectType` are not applicable and are
  deferred to the developer (see branch 2). These are **session constants**: determined
  once for the project, then assumed by every skill that follows. A pattern skill never
  re-decides them.

**1. runtime — always first.**
- Decisive signals (any one alone is sufficient) → `runtime = nuxt`: a `nuxt.config.*`
  file; a `nuxt` dependency in `package.json`; `defineNuxtPlugin` or other Nuxt
  auto-imported APIs (e.g. `useNuxtApp`, `definePageMeta`) in source; a `.nuxt/` build
  directory.
- Directory names alone (`pages/`, `layouts/`, `plugins/`) are **not** decisive — a flat
  (`non-fsd`) Vite project legitimately has `src/pages`, `src/layouts`, `src/plugins` by
  convention. Treat them only as a weak, corroborating hint alongside a decisive signal
  above, never as sufficient evidence on their own. Bare `src/pages` + `src/layouts` in a
  Vite project with no decisive Nuxt signal means `non-fsd`, not Nuxt.
- An **existing codebase** with no decisive Nuxt signal → `runtime = vite-vue`.
- **Greenfield** (an empty or near-empty project — nothing to detect either way) → **ASK the
  developer** which runtime they want. Absence of Nuxt signals in an empty project is not
  evidence for `vite-vue`; ask instead of defaulting.

**2. If `runtime = nuxt`** → load `core/runtimes/nuxt.md` and stop the vite-vue branch there.
- [invariant · desired] Under `nuxt`, `architecture` and `projectType` as defined for
  `vite-vue` do **not** apply: Nuxt's own directory conventions replace the FSD/non-fsd
  distinction, and the ssr/csr toggle is Nuxt's own (`nuxt.config`), not a `projectType`
  this plugin resolves. Both are therefore **deferred to the developer** rather than
  detected or assumed — this is the settled expected state for this branch, not a gap to
  fill by guessing. The Vite bootstrap and routing surface is gated **off**:
  `vue-router`, `pages`, `layouts`, `page-middlewares`, the Vite body of
  `plugin-registration`, and `project-init`'s entry-file scaffolding do **not** apply —
  Nuxt owns that surface by convention.
  - ✅ do: ask the developer how their Nuxt project is structured before placing files,
    and treat their answer as the standing convention for the rest of the session; the
    Nuxt doc is a stub, not a settled discipline.
  - ❌ don't: apply the vite-vue bootstrap/routing skills under `nuxt`, and don't invent
    an `architecture`/`projectType` value for Nuxt by guessing — why: layering a
    hand-rolled router or manual registration fights the framework, and a guessed
    architecture mapping risks locking in the wrong convention before the Nuxt doc is
    codified.

**3. If `runtime = vite-vue`** → load `core/runtimes/vite-vue.md`, then resolve the two
remaining constants:
- **architecture** — numbered layer directories → `fsd`; a flat `src/` → `non-fsd`;
  greenfield → **ASK** (the greenfield ask is realized by `project-init`, which asks as
  part of scaffolding). Load `core/architectures/<architecture>.md`.
- **projectType** — a server bootstrap entry or an `--ssr` build script → `ssr`;
  otherwise → `csr`; greenfield → **ASK**. Load `core/project-types/<projectType>.md`.
- [invariant · desired] Never default to FSD and never rebuild a flat `src/` into FSD
  unasked — the folder architecture is a per-project choice, detected or asked, never
  assumed.

**4. THEN dispatch** to the pattern skill from the index below.

- [invariant · desired] `core/placement.md` is the **token vocabulary** only — it defines
  what each placement token means. Resolving a token to a real path is the job of the
  active architecture doc (`core/architectures/<architecture>.md`). Do not expect paths
  from `placement.md`, and do not resolve a token before step 0 has fixed the architecture.

## Always-on SEO rule

- [invariant · desired] Before finishing ANY change that adds visible content, classify
  it against the content→schema recognition table (the single source of truth is the
  `structured-data` skill's `references/recognition.md`) and fill the matching schema +
  meta WITHOUT being asked — SEO baseline is a reflex, not an opt-in. The user cannot
  enumerate every trigger, so the trigger is intentionally broad: "adding or changing
  visible content". Defer schema specifics to the `structured-data` skill and Vue
  delivery specifics to the `seo` skill, both by name.

## Pattern index
Pick the entry that matches the intent; it carries the specifics. Rows marked
`[runtime: vite-vue only]` are **gated off when `runtime = nuxt`** — Nuxt owns that
surface, so follow `core/runtimes/nuxt.md` instead.

| Pattern | When | Where it lives |
|---|---|---|
| architecture / placement | what-goes-where, resolving placement tokens to paths | `core/architectures/<architecture>.md` (vocabulary: `core/placement.md`) |
| SSR/CSR bootstrap | createApp + bootstrap process for the active project type | `core/project-types/<projectType>.md` |
| modals | "add a modal" / dialog work | `../modals/SKILL.md` |
| vue-router | set up / configure the router `[runtime: vite-vue only]` | `../vue-router/SKILL.md` |
| pages | "create a page" / add a route / redirect `[runtime: vite-vue only]` | `../pages/SKILL.md` |
| layouts | create / wire a page layout `[runtime: vite-vue only]` | `../layouts/SKILL.md` |
| page middlewares | write a route guard/middleware `[runtime: vite-vue only]` | `../page-middlewares/SKILL.md` |
| http-request | the shared request wrapper (transport) | `../http-request/SKILL.md` |
| tanstack-query | fetch/mutate data, invalidate cache by key | `../tanstack-query/SKILL.md` |
| auth | login / logout / auto-logout / auth gating | `../auth/SKILL.md` |
| plugin registration | wiring a Vue plugin (Vite body is vite-vue only) | `../plugin-registration/SKILL.md` |
| forms | building a form | `../forms/SKILL.md` |
| form elements | a new input/control (reka-ui) | `../form-elements/SKILL.md` |
| UI components | creating, extracting, splitting, or reusing a UI component; component boundaries, props/emits/slots/variants | `../components/SKILL.md` |
| stores | module-reactive store setup / state management (no Pinia) | `../stores/SKILL.md` |
| persistence | persisting state (localStorage / cookies) | `../persistence/SKILL.md` |
| hydration | SSR hydration, mismatch fixes | `../hydration/SKILL.md` |
| seo | baseline meta/OG/JSON-LD on a Vue page | `../seo/SKILL.md` |
| robots | robots.txt + sitemap generation | `../robots/SKILL.md` |
| project-init | scaffold a new Vue project from scratch | `../project-init/SKILL.md` |

> The index is maintained by the capture/codification action: when a new Vue pattern
> skill is added, its row is appended here. Cross-cutting UI invariants (the shared
> reka-ui wrapper discipline) will return as part of the reka-ui capture.
