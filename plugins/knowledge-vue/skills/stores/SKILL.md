---
name: stores
description: Use when adding or editing reactive shared state in a Vue project — module-level stores, entity stores with persistence, widget view-state, or feature-scoped state. Covers the no-Pinia, no-defineStore pattern with module-reactive singletons.
---

# stores (Vue) — module-reactive state

Read `../../core/placement.md` first for the `{entity}`, `{widget}`, `{feature}`, `{shared-lib}` tokens; paths resolve in the active architecture doc.

State is managed with plain Vue reactivity at module level — no Pinia, no `defineStore`.
One module = one singleton instance per app boot.

Read `references/store.md` (CSR) or `references/store.ssr.md` (SSR) and
reproduce the one matching the project's `projectType` (fixed by the
`vue-work` skill's step 0) — never both. Each holds the complete files for
all three store shapes; the two variants differ only in
`useSessionStore.ts`'s persistence-init arm (see "Persistence init" below).

## Core rules

- [invariant · desired] **No Pinia. No `defineStore`.** State is a module-level `reactive()`
  (or `ref()`) object declared once. It is shared as a singleton for the lifetime of the app.
- [invariant · desired] **Setters are bare named functions**, exported directly from the module,
  declared outside the composable. They mutate the module-level state directly. They are NOT
  returned from `useXStore()`.
- [invariant · desired] **`useXStore()` returns only `computed` / readonly projections** — never
  the raw `state` object, never setters. Callers read state through computed refs; they call
  setters by importing them from the module.
- [invariant · legacy] A module-singleton store is **CSR-only under SSR**: the server keeps
  the store at its default value across all concurrent requests (the module is shared). Never
  put per-user or per-request data in a module-level store on the server. The real value is
  restored on the client after hydration.

## Store varieties

| Variety | Location | Persistence | Reactive scope |
|---|---|---|---|
| Entity store | `{entity}` — entity store | yes — via `persistence` skill | module-level singleton |
| Widget view-state | `{widget}` — widget view-state | no | module-level singleton |
| Feature state | `{feature}` — feature view-state | no | per-mount (fresh on each `setup` call) |

- **Entity store** — holds business state that survives navigation and may be persisted.
  Storage keys live in a `keys.ts` file beside the store, holding one `STORAGE_KEYS` const
  object (`as const`) plus a `StorageKey` type derived from it — never scattered string
  literals. Storage access uses the `persistence` skill (by name).
- **Widget view-state** — UI-only state (open/closed, selected tab) shared across the
  widget's components. Module-reactive, no persistence.
- **Feature state** — declared inside the composable body, not at module level. A fresh
  instance is created on each `setup` call. Do NOT use module-level `reactive` for feature
  state. In the etalon's feature shape, the state isn't a local `ref`/`reactive` at all —
  it's *derived* via `computed` from an entity action and a shared-lib composable. That's
  the point of the shape (nothing module-level, nothing to reset between mounts), not an
  omission.

## Persistence init (entity stores)

- **Without SSR** — read the stored value directly at module-level declaration time; the
  state's initial value comes straight from storage.
- **With SSR** — do NOT read storage at declaration time (the server has no `localStorage`).
  Register a hydration callback with `registerHydration` (from the `hydration` skill by name)
  at module level; the state stays at its default until the callback runs once on the client
  after the root `<Suspense>` resolves.

✅ do:
- Declare `state` once at module level with `reactive()` or `ref()`.
- Export setters as plain named functions at the module top level.
- Return only `computed` refs from `useXStore()`.
- Declare storage keys in a sibling `keys.ts` file as a single `STORAGE_KEYS` object
  `as const` (flat dot-namespace values, e.g. `'session.authenticated'`), exporting the
  derived `StorageKey` type alongside it.
- For SSR projects, use `registerHydration` (the `hydration` skill) instead of reading
  storage at declaration time.

❌ don't:
- Use `defineStore`, `createPinia`, or any Pinia API.
- Return the raw `state` object or a setter from `useXStore()`.
- Read `localStorage` directly — always use the `persistence` skill by name.
- Put per-user or per-request data in a module-singleton store when SSR is active.
- Declare feature-scoped state at module level.

## Related skills (by name)

persistence · hydration · tanstack-query
