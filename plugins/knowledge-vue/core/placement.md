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
| `{route-config}` | `07-shared/config` | `src/router` |
| `{middlewares}` | `02-pages/middlewares` | `src/router/middlewares` |
| `{global-middlewares}` | `02-pages/config` | `src/router/middlewares/global` |
| `{pages-ui}` | `02-pages/ui/<domain>` | `src/pages/<domain>` |
| `{layouts}` | `02-pages/layouts` | `src/layouts` |
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

> Notation: `{token}` is a placement token — resolve it via this table; in an **import
> path** a token resolves under the project's `@`/`~` src alias. Non-token placeholders
> use `<...>` (e.g. `<API_BASE>`, `<your-app-name>`), never `{...}`.

## 3. FSD layer reference
Numbered layers, dependency direction downward (`01-app` → … → `07-shared`):
- `01-app` — bootstrap: app entry, plugin registration (`plugins/`), root setup.
- `02-pages` — routing: route definitions (`routes/`), page components (`ui/`),
  route middlewares (`middlewares/`), routing config (`config/`).
- `03-widgets` — composite UI blocks (domain-grouped).
- `04-features` — user-facing flows (domain-grouped).
- `05-composition` — stateless UI composites (no state, no fetching) — custom layer.
- `06-entities` — business entities (`api/` + `model/` + `ui/`).
- `07-shared` — shared `lib/` `ui/` `config/` `types/`, no domain knowledge.

Slice shape inside a domain folder: `api/` + `model/` + `ui/` + a barrel `index.ts`.
A skill that needs a layer not in the token table refers to it by its name here.
