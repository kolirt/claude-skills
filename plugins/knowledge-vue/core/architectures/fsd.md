# FSD architecture (Vue) — layers, placement, dependency rules

The architecture doc for a project whose source root has **numbered layer directories**
(`01-app`, `02-pages`, …, `07-shared`). This file is the **only** place that resolves
placement tokens to concrete paths for FSD projects.

The token *vocabulary* (names and roles, no paths) lives in `../placement.md`. Architecture
*detection* — deciding whether a project is FSD or non-FSD — happens in `vue-work` Step 0,
which loads this doc once detection resolves to FSD.

## 1. Layer table

| # | Layer | Responsibility |
|---|---|---|
| 01 | app | Composition root: `createApp`, per-request factory, plugin registration, pre-mount async init. |
| 02 | pages | Route-level assembly: route records, page components (thin frames), layouts, middlewares. |
| 03 | widgets | Stateful composites reused on 2+ pages, or large independent blocks not yet combined with others. |
| 04 | features | One user action = one slice: mutation forms, read-fetchers, imperative triggers. |
| 05 | composition | Stateless domain composites: lays out an entity and its relations; no state, no fetch, no routing. |
| 06 | entities | Business entities: full slice (`api/` + `model/` + `ui/`) declared at once. |
| 07 | shared | Domain-neutral primitives, utilities, infrastructure, and app-wide singletons. |

## 2. Token → path table

Every placement token, resolved for FSD. In an **import path** a token resolves under the
project's `@`/`~` src alias (e.g. `@/07-shared/ui`).

| token | FSD path |
|---|---|
| `{app}` | `01-app` |
| `{plugins}` | `01-app/plugins` |
| `{initial-plugins}` | `01-app/initial-plugins` |
| `{routes}` | `02-pages/routes` |
| `{pages-utils}` | `02-pages/utils` |
| `{pages-types}` | `02-pages/types.ts` |
| `{pages-config}` | `02-pages/config` |
| `{middlewares}` | `02-pages/middlewares` |
| `{global-middlewares}` | `02-pages/global-middlewares` |
| `{pages-ui}` | `02-pages/ui/<domain>` |
| `{layouts}` | `02-pages/layouts` |
| `{shared-config}` | `07-shared/config` |
| `{shared-ui}` | `07-shared/ui` |
| `{shared-lib}` | `07-shared/lib` |
| `{shared-utils}` | `07-shared/utils` |
| `{composition}` | `05-composition` |
| `{feature}` | `04-features/<name>` |
| `{widget}` | `03-widgets/<name>` |
| `{entity}` | `06-entities/<name>` |
| `{assets}` | `07-shared/assets` |

`{app}` resolves to `01-app` and holds the app bootstrap surface and the root component. The
per-request `createApp` factory and imperative bootstrap initialisers live in
`{initial-plugins}`, and the Vue `app.use` plugin factories in `{plugins}` — not directly in
`{app}`. The concrete bootstrap shape (how many entry files, what each one does) is defined by
the active project type in `core/project-types/<t>.md`, not here.

## 3. "Where does it go" — decision order (take first match)

1. **Domain entity** → `{entity}` (`06-entities/<name>`) — entity-first: declare the full slice at once, never a thin stub. [preference · desired]
2. **User action** (mutation, form submit, read-trigger) → `{feature}` (`04-features/<name>`) — one action = one slice.
3. **Assemble a ready entity UI** (no own state, no fetch, no routing; reused across contexts) → `{composition}` (`05-composition/<name>`) — actions arrive via slots, not props.
4. **Stateful composite reused on 2+ pages**, or a large independent block that stands alone → `{widget}` (`03-widgets/<name>`). Uncombined main content stays in the page; not every block is a widget. [preference · desired]
5. **Domain-neutral primitive / utility / infrastructure** → `07-shared/<segment>` — see section 6.
6. **Route-level assembly** → `{pages-ui}` (`02-pages/ui/<domain>`) — the page component is a thin frame that composes layers below.

## 4. Dependency rules

- [invariant · desired] Import **DOWN only**: a layer may only import from layers with a **higher** number (lower layers = more context; higher numbers = more generic). Example: `04-features` may import `06-entities` and `07-shared`, never `03-widgets` or `02-pages`.
- [invariant · desired] **Same-layer slices do not import each other.** Lift shared code down (to a lower layer) or up (to a higher layer) instead.
- [invariant · desired] **Exception — entities↔entities type-only**: cross-entity type references use `@x` notation (`06-entities/<A>/@x/<B>.ts` re-exports types from entity B for consumption inside entity A, `import type` only). No runtime cross-entity imports.
- [invariant · desired] **`app` and `shared` are layer+segment** (no slice level): code inside them may import each other freely within the same layer.

