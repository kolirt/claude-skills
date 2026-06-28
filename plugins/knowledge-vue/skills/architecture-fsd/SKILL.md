---
name: architecture-fsd
description: Use when deciding which FSD layer/slice code belongs to, or wiring imports between layers — the layer model, decision order, and dependency rules. Path resolution is placement.md.
---

# architecture-fsd (Vue) — layer/slice placement and dependency rules

Read `../../core/placement.md` first (resolve layer tokens to concrete paths).

## Layer table

| # | Layer | Responsibility |
|---|---|---|
| 01 | app | Composition root: `createApp`, per-request factory, plugin registration, pre-mount async init. |
| 02 | pages | Route-level assembly: route records, page components (thin frames), layouts, middlewares. |
| 03 | widgets | Stateful composites reused on 2+ pages, or large independent blocks not yet combined with others. |
| 04 | features | One user action = one slice: mutation forms, read-fetchers, imperative triggers. |
| 05 | composition | Stateless domain composites: lays out an entity and its relations; no state, no fetch, no routing. |
| 06 | entities | Business entities: full slice (`api/` + `model/` + `ui/`) declared at once. |
| 07 | shared | Domain-neutral primitives, utilities, infrastructure, and app-wide singletons. |

See `references/layers.md` for per-layer anatomy.

## "Where does it go" — decision order (take first match)

1. **Domain entity** → `06-entities/<name>` — entity-first: declare the full slice at once, never a thin stub. [preference · desired]
2. **User action** (mutation, form submit, read-trigger) → `04-features/<name>` — one action = one slice.
3. **Assemble a ready entity UI** (no own state, no fetch, no routing; reused across contexts) → `05-composition/<name>` — actions arrive via slots, not props.
4. **Stateful composite reused on 2+ pages**, or a large independent block that stands alone → `03-widgets/<name>`. Uncombined main content stays in the page; not every block is a widget. [preference · desired]
5. **Domain-neutral primitive / utility / infrastructure** → `07-shared/<segment>` — see `references/shared-segments.md`.
6. **Route-level assembly** → `02-pages/<domain>` — page component is a thin frame that composes layers below.

## Dependency rules

- [invariant · desired] Import **DOWN only**: a layer may only import from layers with a **higher** number (lower layers = more context; higher numbers = more generic). Example: `04-features` may import `06-entities` and `07-shared`, never `03-widgets` or `02-pages`.
- [invariant · desired] **Same-layer slices do not import each other.** Lift shared code down (to a lower layer) or up (to a higher layer) instead.
- [invariant · desired] **Exception — entities↔entities type-only**: cross-entity type references use `@x` notation (`06-entities/<A>/@x/<B>.ts`, `import type` only). No runtime cross-entity imports.
- [invariant · desired] Each slice exposes a **barrel `index.ts`** as its public API. Consumers import from the barrel only.
- [invariant · desired] Every segment inside a slice (`api/`, `model/`, `ui/`, and nested sub-segments such as `model/query`, `model/action`, `model/store`, `ui/<component>`) also has its own `index.ts` barrel; the slice barrel composes these segment barrels (e.g. `export * from './model'`), not deep file paths. (FSD; non-FSD: same barrel rule applies to each `src/lib/<name>` / `src/composables/<name>` module.)
- [invariant · desired] Slice and segment barrels MAY use `export *` to aggregate their sub-barrels; leaf modules (`lib/<name>`, single-purpose files) re-export explicit names. The barrel is the public API either way.
- [invariant · desired] **`app` and `shared` are layer+segment** (no slice level): code inside them may import each other freely within the same layer.

## Segments (inside a slice)

| Segment | Purpose |
|---|---|
| `ui/` | Display components |
| `api/` | Backend calls. Each file declares its own `Payload`/`Response` types inline; types shared across 2+ api files in the same slice go in `api/types.ts`. Transport DTO types (request payloads, response shapes) live here, NOT in `model/`. |
| `model/` | Data, state, logic (in entities: split into `store/`, `action/`, `query/`, `realtime/`) |
| `lib/` | Slice-local utilities (not exported) |
| `config/` | Slice-local constants / enums |

Name segments by **purpose**, not by essence. `hooks/`, `types/`, `components/` are bad segment names.

- [invariant · desired] Each `api/` file declares its own `Payload`/`Response` types inside the file. Types shared across 2+ api files in the slice go in `api/types.ts`.
- [invariant · desired] Transport DTO types (request payloads, response shapes) live in `api/`, NOT in `model/`. `model/` holds domain/store types only.

## Placement

Resolve layer paths via `../../core/placement.md` tokens (`{app}`, `{entity}`, `{feature}`, `{widget}`, `{composition}`, `{pages-ui}`, `{shared-ui}`, `{shared-lib}`, …). Layer numbers are the real directory prefixes — read them from the source root.

## Related skills (by name)

stores · tanstack-query · ssr · pages
