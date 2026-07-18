---
name: vue-router
description: Use when setting up or configuring vue-router in a Vue project — installing it, registering the router, wiring middlewares into navigation. One-time setup. Creating individual routes/pages is the `pages` skill; authoring a single middleware is the `page-middlewares` skill.
---

# vue-router (Vue) — router setup

One-time router setup: install, register, and wire the middleware runner. Defer to
`plugin-registration` (by name) for the factory-file discipline, and to
`page-middlewares` (by name) for authoring individual middlewares. Adding routes is
the `pages` skill.

Read `../../core/disciplines/routing-discipline.md` first (route-by-name + the shared
`fallbackRoute`).
- [invariant · desired] This skill applies under runtime = vite-vue; under Nuxt, routing/pages/layouts/middleware are Nuxt-owned (file-based) — see core/runtimes/nuxt.md.

Read `../../core/placement.md` first for the `{plugins}` / `{pages-config}` /
`{global-middlewares}` tokens; paths resolve in the active architecture doc.

## 1. Install + register
- `yarn add vue-router`.
- [invariant · desired] Register through the `plugin-registration` skill: a factory
  `createRouter(options)` in `{plugins}/router.ts` (alias the library import as
  `createRouterMaster` to avoid the name clash). The factory builds the router, wires
  middlewares (§2), and returns it.
- [invariant · desired] History mode is chosen at **runtime** from an SSR flag:
  `createMemoryHistory()` when SSR, else `createWebHistory(import.meta.env.BASE_URL)`.
- [invariant · desired] Augment `RouteMeta` via `declare module 'vue-router'`,
  colocated in the router plugin file.

```ts
// {plugins}/router.ts
import { createRouter as createRouterMaster, createMemoryHistory, createWebHistory } from 'vue-router'
import { routes } from '{routes}'
import { GlobalMiddlewares, fallbackRoute } from '{pages-config}'  // array + fallbackRoute (routing-discipline); middleware impls live in {global-middlewares}

export function createRouter(options: { ssr?: boolean }) {
  const router = createRouterMaster({
    history: options.ssr ? createMemoryHistory() : createWebHistory(import.meta.env.BASE_URL),
    routes
  })
  wireMiddlewares(router)
  return router
}
```

## 2. Middleware wiring (one runner, ordered chain)
- [invariant · desired] Wire middlewares with **one** `router.beforeEach` that runs an
  ordered async chain `[...GlobalMiddlewares, ...(to.meta.middleware ?? [])]`. (Authoring
  a middleware is `page-middlewares`; this is only the runner.)
```ts
function wireMiddlewares(router: Router) {
  router.beforeEach(async (to, from, next) => {
    for (const middleware of [...GlobalMiddlewares, ...(to.meta.middleware ?? [])]) {
      const result = await middleware(to, from)
      if (typeof result === 'object') return next(result)   // redirect (by name)
      if (result === false) return next(fallbackRoute)       // shared fallback
    }
    return next()
  })
}
```
- [invariant · desired] **Global middlewares** are a static, ordered array
  (`GlobalMiddlewares`) in `{pages-config}` (impl files in `{global-middlewares}`). **Order
  matters**: `handle404` runs **first** (it fills empty meta for unmatched URLs — see the
  implicit-404 mechanism in `layouts`), THEN the layout-resolver middleware (§3), then
  always-on guards (e.g. the modal-close middleware) — e.g.
  `[handle404Middleware, layoutMiddleware, closeModalsMiddleware]`. The global-vs-per-route
  middleware tiers themselves are described in `page-middlewares`.
- [preference · desired] (SSR) call `createRouter({ ssr: true })` **per request** — never
  share one router instance across requests, or state leaks between users.

## 3. Layouts
- [invariant · desired] Layout creation, the `Layouts` enum, the resolver middleware,
  and the default `DefaultLayout` / `ErrorLayout` scaffold are the **`layouts` skill**'s
  concern (defer by name). Router setup registers the layout resolver in
  `GlobalMiddlewares` and triggers the default-layout scaffold.

## History mode and crawlability

- [invariant · desired] For INDEXABLE routes, use the History API (`createWebHistory`),
  NOT hash routing — search engines and AI crawlers cannot reliably resolve hash
  fragments to indexable URLs. A non-indexable context (e.g. a browser extension that
  requires hash history) is explicitly fine. Defer crawlability principles to the
  `javascript-seo` skill (knowledge-seo) by name.

## Placement (tokens)
- [invariant · desired] Router factory → `{plugins}/router.ts`.
- [invariant · desired] `GlobalMiddlewares` array → `{pages-config}`.
- [invariant · desired] Global middleware impl files (incl. the layout middleware) →
  `{global-middlewares}/<name>.middleware.ts`.