## 5. Slice and segment rules

Slice shape inside a domain folder: `api/` + `model/` + `ui/` + a barrel `index.ts`.

| Segment | Purpose |
|---|---|
| `ui/` | Display components |
| `api/` | Backend calls. Each file declares its own `Payload`/`Response` types inline; types shared across 2+ api files in the same slice go in `api/types.ts`. Transport DTO types (request payloads, response shapes) live here, NOT in `model/`. |
| `model/` | Data, state, logic (in entities: split into `store/`, `action/`, `query/`, `realtime/`) |
| `lib/` | Slice-local utilities (not exported) |
| `config/` | Slice-local constants / enums |

Name segments by **purpose**, not by essence. `hooks/`, `types/`, `components/` are bad
segment names.

- [invariant · desired] Each slice exposes a **barrel `index.ts`** as its public API. Consumers import from the barrel only.
- [invariant · desired] Every segment inside a slice (`api/`, `model/`, `ui/`, and nested sub-segments such as `model/query`, `model/action`, `model/store`, `model/realtime`, `ui/<component>`) also has its own `index.ts` barrel; the slice barrel composes these segment barrels (e.g. `export * from './model'`), not deep file paths.
- [invariant · desired] Slice and segment barrels MAY use `export *` to aggregate their sub-barrels; leaf modules (`lib/<name>`, single-purpose files) re-export explicit names. The barrel is the public API either way.
- [invariant · desired] Each `api/` file declares its own `Payload`/`Response` types inside the file. Types shared across 2+ api files in the slice go in `api/types.ts`.
- [invariant · desired] Transport DTO types (request payloads, response shapes) live in `api/`, NOT in `model/`. `model/` holds domain/store types only.

### Per-layer anatomy

- **`01-app`** — the bootstrap entry file(s) at the layer root (count and shape defined by the active project type in `core/project-types/<t>.md`); `initial-plugins/` (the per-request `createApp()` factory, SSR-safe with no module-level state, plus imperative bootstrap initialisers that must run before `app.mount()`, and a barrel `index.ts`); `plugins/` (one file per Vue `app.use` plugin factory). The factory does NOT live at the layer root or in an entry file. Imports from any layer; imported by none.
- **`02-pages`** — `routes/<domain>.ts` composed in `routes/index.ts`; `ui/<Domain>/<Name>Page.vue` (thin frame); `layouts/`; `middlewares/` and `global-middlewares/` (`<name>.middleware.ts`); `config/` (the `Layouts` enum, the `GlobalMiddlewares` array, the `fallbackRoute` constant — NOT route builders, NOT the `RouteNames` enum, which is cross-layer and lives in `{shared-config}`); `utils/` (route builders `page()`, `group()`, `redirect()`, `getDefaultMeta()`); `types.ts` (`Route`, `Middleware`). A page is approximately one slice, and a page component does not pull entity data directly into its body — the only exception is a middleware reading an entity store for auth/guard decisions.
- **`03-widgets`** — `ui/` (the composite) + `model/use<Name>.ts` (view-state composable). Widgets have **no `api/`**: they read data through entity query-composables and fire mutations through features. [preference · desired] Not every block is a widget; uncombined main content belongs in the page.
- **`04-features`** — one user action = one slice, in one of three forms: form + mutation (`{ form, submit, submitError }`), read-fetcher (`{ items, isLoading }`), imperative trigger (`{ trigger, isPending }`). Anatomy: `ui/` + `model/use<Name>.ts`. **No `api/`** (that goes in the entity) and **no `lib/`**. State is strictly per-mount; module-level store variables are forbidden in features.
- **`05-composition`** — the slice **is** the component folder: `<Name>.vue` + `interface.ts` (CVA variants) + `index.ts`; no `ui/`, `model/`, or `api/` sub-directories. [invariant · desired] Stateless: no reactive state, no data fetching, no routing logic — if any are needed, promote to a widget. [invariant · desired] Does not import features or widgets; actions reach the component via slots (`<template #actions>`), never via imported feature components.
- **`06-entities`** — full slice declared all at once: `api/`, `model/store/`, `model/action/`, `model/query/`, `model/realtime/`, `ui/`, `config/`. [preference · desired] Entity-first: avoid thin entities that hold only types or only a store.

## 6. Internal module layout

