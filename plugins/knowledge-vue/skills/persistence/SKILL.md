---
name: persistence
description: Use when reading or writing browser storage (localStorage / sessionStorage) in a Vue project — creating a persistence wrapper, defining storage keys, or integrating storage access into a store. Never touch Web Storage APIs directly; the wrapper lives in {shared-lib}.
---

# persistence (Vue) — browser storage via a typed wrapper

Read `../../core/placement.md` first for the `{shared-lib}` token; paths resolve in the active architecture doc.

All browser storage access is centralised in two thin wrappers:
`{shared-lib}/local-persistence` (localStorage) and
`{shared-lib}/session-persistence` (sessionStorage).
No other file in the project imports `localStorage` or `sessionStorage` directly.

Read `references/persistence.md` and reproduce it — it holds the complete files for the two
storage wrappers. Storage-key declarations live at the call site with the consuming store and
are owned by the `stores` skill's own etalon, not by this one.

## Rules

- [invariant · desired] **Never access `localStorage` or `sessionStorage` directly** — always
  call `{shared-lib}/local-persistence` or `{shared-lib}/session-persistence`. This keeps
  the SSR guard, serialisation, and error handling in one place.
- [invariant · desired] **Wrappers are imperative, not reactive.** They expose `get` / `set` /
  `remove` functions only. Reactivity is the responsibility of the calling store (see the
  `stores` skill by name).
- [invariant · desired] Both wrappers include an **SSR guard**: when `import.meta.env.SSR`
  is `true`, `set` and `remove` are no-ops, and `get` returns the typed fallback (or `null`).
  This makes them safe to import at module level in SSR projects.
- [invariant · desired] Values are **JSON-serialised** inside the wrapper with `try/catch`.
  A parse error on `get` returns the fallback (or `null`) and does not throw.
- [invariant · desired] `get<T>(key, fallback: T): T` — always returns `T`.
  `get<T>(key): T | null` — returns `null` when the key is absent or unreadable.
- [invariant · desired] The persistence lib is **key-agnostic**: `useLocalPersistence()`
  exposes `get/set/remove(key: string, ...)` and owns no keys registry.
- [invariant · desired] **Storage keys are declared in a `keys.ts` file beside the
  store or feature that persists**, as one `STORAGE_KEYS` object `as const` plus a derived
  `StorageKey` type — never scattered string literals at the call site. There is **no
  central keys registry** in `{shared-lib}/local-persistence` itself; each keys file is
  scoped to its consuming module. Keys use a flat dot-namespace (e.g. `'session.authenticated'`,
  `'ui.sidebar.collapsed'`); they are NOT query-key-factory keys (those are hierarchical
  cache keys; storage keys are flat strings).
- [invariant · desired] `{shared-lib}/local-persistence/index.ts` is a **pure barrel**:
  `export { useLocalPersistence } from './useLocalPersistence'`. The implementation lives
  in the sibling `useLocalPersistence.ts`. No implementation code in `index.ts`.
- [anti-pattern · desired] **Do NOT replace with VueUse `useLocalStorage`.** Its reactive ref
  reads storage outside the controlled hydration moment and creates a second source of truth
  that diverges from the store. Use the imperative wrapper + the `stores` / `hydration` skills
  instead.

## Key declaration

Storage keys are owned by the module that uses them: a `keys.ts` file sibling of the
consuming store or feature, exporting one `STORAGE_KEYS` object `as const` and its
derived `StorageKey` type. This etalon (`references/persistence.md`) does not ship
`keys.ts` — the `stores` skill's own etalon (`store.md` / `store.ssr.md`) owns and
reproduces it, since it lives beside the store that consumes it.

✅ do:
- Import `useLocalPersistence` from `{shared-lib}/local-persistence`; destructure `get` / `set` / `remove`.
- Declare storage keys in a sibling `keys.ts` file as a `STORAGE_KEYS` object `as const` (flat dot-namespace values).
- Let the store (not the wrapper) hold reactive state; the wrapper is called during
  hydration or on user action, not observed with a watch.

❌ don't:
- Call `localStorage.setItem(...)` / `sessionStorage.getItem(...)` anywhere outside the wrapper.
- Create a reactive ref in the wrapper (`ref(localStorage.getItem(...))`).
- Create a central keys file or `STORAGE_KEYS` registry inside the persistence lib itself.
- Reuse query-key-factory keys as storage keys.
- Import `useLocalStorage` from VueUse.

## Related skills (by name)

stores · hydration
