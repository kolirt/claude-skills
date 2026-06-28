# Placement (Vue) — where files go

The **location vocabulary** for the Vue domain. A skill never hard-codes a path; it
places its artifacts using the **tokens** below, and this file resolves each token to
a concrete path for the **current project's architecture**.

## 1. Detect the architecture
- **FSD** — the source root has numbered layer directories (`01-app`, `02-pages`, …,
  `07-shared`).
- **non-FSD** — a flat `src/` (e.g. `src/components`, `src/pages`).
- If it cannot be determined, **ask the developer**.

## 2. Location tokens → concrete paths

| token | FSD | non-FSD |
|---|---|---|
| `{app}` | `01-app` | `src/app` |
| `{plugins}` | `01-app/plugins` | `src/plugins` |
| `{routes}` | `02-pages/routes` | `src/router/routes` |
| `{pages-utils}` | `02-pages/utils` | `src/router/utils` |
| `{pages-types}` | `02-pages/types.ts` | `src/router/types.ts` |
| `{pages-config}` | `02-pages/config` | `src/router/config` |
| `{middlewares}` | `02-pages/middlewares` | `src/router/middlewares` |
| `{global-middlewares}` | `02-pages/global-middlewares` | `src/router/middlewares/global` |
| `{pages-ui}` | `02-pages/ui/<domain>` | `src/pages/<domain>` |
| `{layouts}` | `02-pages/layouts` | `src/layouts` |
| `{shared-config}` | `07-shared/config` | `src/config` |
| `{shared-ui}` | `07-shared/ui` | `src/components` |
| `{shared-lib}` | `07-shared/lib` | `src/lib` |
| `{composition}` | `05-composition` | `src/components` |
| `{feature}` | `04-features/<name>` | `src/components/<name>` |
| `{widget}` | `03-widgets/<name>` | `src/components/<name>` |
| `{entity}` | `06-entities/<name>` | `src/composables/<name>` |

Tokens with no native non-FSD layer (`{feature}`, `{widget}`, `{composition}`)
collapse to the flat components location.

`{app}` holds the app entry point (`createApp` / per-request factory), plugin registration
(`plugins/`), and async pre-mount initialisation (`initial-plugins/`).

**Routing buckets are NOT interchangeable** — do not collapse them into one `config/`:
- `{shared-config}` (`07-shared/config`) — **value constants only**, used by 2+ layers, zero
  behaviour (e.g. the `RouteNames` enum, `LEGAL_LINKS`). Never functions, never types.
- `{pages-config}` (`02-pages/config`) — page-layer config: the `Layouts` enum and the
  `GlobalMiddlewares` array.
- `{pages-utils}` (`02-pages/utils`) — route **builder functions** (`page()`, `group()`,
  `redirect()`, `getDefaultMeta()`). Functions never go in any `config/`.
- `{pages-types}` (`02-pages/types.ts`) — routing **types** (`Route`, `Middleware`). Types
  never go in any `config/`.
- `{middlewares}` / `{global-middlewares}` — middleware **implementation files**, one per
  file named `<name>.middleware.ts`; the `GlobalMiddlewares` array that lists them lives in
  `{pages-config}`.

**A `{shared-lib}/<name>/` module's `index.ts` is a pure barrel** — explicit named
re-exports only (`export { foo } from './foo'`), never implementation. The actual code lives
in sibling files (one logical unit per file: `registry.ts`, `useQuery.ts`, …). Putting the
implementation directly in `index.ts` is the anti-pattern.

> Notation: `{token}` is a placement token — resolve it via this table; in an **import
> path** a token resolves under the project's `@`/`~` src alias. Non-token placeholders
> use `<...>` (e.g. `<API_BASE>`, `<your-app-name>`), never `{...}`.

## 3. FSD layer reference
Numbered layers, dependency direction downward (`01-app` → … → `07-shared`):
- `01-app` — bootstrap: app entry, plugin registration (`plugins/`), root setup.
- `02-pages` — routing: route definitions (`routes/`), page components (`ui/`),
  route builders (`utils/`), routing types (`types.ts`), per-route middlewares
  (`middlewares/`), global middlewares (`global-middlewares/`), page-layer config
  (`config/`: `Layouts` enum + `GlobalMiddlewares` array).
- `03-widgets` — composite UI blocks (domain-grouped).
- `04-features` — user-facing flows (domain-grouped).
- `05-composition` — stateless UI composites (no state, no fetching) — custom layer.
- `06-entities` — business entities (`api/` + `model/` + `ui/`).
- `07-shared` — shared `lib/` `ui/` `config/` `types/`, no domain knowledge.

Slice shape inside a domain folder: `api/` + `model/` + `ui/` + a barrel `index.ts`.
A skill that needs a layer not in the token table refers to it by its name here.
