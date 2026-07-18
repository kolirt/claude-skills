# non-FSD architecture (Vue) — flat `src/` placement and module rules

The architecture doc for a project with a **flat `src/`** (`src/components`, `src/pages`, …)
and no numbered layer directories. This file is the **only** place that resolves placement
tokens to concrete paths for non-FSD projects.

The token *vocabulary* (names and roles, no paths) lives in `../placement.md`. Architecture
*detection* — deciding whether a project is FSD or non-FSD — happens in `vue-work` Step 0,
which loads this doc once detection resolves to non-FSD.

## 1. Token → path table

Every placement token, resolved for a flat `src/`. In an **import path** a token resolves
under the project's `@`/`~` src alias (e.g. `@/lib/http-request`).

| token | non-FSD path |
|---|---|
| `{app}` | `src/app` |
| `{plugins}` | `src/plugins` |
| `{initial-plugins}` | `src/initial-plugins` |
| `{routes}` | `src/router/routes` |
| `{pages-utils}` | `src/router/utils` |
| `{pages-types}` | `src/router/types.ts` |
| `{pages-config}` | `src/router/config` |
| `{middlewares}` | `src/router/middlewares` |
| `{global-middlewares}` | `src/router/middlewares/global` |
| `{pages-ui}` | `src/pages/<domain>` |
| `{layouts}` | `src/layouts` |
| `{shared-config}` | `src/config` |
| `{shared-ui}` | `src/components` |
| `{shared-lib}` | `src/lib` |
| `{shared-utils}` | `src/utils` |
| `{composition}` | `src/components` |
| `{feature}` | `src/components/<name>` |
| `{widget}` | `src/components/<name>` |
| `{entity}` | `src/composables/<name>` |
| `{assets}` | `src/assets` |

## 2. No layers, no slices

A flat `src/` has **no numbered layers and no slice level**. There is therefore no
import-down-only rule and no `@x` cross-entity notation to enforce — the structure is a set
of sibling directories, and discipline comes from module boundaries (barrels) rather than
from layer numbering.

The domain-layer tokens collapse to the flat locations:

- `{feature}`, `{widget}`, `{composition}` → all resolve under `src/components` (there is no
  native features / widgets / composition layer). Distinguish them by folder name and by the
  responsibilities in section 3, not by location.
- `{entity}` → `src/composables/<name>`: an entity's api calls, state, and read/mutate
  composables live together in one composable module instead of a six-segment slice.

Because several tokens share a directory, **name the folder after the thing it is**
(`add-comment`, `comment-list`) so that co-located concerns stay distinguishable.

### Internal module layout

Pattern skills name a **role** in prose — "the entity store lives in the `{entity}` module" —
never a path. This table is where that role reference resolves under non-FSD: the concrete
flat location for each role.

| role | non-FSD location |
|---|---|
| entity store | `{entity}/store.ts` |
| entity query | `{entity}/use<Entity>Query.ts` |
| entity query keys | `{entity}/keys.ts` |
| entity action | `{entity}/<action>.ts` |
| entity api | `{entity}/api.ts` (or the entity's api file(s) directly in the module) |
| widget view-state | `{widget}/use<Name>.ts` |
| feature view-state | `{feature}/use<Name>.ts` |

The flat principle: one directory per entity or component, its files side by side, and
`index.ts` reserved for the module's barrel. Never create a `model/`, `api/`, or `ui/`
sub-directory here — that structure belongs to FSD, not to a flat project. If a module grows
noisy enough to tempt you into a *segment-like* sub-directory, that is a signal the module is
doing too much — split the module, do not reintroduce segments.

- [invariant · desired] This does **not** forbid a **component package** — a kebab-case folder
  holding one component's `.vue` + `interface.ts` + `index.ts`, as the `components` skill
  defines. That folder is the component's own module (one directory per component, files side
  by side), not a segment. Segments group *kinds* of file across a module; a component package
  groups *one component's* files. Only the former is forbidden here.

## 3. What goes where

1. **Domain entity** → `{entity}` (`src/composables/<name>`) — the module owns the entity's
   api file(s), its state, and its read/mutate composables. Declare it whole, not as a thin
   stub holding only types. [preference · desired]
2. **User action** (mutation, form submit, read-trigger) → `{feature}`
   (`src/components/<name>`) — one action = one module: a component plus a
   `use<Name>.ts` view-state composable. No api file of its own; the call lives in the
   entity composable. State is strictly per-mount; module-level store variables are
   forbidden here. [invariant · desired]
3. **Stateless domain composite** (lays out an entity and its relations; no state, no fetch,
   no routing) → `{composition}` (`src/components`). Actions arrive via slots
   (`<template #actions>`), never via imported action components. If state, fetching, or
   routing is needed, it is a stateful composite instead. [invariant · desired]
4. **Stateful composite reused on 2+ pages**, or a large independent block that stands alone
   → `{widget}` (`src/components/<name>`): a component plus `use<Name>.ts`. It reads data
   through entity composables and fires mutations through action modules — no api file of its
   own. Uncombined main content stays in the page. [preference · desired]
