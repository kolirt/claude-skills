---
name: persistence
description: Use when reading or writing browser storage (localStorage / sessionStorage) in a Vue project — creating a persistence wrapper, defining storage keys, or integrating storage access into a store. Never touch Web Storage APIs directly; the wrapper lives in {shared-lib}.
---

# persistence (Vue) — browser storage via a typed wrapper

Read `../../core/placement.md` first (resolve `{shared-lib}`).

All browser storage access is centralised in two thin wrappers:
`{shared-lib}/local-persistence` (localStorage) and
`{shared-lib}/session-persistence` (sessionStorage).
No other file in the project imports `localStorage` or `sessionStorage` directly.

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
- [invariant · desired] **Storage keys live in a sibling `keys.ts`** as a typed `STORAGE_KEYS`
  `as const` object. Keys use a **flat dot-namespace** (`'session.authenticated'`,
  `'ui.sidebar.collapsed'`). They are NOT query-key-factory keys (those are hierarchical
  cache keys; storage keys are flat strings).
- [anti-pattern · desired] **Do NOT replace with VueUse `useLocalStorage`.** Its reactive ref
  reads storage outside the controlled hydration moment and creates a second source of truth
  that diverges from the store. Use the imperative wrapper + the `stores` / `hydration` skills
  instead.

## Wrapper shape

```ts
// {shared-lib}/local-persistence/index.ts
import { STORAGE_KEYS } from './keys'

function isServer() { return import.meta.env.SSR }

export function get<T>(key: string, fallback: T): T
export function get<T>(key: string): T | null
export function get<T>(key: string, fallback?: T): T | null {
  if (isServer()) return fallback ?? null
  try {
    const raw = localStorage.getItem(key)
    if (raw === null) return fallback ?? null
    return JSON.parse(raw) as T
  } catch {
    return fallback ?? null
  }
}

export function set<T>(key: string, value: T): void {
  if (isServer()) return
  try { localStorage.setItem(key, JSON.stringify(value)) } catch { /* quota / private mode */ }
}

export function remove(key: string): void {
  if (isServer()) return
  localStorage.removeItem(key)
}

export { STORAGE_KEYS }
```

## Storage keys

```ts
// {shared-lib}/local-persistence/keys.ts
export const STORAGE_KEYS = {
  session: {
    authenticated: 'session.authenticated',
    token: 'session.token',
  },
  ui: {
    sidebarCollapsed: 'ui.sidebar.collapsed',
  },
} as const
```

✅ do:
- Import `get` / `set` / `remove` + `STORAGE_KEYS` from `{shared-lib}/local-persistence`.
- Add new keys to `STORAGE_KEYS` as flat dot-namespaced strings.
- Let the store (not the wrapper) hold reactive state; the wrapper is called during
  hydration or on user action, not observed with a watch.

❌ don't:
- Call `localStorage.setItem(...)` / `sessionStorage.getItem(...)` anywhere outside the wrapper.
- Create a reactive ref in the wrapper (`ref(localStorage.getItem(...))`).
- Reuse query-key-factory keys as storage keys.
- Import `useLocalStorage` from VueUse.

## Related skills (by name)

stores · hydration
