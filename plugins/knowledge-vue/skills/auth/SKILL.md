---
name: auth
description: Use when adding authentication/authorization to a Vue project — login, logout, gating auth-only data, and auto-logout on 401. Wires the session store, TanStack Query cache eviction, and the http-request unauthorized handler.
---

# auth (Vue) — authentication / logout / auto-logout

How auth state, login, logout, and 401 auto-logout work. Composes the
`tanstack-query` skill (queries/mutations + cache eviction) and the `http-request`
skill (the 401 hook) — defer to them by name.

Read `../../core/placement.md` first for the `{entity}` / `{plugins}` tokens; paths resolve in the active architecture doc.

## Session store
- [invariant · desired] Auth state lives in a **session store** — the `{entity}` module's
  **entity store** (the entity is `session`); the active architecture doc resolves where
  inside the module it goes — a module-level reactive flag, hydrated from
  `localStorage` on boot. `useSessionStore()` exposes `isAuthenticated` (computed).
  `markAuthenticated()` / `clearAuthenticated()` are standalone exported functions that
  mutate the flag **and** sync `localStorage`.

## Gating vs eviction (two separate concerns)
- [invariant · desired] **Gate** auth-only queries with
  `enabled: computed(() => session.isAuthenticated.value)` (they don't run while logged out).
- [invariant · desired] **Tag** every auth-dependent query with
  `meta: { requiresAuth: true }` (the meta type is declared in the `tanstack-query` setup)
  so it can be **evicted** on logout/401. The predicate lives in the session `{entity}`
  module alongside its **entity query** — the active architecture doc resolves where
  inside the module it goes:
  ```ts
  export function isAuthQuery(query: Query): boolean {
    return query.meta?.requiresAuth === true
  }
  ```

## Login
- [invariant · desired] Login is a `use*Action` mutation (see `tanstack-query`). On
  success: `markAuthenticated()` + `invalidateQueries({ queryKey: sessionKeys.me.queryKey })`
  (refetch the user). *(The specific provider, e.g. Discord, is project-specific; the
  flow is the convention.)*

## Logout
- [invariant · desired] Logout is a `use*Action`. Clean up in **`onSettled`** (runs even
  if the API call fails) so state is always cleared: `clearAuthenticated()` +
  `queryClient.removeQueries({ predicate: isAuthQuery })` — a surgical eviction of all
  `requiresAuth` queries (NOT `queryClient.clear()`; public cache survives).

## Auto-logout on 401
- [invariant · desired] The 401 hook lives in `http-request` (it calls the registered
  unauthorized handler — see that skill). The `auth` setup **registers** that handler
  once at app boot, given the `QueryClient`, and it does **exactly what manual logout
  does**:
  ```ts
  // at app boot, where the QueryClient is available (see tanstack-query setup):
  setUnauthorizedHandler(() => {
    clearAuthenticated()
    queryClient.removeQueries({ predicate: isAuthQuery })
  })
  ```
  So intentional logout and session expiry leave the store + cache in the same state.

## When the developer says "add authorization"
1. Create/ensure the session store (`isAuthenticated`, `mark`/`clearAuthenticated`).
2. Add login + logout `use*Action`s (login → mark + invalidate me; logout → onSettled clear + removeQueries).
3. Tag auth-only queries with `meta.requiresAuth` and gate them with `enabled`.
4. Register the 401 unauthorized handler (auto-logout) at app boot.
