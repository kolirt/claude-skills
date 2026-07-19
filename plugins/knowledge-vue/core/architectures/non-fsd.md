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
| `{project-root}` | `.` (the repository root itself, outside the src tree) |
| `{app}` | `app` |
| `{plugins}` | `plugins` |
| `{initial-plugins}` | `initial-plugins` |
| `{routes}` | `router/routes` |
| `{pages-utils}` | `router/utils` |
| `{pages-types}` | `router/types.ts` |
| `{pages-config}` | `router/config` |
| `{middlewares}` | `router/middlewares` |
| `{global-middlewares}` | `router/global-middlewares` |
| `{pages-ui}` | `pages` |
| `{layouts}` | `layouts` |
| `{shared-config}` | `config` |
| `{shared-ui}` | `components/ui` |
| `{shared-lib}` | `lib` |
| `{shared-utils}` | `utils` |
| `{composition}` | `components/composition` |
| `{feature}` | `components/features` |
| `{widget}` | `components/widgets` |
| `{entity}` | `composables` |
| `{assets}` | `assets` |

Every token above names a **bucket only**, relative to the source root (`src`) — the
slice/domain name is never part of the token value. The author writes it after the token
(`{entity}` + `session` → `composables/session`, filesystem-rendered `src/composables/session`).
See `../placement.md` §1 for the rule and its per-consumer rendering.

**Why `{shared-ui}`, `{widget}`, `{feature}`, and `{composition}` now each have their own
directory:** previously all four resolved to the single `components` bucket, which destroyed
the layering distinction on disk and made the import-direction rule unenforceable — nothing on
the filesystem told you whether a given `components/<x>` was a primitive, a widget, a feature,
or a composition. Giving each role its own directory (`components/ui`, `components/widgets`,
`components/features`, `components/composition`) restores that distinction in non-FSD too.

## 2. Slices exist without layers

A flat `src/` has **no numbered layers** — there is therefore no import-down-only rule and no
`@x` cross-entity notation to enforce; the top-level directories are a set of siblings, not a
numbered stack. But **a slice has the same inner shape as FSD**: `{entity}`, `{widget}`, and
`{feature}` buckets hold slice folders with the same segments (`api/`, `model/store/`,
`model/query/`, `model/action/`, `ui/`, `config/`) as their FSD counterparts (see
`fsd.md` §5). The only difference between the two architectures is **what the root token
resolves to** — the internal slice structure is identical.

- `{entity}` (`composables`) — full slice: `api/`, `model/store/`, `model/action/`,
  `model/query/`, `model/realtime/`, `ui/`, `config/`. Same anatomy as FSD `06-entities`.
- `{widget}` (`components/widgets`) — `ui/` (the composite) + `model/use<Name>.ts`
  (view-state composable). No `api/`. Same anatomy as FSD `03-widgets`.
- `{feature}` (`components/features`) — `ui/` + `model/use<Name>.ts`. No `api/`, no `lib/`.
  Same anatomy as FSD `04-features`.
- `{composition}` (`components/composition`) — the slice **is** the component folder:
  `<Name>.vue` + `interface.ts` (CVA variants) + `index.ts`; no `ui/`, `model/`, or `api/`
  sub-directories. Same anatomy as FSD `05-composition` — composition was never segmented,
  in either architecture.

Name each slice folder after the thing it is (`add-comment`, `comment-list`) so that sibling
slices in the same bucket stay distinguishable.

### Entity nesting

[preference · desired] An entity lives either directly under `{entity}` (`{entity}/session`)
or inside a domain folder (`{entity}/auth/session`). Both are valid; the domain folder is
optional grouping used when it makes the layer easier to navigate. The segments (`api/`,
`model/`, `ui/`, `config/`) always sit INSIDE the entity folder, never inside the domain
folder — `{entity}/auth/model/store/` is the error this rule exists to prevent.

### Internal module layout

Pattern skills name a **role** in prose — "the entity store lives in the `{entity}` module" —
never a path. This table is where that role reference resolves under non-FSD: the concrete
in-slice location for each role, consistent with the segment rules above.

| role | non-FSD location |
|---|---|
| entity store | `{entity}/[<domain>/]<name>/model/store/` |
| entity query | `{entity}/[<domain>/]<name>/model/query/` |
| entity query keys | `{entity}/[<domain>/]<name>/model/query/keys.ts` |
| entity action | `{entity}/[<domain>/]<name>/model/action/` |
| entity api | `{entity}/[<domain>/]<name>/api/` |
| widget view-state | `{widget}/<name>/model/` |
| feature view-state | `{feature}/<name>/model/` |