5. **Domain-neutral primitive / utility / infrastructure** → `{shared-ui}` (`src/components`),
   `{shared-lib}` (`src/lib`), `src/utils`, `src/types`, or `{shared-config}` (`src/config`)
   — see section 4.
6. **Route-level assembly** → `{pages-ui}` (`src/pages/<domain>`) — the page component is a
   thin frame that composes the modules below it. A page component does not pull entity data
   directly into its body; the only exception is a middleware reading entity state for
   auth/guard decisions.

## 4. Barrels, shared modules, and assets

- [invariant · desired] Each module directory (`src/lib/<name>`, `src/composables/<name>`, a
  component folder under `src/components`) exposes a **barrel `index.ts`** as its public API.
  Consumers import from the barrel only.
- [invariant · desired] Aggregating barrels MAY use `export *` to compose their sub-barrels;
  leaf modules re-export explicit names. The barrel is the public API either way.
- [invariant · desired] **No deep-import into a shared segment.** External callers import
  from the segment barrel — `@/components`, not `@/components/SomeComp.vue`; `@/lib`, not
  `@/lib/http-request/client.ts`.
- [invariant · desired] A `src/lib/<name>/` module's `index.ts` is a **pure barrel** —
  explicit named re-exports only (`export { foo } from './foo'`), never `export *`, never
  implementation. The actual code lives in sibling files, one logical unit per file
  (`registry.ts`, `useQuery.ts`, …). The public surface is usually a `use<Name>` composable,
  but may be free functions or a small set of wrappers — whatever the boundary needs.
- [invariant · desired] `src/lib` is for **modules with a boundary**: wrapping an external
  system (fetch, `localStorage`, WebSocket, OAuth, analytics) or an app-wide UI-state
  singleton (a notification queue, a modal stack). `src/utils` is for **single pure
  functions**: no state, no lifecycle, no external-system boundary, no side effects. If any of
  those are present, it belongs in `src/lib`.
- [invariant · desired] **All access to an external system goes through the matching
  `src/lib` module** — `localStorage` only through `lib/local-persistence`, HTTP only through
  `lib/http-request`. Direct calls to `localStorage`, `fetch`, etc. outside their module are
  an anti-pattern.
- [invariant · desired] A function goes into `src/utils` **only when** all three hold: (1)
  broadly reused across 2+ areas, (2) domain-neutral (no knowledge of any entity or action),
  (3) small and pure. If any condition fails, declare it at the call site.
- [invariant · desired] `src/utils` (`{shared-utils}`) has its own `index.ts` **pure barrel**
  — explicit named re-exports only (`export { cn } from './cn'`), never implementation — same
  rule as `src/lib/<name>`. Each helper still lives in its own file (`cn.ts`, `formatDate.ts`,
  …); the barrel is what makes `import { cn } from '{shared-utils}'` resolve.
- [invariant · desired] Global stylesheets and all static assets (images, fonts, SVGs) live in
  `{assets}` (`src/assets`), organised as `styles/`, `images/`, `fonts/`. The app entry
  imports global CSS from `{assets}/styles/...`. No CSS or assets in `{app}`.

## 5. Api files and typing

- [invariant · desired] Each api file declares its own `Payload`/`Response` types inside the
  file. Types shared across 2+ api files in the same module go in a sibling `types.ts` next to
  them.
- [invariant · desired] Transport DTO types (request payloads, response shapes) live next to
  the api calls, NOT next to state/store code. State modules hold domain/store types only.

## 6. Bootstrap and routing buckets

`{app}` resolves to `src/app` and holds the app bootstrap surface and the root component. The
per-request `createApp` factory and imperative bootstrap initialisers live in
`{initial-plugins}` (`src/initial-plugins`); the Vue `app.use` plugin factories in
`{plugins}` (`src/plugins`) — not directly in `{app}`. The concrete bootstrap shape (how many
entry files, what each one does) is defined by the active project type in
`core/project-types/<t>.md`, not here.

Routing buckets are **NOT interchangeable** — do not collapse them into one `config/`:

- `{shared-config}` (`src/config`) — **value constants only**, used across 2+ areas, zero
  behaviour (e.g. the `RouteNames` enum). Never functions, never types.
- `{pages-config}` (`src/router/config`) — router-layer config: the `Layouts` enum, the
  `GlobalMiddlewares` array, and the `fallbackRoute` constant.
- `{pages-utils}` (`src/router/utils`) — route **builder functions** (`page()`, `group()`,
  `redirect()`, `getDefaultMeta()`). Functions never go in any `config/`.
- `{pages-types}` (`src/router/types.ts`) — routing **types** (`Route`, `Middleware`). Types
  never go in any `config/`.
- `{middlewares}` / `{global-middlewares}` — middleware **implementation files**, one per file
  named `<name>.middleware.ts`; the `GlobalMiddlewares` array that lists them lives in
  `{pages-config}`.
- `{routes}` (`src/router/routes`) — route records, one file per domain, composed in
  `routes/index.ts`.
- `{layouts}` (`src/layouts`) — layout components resolved by the global layout middleware.
