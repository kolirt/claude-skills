---
name: ssr
description: Use when setting up or debugging Vue SSR delivery — per-request createApp factory, entryServer/entryClient wiring, selective SSR via meta.ssr, head management with unhead, and SSR guards that prevent module-singleton leaks across parallel requests.
---

# ssr (Vue) — SSR delivery

> **SSR is OPTIONAL.** Use this skill ONLY when the project actually needs server-side
> rendering (e.g. SEO / first-paint for content pages). A CSR/SPA needs none of this — every
> other convention (FSD, stores, http-request, TanStack, modals) works without it; see the
> no-SSR branches in `stores` and `hydration`. Whether a project is SSR or CSR is decided at
> `project-init` (which asks the developer).

Read `../../core/placement.md` first (resolve `{app}`).

Vue SSR requires a **per-request app factory**: every incoming request gets a fresh,
isolated `app`, `router`, `queryClient`, and `head`. Shared module-level singletons
in the factory's import graph cause cross-request state leaks under concurrent load.

## Placement

`{app}` — `entry-server.ts` and `entry-client.ts` live alongside the main `entry.ts`.

## Rules

- [invariant · desired] `createApp` is a **per-request factory**. Always call `createSSRApp`
  (never `createApp`) when `ssr: true`; produce a fresh `app`, `router`, `queryClient`, and
  `head` on every invocation. A module-level singleton in any module the factory imports is a
  race condition — parallel SSR requests share the same Node process and will read/overwrite
  each other's state.

  ```ts
  // ✅ fresh instances on every request
  export async function createApp({ ssr }: { ssr: boolean }) {
    const app = ssr ? createSSRApp(Root) : _createApp(Root)
    const router = createRouter()
    const queryClient = new QueryClient()
    const head = createHead()
    app.use(router).use(VueQueryPlugin, { queryClient }).use(head)
    return { app, router, queryClient, head }
  }

  // ❌ module-level singleton — leaks across parallel requests
  const queryClient = new QueryClient() // shared by all concurrent requests
  export async function createApp({ ssr }: { ssr: boolean }) { … }
  ```

- [invariant · desired] **Client-only wiring runs only in the client entry.**
  - `BroadcastChannel` setup lives under `if (!ssr)` or entirely in `entry-client.ts`.
  - Unauthorized/notification event handlers are registered only in `entry-client.ts`.
  - DOM-portal targets (modal mount point, toast mount point) use `<ClientOnly>` in the
    root component.
  - `<ClientOnly>` is for DOM-portals specifically — it is **not** a general SSR escape
    hatch. Using it to hide arbitrary components defeats SSR parity.

- [invariant · desired] **SSR guards**: nothing in the `createApp` import graph may
  access `window`, `document`, `localStorage`, or `BroadcastChannel` at **module
  top-level**. Defer browser-only reads via `registerHydration` (see the `hydration`
  skill) or guard inline with `if (!import.meta.env.SSR)`.

- [invariant · desired] **Hydration order**: `hydrate(queryClient, window.__INITIAL_STATE__)`
  is called **before** `app.mount()`; `runHydrations()` is called **after** mount, inside
  `<Suspense @resolve>`. The `hydration` skill owns `runHydrations` — do not inline its
  logic here.

- [invariant · desired] **Selective SSR via `meta.ssr`**: each route declares whether it
  is server-rendered through a `meta.ssr` flag, typically set by a
  `group({ ssr: true }, [...])` helper. The server entry inspects this after routing
  completes.

## `entryServer` — ordered sequence

1. `createApp({ ssr: true })` — per-request factory; no module-level singletons.
2. Register a top-level `app.config.errorHandler` that catches `abort(statusCode)` signals
   thrown during route guards or prefetch (e.g. `abort(404)`).
3. `await router.push(url)` → `await router.isReady()`.
4. **No route matched** → return a 404 response (real HTTP status, not a soft-404).
5. **Matched route has no `meta.ssr`** → return a **shell** response (empty HTML document;
   the browser completes the render as CSR).
6. `await renderToString(app)`.
7. `dehydrate(queryClient)` → serialize as `window.__INITIAL_STATE__`.
8. `head.render()` → head tags string.
9. Return `{ html, state, head }` to the server adapter.

## `entryClient` — ordered sequence

1. `createApp({ ssr: false })`.
2. Init client-only handlers: auth/notification listeners, `BroadcastChannel`.
3. `hydrate(queryClient, window.__INITIAL_STATE__)` — **before** `app.mount()`.
4. `await router.isReady()`.
5. `app.mount('#app')`.
6. Root component `<Suspense @resolve>` fires → `runHydrations()` — **after** mount.

## Head management

Use the **async server / client flavour** of `unhead` via `createHead()`. Instantiate
once per request inside the factory, attach to the `app`, and call `head.render()` in
`entryServer` after `renderToString` completes. The server-side `createHead` and the
client-side one are separate named imports from their respective `unhead` entry points.

## HTTP semantics — cross-links to knowledge-seo

The following principles are defined in the **knowledge-seo** plugin and must not be
restated here:

- A page that fails to match a route must return a **real HTTP 404**, not a 200 response
  with a client-rendered error UI. This "no soft-404" principle lives in the
  **`canonicalization-and-redirects`** skill.
- Initial HTML content must match the hydrated DOM. The principle lives in the
  **`javascript-seo`** skill.

## Mode-aware build

See the **`project-init`** skill for the `build:dev` / `build:prod` scripts that pass
`--mode development|production` into both SSR bundles and the server bootstrap compile.

## Related skills (by name)

hydration · stores · seo · tanstack-query · architecture-fsd