`[...]` marks an optional path segment; `<...>` is the existing non-token placeholder
notation (see `../placement.md`). `keys.ts` keeps its name in both architectures.

- [invariant · desired] A **component package** — a kebab-case folder holding one
  component's `.vue` + `interface.ts` + `index.ts`, as the `components` skill defines — is
  distinct from a slice's `ui/` segment: a component package groups *one component's* files
  with no further behaviour segments, while a slice's `ui/` segment holds the display
  components for that slice alongside its `model/`, `api/`, and `config/` segments.

## 3. What goes where

1. **Domain entity** → `{entity}` (`src/composables`) — declare the full slice at once
   (`api/`, `model/store/`, `model/action/`, `model/query/`, `ui/`, `config/`), never a thin
   stub holding only types or only a store. [preference · desired]
2. **User action** (mutation, form submit, read-trigger) → `{feature}`
   (`src/components/features`) — one action = one slice: `ui/` + `model/use<Name>.ts`. No
   `api/` of its own; the call lives in the entity module. State is strictly per-mount;
   module-level store variables are forbidden here. [invariant · desired]
3. **Stateless domain composite** (lays out an entity and its relations; no state, no fetch,
   no routing) → `{composition}` (`src/components/composition`). Actions arrive via slots
   (`<template #actions>`), never via imported action components. If state, fetching, or
   routing is needed, it is a stateful composite instead. [invariant · desired]
4. **Stateful composite reused on 2+ pages**, or a large independent block that stands alone
   → `{widget}` (`src/components/widgets`): `ui/` + `model/use<Name>.ts`. It reads data
   through entity query-composables and fires mutations through features — no `api/` of its
   own. Uncombined main content stays in the page. [preference · desired]
5. **Domain-neutral primitive / utility / infrastructure** → `{shared-ui}` (`src/components/ui`),
   `{shared-lib}` (`src/lib`), `src/utils`, `src/types`, or `{shared-config}` (`src/config`)
   — see section 4.
6. **Route-level assembly** → `{pages-ui}` (`src/pages`) — the page component is a
   thin frame that composes the modules below it. A page component does not pull entity data
   directly into its body; the only exception is a middleware reading entity state for
   auth/guard decisions.

## 4. Barrels, shared modules, and assets

- [invariant · desired] Each slice exposes a **barrel `index.ts`** as its public API.
  Consumers import from the barrel only. Every segment inside a slice (`api/`, `model/`,
  `ui/`, and nested sub-segments such as `model/query`, `model/action`, `model/store`) also
  has its own `index.ts` barrel; the slice barrel composes these segment barrels (e.g.
  `export * from './model'`), not deep file paths — same rule as FSD (`fsd.md` §5).
- [invariant · desired] Aggregating barrels MAY use `export *` to compose their sub-barrels;
  leaf modules re-export explicit names. The barrel is the public API either way.
- [invariant · desired] **`{shared-ui}` has no segment-root barrel.** Each component
  **family** (`buttons`, `icons`, `form`, `modals`, …) is its own folder under
  `src/components/ui` with its own `index.ts`, and that family barrel is the public entry
  point — `@/components/ui/buttons`, `@/components/ui/icons`. Importing a component file
  directly (`@/components/ui/buttons/BaseButton.vue`) is still the anti-pattern; there is no
  single `@/components/ui` mega-barrel aggregating every family.
- [invariant · desired] **`{shared-lib}` has no segment-root barrel.** Each module is
  imported through its own **module barrel** — `@/lib/http-request`, never a deep
  implementation file (`@/lib/http-request/client.ts`) and never one mega-barrel
  aggregating every module at `@/lib`.
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
  `{assets}` (`src/assets`), organised as `styles/`, `images/`, `fonts/`. `{initial-plugins}/createApp.ts`
  imports global CSS from `{assets}/styles/...`, not the app entry. No CSS or assets in `{app}`.

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
  `GLOBAL_MIDDLEWARES` array, and the `FALLBACK_ROUTE` constant.
- `{pages-utils}` (`src/router/utils`) — route **builder functions** (`page()`, `group()`,
  `redirect()`, `getDefaultMeta()`). Functions never go in any `config/`.
- `{pages-types}` (`src/router/types.ts`) — routing **types** (`Route`, `Middleware`). Types
  never go in any `config/`.
- `{middlewares}` / `{global-middlewares}` — middleware **implementation files**, one per file
  named `<name>.middleware.ts`; the `GLOBAL_MIDDLEWARES` array that lists them lives in
  `{pages-config}`.
- `{routes}` (`src/router/routes`) — route records, one file per domain, composed in
  `routes/index.ts`.
- `{layouts}` (`src/layouts`) — layout components resolved by the global layout middleware.

