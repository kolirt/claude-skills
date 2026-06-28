# FSD layers — per-layer anatomy

## 01-app — composition root

- `entryClient.ts` / `entryServer.ts` — environment entry points.
- Per-request `createApp()` factory (SSR-safe; no module-level state).
- `plugins/` — one file per plugin; each file registers exactly one plugin.
- `initial-plugins/` — async initialisers that must complete before `app.mount()`.

Import direction: imports from any layer; imported by none.

---

## 02-pages — routing

- `routes/<domain>.ts` — route records for one domain; composed in `routes/index.ts`.
- `ui/<Domain>/<Name>Page.vue` — thin frame component; delegates to lower layers.
- `layouts/` — layout components resolved by the global layout middleware.
- `middlewares/` — per-route middleware impl files (`<name>.middleware.ts`).
- `global-middlewares/` — global middleware impl files (`<name>.middleware.ts`).
- `config/` — the `Layouts` enum and the `GlobalMiddlewares` array (NOT route builders, NOT
  the `RouteNames` enum — that is cross-layer and lives in `07-shared/config`).
- `utils/` — route builder functions (`page()`, `group()`, `redirect()`) + page-layer helpers.
- `types.ts` — routing types (`Route`, `Middleware`).

A page is approximately one slice. A page component **does not pull entity data directly into its body** — the only exception is a middleware reading an entity store for auth/guard decisions.

---

## 03-widgets — stateful composites

- `ui/` — the composite component(s).
- `model/use<Name>.ts` — view-state composable (local reactive state, coordinates children).

Widgets do **not** contain `api/`: they read data through entity query-composables and fire mutations through features. Use a widget when a block is stateful and reused on 2+ pages, or when it is large and stands alone as an independent section.

[preference · desired] Not every block is a widget. Uncombined main content belongs in the page.

---

## 04-features — user actions

One user action = one slice. A feature may take one of three forms:

- **Form + mutation** — state: `{ form, submit, submitError }`.
- **Read-fetcher** — state: `{ items, isLoading }`.
- **Imperative trigger** — state: `{ trigger, isPending }`.

Anatomy: `ui/` + `model/use<Name>.ts`. **No `api/`** (goes in the entity) and **no `lib/`**. State is strictly per-mount; module-level store variables are forbidden in features.

---

## 05-composition — stateless domain composites

The slice **is** the component folder: `<Name>.vue` + `interface.ts` (CVA variants) + `index.ts`.

- No `ui/`, `model/`, or `api/` sub-directories.
- Receives an entity as a prop, lays out its relations, renders them using entity UI components.
- [invariant · desired] Stateless: no reactive state, no data fetching, no routing logic. If any of these are needed, promote the component to a widget.
- [invariant · desired] Does not import features or widgets (import direction is down-only). Actions reach the component via slots (`<template #actions>`), never via imported feature components.

---

## 06-entities — business entities

Full slice anatomy, declared all at once:

- `api/` — HTTP calls and response types.
- `model/store/` — Pinia store.
- `model/action/` — mutation composables.
- `model/query/` — read/fetch composables.
- `model/realtime/` — WebSocket / SSE listeners.
- `ui/` — entity display components.
- `config/` — entity-local constants / enums.

[preference · desired] Entity-first: each entity is declared as a full slice immediately. Avoid thin entities that hold only types or only a store.

Cross-entity type references only: use the `@x` notation — `06-entities/<A>/@x/<B>.ts` re-exports types from entity B for consumption inside entity A (`import type` only; no runtime cross-entity imports).

---

## 07-shared — domain-neutral infrastructure

See `shared-segments.md` for the full segment breakdown.
