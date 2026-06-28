---
name: stores
description: Use when adding or editing reactive shared state in a Vue project — module-level stores, entity stores with persistence, widget view-state, or feature-scoped state. Covers the no-Pinia, no-defineStore pattern with module-reactive singletons.
---

# stores (Vue) — module-reactive state

Read `../../core/placement.md` first (resolve `{entity}`, `{widget}`, `{feature}`, `{shared-lib}`).

State is managed with plain Vue reactivity at module level — no Pinia, no `defineStore`.
One module = one singleton instance per app boot.

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
| Entity store | `{entity}/model/store/` | yes — via `persistence` skill | module-level singleton |
| Widget view-state | `{widget}/model/` | no | module-level singleton |
| Feature state | `{feature}/model/` | no | per-mount (fresh on each `setup` call) |

- **Entity store** — holds business state that survives navigation and may be persisted.
  Storage keys are declared as local string constants at the call site; storage access uses
  the `persistence` skill (by name).
- **Widget view-state** — UI-only state (open/closed, selected tab) shared across the
  widget's components. Module-reactive, no persistence.
- **Feature state** — declared inside the composable body, not at module level. A fresh
  instance is created on each `setup` call. Do NOT use module-level `reactive` for feature
  state.

## Persistence init (entity stores)

- **Without SSR** — read the stored value directly at module-level declaration time.
  ```ts
  const SESSION_AUTHENTICATED_KEY = 'session.authenticated'
  const { get } = useLocalPersistence()
  const state = reactive({ authenticated: get(SESSION_AUTHENTICATED_KEY, false) })
  ```
- **With SSR** — do NOT read storage at declaration time (the server has no `localStorage`).
  Register a hydration callback with `registerHydration` (from the `hydration` skill by name)
  at module level. The callback runs once on the client after the root `<Suspense>` resolves.
  ```ts
  // With SSR: initial value stays at the default; storage is read after mount.
  const SESSION_AUTHENTICATED_KEY = 'session.authenticated'
  const { get } = useLocalPersistence()
  const state = reactive({ authenticated: false })
  registerHydration('session', () => {
    state.authenticated = get(SESSION_AUTHENTICATED_KEY, false)
  })
  ```

## Module-reactive entity store — annotated sample

```ts
// {entity}/model/store/index.ts
import { computed, reactive } from 'vue'
import { useLocalPersistence } from '{shared-lib}/local-persistence'
// import { registerHydration } from '{shared-lib}/hydration'  // ← uncomment for SSR projects

// ── storage keys declared at the call site ────────────────────────────────────
const SESSION_AUTHENTICATED_KEY = 'session.authenticated'
const SESSION_TOKEN_KEY = 'session.token'

const { get, set, remove } = useLocalPersistence()

// ── module-level state (one instance per app) ────────────────────────────────
const state = reactive({
  authenticated: false,   // SSR: stays false; see registerHydration block below
  token: null as string | null,
})

// SSR projects only — defer storage read to the client hydration moment:
// registerHydration('session', () => {
//   state.authenticated = get(SESSION_AUTHENTICATED_KEY, false)
//   state.token         = get(SESSION_TOKEN_KEY)
// })

// ── setters (exported directly, NOT via useSessionStore) ─────────────────────
export function setAuthenticated(value: boolean): void {
  state.authenticated = value
  set(SESSION_AUTHENTICATED_KEY, value)
}

export function setToken(token: string): void {
  state.token = token
  set(SESSION_TOKEN_KEY, token)
}

export function clearSession(): void {
  state.authenticated = false
  state.token = null
  remove(SESSION_AUTHENTICATED_KEY)
  remove(SESSION_TOKEN_KEY)
}

// ── getter composable (computed / readonly projections only) ──────────────────
export function useSessionStore() {
  return {
    isAuthenticated: computed(() => state.authenticated),
    token: computed(() => state.token),
  }
}
```

✅ do:
- Declare `state` once at module level with `reactive()` or `ref()`.
- Export setters as plain named functions at the module top level.
- Return only `computed` refs from `useXStore()`.
- Declare storage keys as local string constants at the call site (flat dot-namespace).
- For SSR projects, use `registerHydration` (the `hydration` skill) instead of reading
  storage at declaration time.

❌ don't:
- Use `defineStore`, `createPinia`, or any Pinia API.
- Return the raw `state` object or a setter from `useXStore()`.
- Read `localStorage` directly — always use the `persistence` skill by name.
- Put per-user or per-request data in a module-singleton store when SSR is active.
- Declare feature-scoped state at module level.

## Related skills (by name)

persistence · hydration · tanstack-query · architecture-fsd