Pattern skills name a **role** in prose — "the entity store lives in the `{entity}` module" —
never a path or an FSD segment suffix. This table is where that role reference resolves under
FSD: the concrete in-slice location for each role, consistent with the segment rules in
section 5.

| role | FSD location |
|---|---|
| entity store | `{entity}/model/store/` |
| entity query | `{entity}/model/query/` |
| entity query keys | `{entity}/model/query/keys.ts` |
| entity action | `{entity}/model/action/` |
| entity api | the entity's `api/` segment |
| widget view-state | `{widget}/model/` |
| feature view-state | `{feature}/model/` |

## 7. `07-shared` segments

| Segment | Contents |
|---|---|
| `assets/` | Global stylesheets and static files; organised as `styles/`, `images/`, `fonts/`. |
| `config/` | Pure identifiers and enums — only when used by 2+ layers, zero behaviour, and no single upper-layer owner. |
| `lib/` | Mini-libraries with a clear boundary wrapping an external system, OR an app-wide UI-state singleton. |
| `types/` | Type aliases and interfaces reused across 2+ layers. |
| `ui/` | Stateless, domain-neutral primitive components (buttons, inputs, typography). |
| `utils/` | Pure helper functions with broad reuse across 2+ layers. |

- [invariant · desired] Each `07-shared/` segment that exposes consumable items (`ui/`, `lib/`, `utils/`) has a barrel `index.ts`; external callers import from the segment barrel only — never deep-import an internal file (`@/07-shared/ui`, not `@/07-shared/ui/SomeComp.vue`).
- [invariant · desired] `{shared-utils}`'s `index.ts` is a **pure barrel** — explicit named re-exports only (`export { cn } from './cn'`), never implementation — same rule as `{shared-lib}`. Each helper still lives in its own file (`cn.ts`, `formatDate.ts`, …); the barrel is what makes `import { cn } from '{shared-utils}'` resolve.
- [invariant · desired] Global stylesheets and all static assets (images, fonts, SVGs) live in `{assets}` (`07-shared/assets`), organised as `styles/`, `images/`, `fonts/`. The app entry imports global CSS from `{assets}/styles/...`. No CSS or assets in `{app}`.
- [invariant · desired] `utils/` contains **a single pure function**: no state, no lifecycle, no external-system boundary, no side effects. If any of those are present, it belongs in `lib/`.
- [invariant · desired] `lib/` is **a module with a boundary**: it wraps an external system (fetch, `localStorage`, WebSocket, OAuth, analytics) OR it is an app-wide UI-state singleton (e.g. a notification queue, a modal stack). A `{shared-lib}/<name>/` entry lives in a dedicated subfolder whose `index.ts` is a **pure barrel** — explicit named re-exports only (`export { foo } from './foo'`), never `export *`, never implementation. The actual code lives in sibling files (one logical unit per file: `registry.ts`, `useQuery.ts`, …). The public surface is usually a `use<Name>` composable, but may be free functions or a small set of wrappers — whatever the boundary needs.
- [invariant · desired] **All access to an external system goes through the matching `lib/`** — e.g. `localStorage` only through `lib/local-persistence`, HTTP only through `lib/http-request`. Direct calls to `localStorage`, `fetch`, etc. outside their `lib/` are an anti-pattern.
- [invariant · desired] A function goes into `07-shared/utils` **only when** all three hold: (1) broadly reused across 2+ layers, (2) domain-neutral (no knowledge of any entity or feature), (3) small and pure (no state, no side effects, no external-system calls). If any condition fails, declare it at the call site. Dumping random helpers into `utils/` is an anti-pattern.

## 8. Routing buckets are NOT interchangeable

Do not collapse them into one `config/`:

- `{shared-config}` (`07-shared/config`) — **value constants only**, used by 2+ layers, zero behaviour (e.g. the `RouteNames` enum). Never functions, never types.
- `{pages-config}` (`02-pages/config`) — page-layer config: the `Layouts` enum, the `GlobalMiddlewares` array, and the `fallbackRoute` constant.
- `{pages-utils}` (`02-pages/utils`) — route **builder functions** (`page()`, `group()`, `redirect()`, `getDefaultMeta()`). Functions never go in any `config/`.
- `{pages-types}` (`02-pages/types.ts`) — routing **types** (`Route`, `Middleware`). Types never go in any `config/`.
- `{middlewares}` / `{global-middlewares}` — middleware **implementation files**, one per file named `<name>.middleware.ts`; the `GlobalMiddlewares` array that lists them lives in `{pages-config}`.
