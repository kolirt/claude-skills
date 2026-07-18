# Placement (Vue) — where files go

The **location vocabulary** for the Vue domain. A skill never hard-codes a path; it
places its artifacts using the **tokens** below. This file *names* the tokens and their
roles — it does not resolve them to paths. Path resolution for the active architecture
lives in `core/architectures/<a>.md` (`fsd.md` or `non-fsd.md`), pre-loaded by `vue-work`
step 0.

## 1. Location tokens → role

| token | role |
|---|---|
| `{app}` | Composition root: entry files, bootstrap. |
| `{plugins}` | Vue `app.use` plugin factories. |
| `{initial-plugins}` | Per-request `createApp` factory + imperative bootstrap initialisers. |
| `{routes}` | Route records, one file per domain. |
| `{pages-utils}` | Route builder functions (`page()`, `group()`, `redirect()`, `getDefaultMeta()`). |
| `{pages-types}` | Routing types (`Route`, `Middleware`). |
| `{pages-config}` | Page-layer config: `Layouts` enum, `GlobalMiddlewares` array, `fallbackRoute` constant. |
| `{middlewares}` | Per-route middleware implementation files. |
| `{global-middlewares}` | Global middleware implementation files. |
| `{pages-ui}` | Page components (thin frames), grouped by domain. |
| `{layouts}` | Layout components. |
| `{shared-config}` | Value constants only, used by 2+ layers, zero behaviour (e.g. `RouteNames` enum). |
| `{shared-ui}` | Domain-neutral primitive components. |
| `{shared-lib}` | Mini-libraries wrapping an external system, or app-wide UI-state singletons. |
| `{shared-utils}` | Single pure helper functions with broad reuse and no external-system boundary (e.g. a `cn()` class merger). |
| `{composition}` | Stateless domain composites: lays out an entity and its relations; no state, no fetch, no routing. |
| `{feature}` | One user action = one slice: mutation forms, read-fetchers, imperative triggers. |
| `{widget}` | Stateful composite reused on 2+ pages, or a large independent block. |
| `{entity}` | Business entity: full slice (api + state + read/mutate) declared at once. |
| `{assets}` | Global stylesheets and static files. |

`{app}` holds the app bootstrap surface and the root component. The per-request `createApp`
factory and imperative bootstrap initialisers live in `{initial-plugins}`, and the Vue
`app.use` plugin factories in `{plugins}` — not directly in `{app}`. The concrete bootstrap
shape (how many entry files, what each one does) is defined by the active project type in
`core/project-types/<t>.md`, not here.

**Routing buckets are NOT interchangeable** — do not collapse them into one `config/`:
- `{shared-config}` — **value constants only**, used by 2+ layers, zero behaviour (e.g. a
  `RouteNames` enum, `LEGAL_LINKS`). Never functions, never types.
- `{pages-config}` — page-layer config: the `Layouts` enum, the `GlobalMiddlewares` array,
  and the `fallbackRoute` constant.
- `{pages-utils}` — route **builder functions** (`page()`, `group()`, `redirect()`,
  `getDefaultMeta()`). Functions never go in any `config/`.
- `{pages-types}` — routing **types** (`Route`, `Middleware`). Types never go in any
  `config/`.
- `{middlewares}` / `{global-middlewares}` — middleware **implementation files**, one per
  file named `<name>.middleware.ts`; the `GlobalMiddlewares` array that lists them lives in
  `{pages-config}`.

**A `{shared-lib}/<name>/` module's `index.ts` is a pure barrel** — explicit named
re-exports only (`export { foo } from './foo'`), never implementation. The actual code lives
in sibling files (one logical unit per file: `registry.ts`, `useQuery.ts`, …). Putting the
implementation directly in `index.ts` is the anti-pattern.

> Notation: `{token}` is a placement token — resolve it via the active
> `core/architectures/<a>.md`; in an **import path** a token resolves under the project's
> `@`/`~` src alias. Non-token placeholders use `<...>` (e.g. `<API_BASE>`,
> `<your-app-name>`), never `{...}`.

## 2. Naming conventions

[invariant · desired] Follow these project-wide file and folder naming rules:
- **Folders → kebab-case** (`http-request`, `global-middlewares`, `add-comment`).
- **TS/JS files → camelCase** (`globalMiddlewares.ts`, `closeModals.middleware.ts`, `routeNames.ts`, `useHttpRequest.ts`, `entryClient.ts`).
- **Vue SFC components → PascalCase** (`DefaultLayout.vue`, `PostCard.vue`).
