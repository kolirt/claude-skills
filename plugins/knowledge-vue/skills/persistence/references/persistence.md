# Persistence wrappers — full-file etalon

Two thin, imperative wrappers around Web Storage — `local-persistence`
(localStorage) and `session-persistence` (sessionStorage) — both sharing an
SSR guard, JSON serialisation with a `try/catch` fallback, and an overloaded
`get<T>` (fallback vs. `null`). Storage keys are declared at the call site, not
centralised here; the `session` entity's key file and consuming store
(`useSessionStore`) are owned by the `stores` skill's own etalon.

## Files

- `{shared-lib}/local-persistence/useLocalPersistence.ts`
- `{shared-lib}/local-persistence/index.ts`
- `{shared-lib}/session-persistence/useSessionPersistence.ts`
- `{shared-lib}/session-persistence/index.ts`

`{entity}/session/model/store/keys.ts` is owned by the `stores` skill's `store.md`
(CSR) / `store.ssr.md` (SSR) etalon (pick by `projectType`) — imported by token,
not reproduced here.

**File:** `{shared-lib}/local-persistence/useLocalPersistence.ts`
```ts
export function useLocalPersistence() {
  function get<T>(key: string): T | null
  function get<T>(key: string, fallback: T): T
  function get<T>(key: string, fallback: T | null = null): T | null {
    if (import.meta.env.SSR) return fallback

    const raw = localStorage.getItem(key)
    if (raw === null) return fallback

    try {
      return JSON.parse(raw) as T
    } catch {
      return fallback
    }
  }

  function set<T>(key: string, value: T): void {
    if (import.meta.env.SSR) return

    if (value === undefined) {
      localStorage.removeItem(key)
      return
    }

    localStorage.setItem(key, JSON.stringify(value))
  }

  function remove(key: string): void {
    if (import.meta.env.SSR) return

    localStorage.removeItem(key)
  }

  return { get, set, remove }
}
```

**File:** `{shared-lib}/local-persistence/index.ts`
```ts
export { useLocalPersistence } from './useLocalPersistence'
```

**File:** `{shared-lib}/session-persistence/useSessionPersistence.ts`
```ts
export function useSessionPersistence() {
  function get<T>(key: string): T | null
  function get<T>(key: string, fallback: T): T
  function get<T>(key: string, fallback: T | null = null): T | null {
    if (import.meta.env.SSR) return fallback

    const raw = sessionStorage.getItem(key)
    if (raw === null) return fallback

    try {
      return JSON.parse(raw) as T
    } catch {
      return fallback
    }
  }

  function set<T>(key: string, value: T): void {
    if (import.meta.env.SSR) return

    if (value === undefined) {
      sessionStorage.removeItem(key)
      return
    }

    sessionStorage.setItem(key, JSON.stringify(value))
  }

  function remove(key: string): void {
    if (import.meta.env.SSR) return

    sessionStorage.removeItem(key)
  }

  return { get, set, remove }
}
```

**File:** `{shared-lib}/session-persistence/index.ts`
```ts
export { useSessionPersistence } from './useSessionPersistence'
```

## Consuming store — persistence wiring only

`keys.ts` is a sibling of the store it serves (`{entity}/session/model/store/keys.ts`,
next to `useSessionStore.ts`), not a central registry. The store imports
`useLocalPersistence` and `STORAGE_KEYS`, creates the wrapper once at module
level, reads the stored value during hydration (`get` with a default), and
calls `set` on the transition that turns the flag on and `remove` on the one
that clears it. The full store file (module `reactive()` state, `useXStore()`,
setters) is the `stores` skill's own etalon — not reproduced here, even as a
partial snippet, since an etalon holds whole files.

## Related skills (by name)

stores · hydration
