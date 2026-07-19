---
name: page-middlewares
description: Use when writing a route/page middleware or guard in a Vue app — a single middleware that runs on navigation (per-route or global). Owns how a middleware is authored; the vue-router skill wires them into the router.
---

# page-middlewares (Vue)

How to author a **single** middleware. Wiring middlewares into the router (the
`beforeEach` runner, the ordered chain) belongs to the `vue-router` skill — defer to
it by name; do not restate it here.

Read `../../core/disciplines/routing-discipline.md` first (route-by-name + the shared
`FALLBACK_ROUTE`).
- [invariant · desired] This skill applies under runtime = vite-vue; under Nuxt, routing/pages/layouts/middleware are Nuxt-owned (file-based) — see core/runtimes/nuxt.md.

Read `../../core/placement.md` first for the `{middlewares}` / `{global-middlewares}` /
`{pages-config}` / `{pages-types}` tokens; paths resolve in the active architecture doc.

Read `references/middleware.md` and reproduce it, recomputing any line marked
`// @arch-relative` — it holds the complete files for per-route guards, global
middlewares and the `GLOBAL_MIDDLEWARES` array.

## Middleware contract

- [invariant · desired] A middleware is a function `(to, from) => false | void | object`.
  The `Middleware` **type** lives in `{pages-types}` (alongside `Route`)
  — never in any `config/`.
  - **return an object** → it is a route location → redirect there (the runner passes
    it to `next(value)`). Build it **by name**: `return { name: RouteNames.Login }`.
  - **return `false`** → bounce to the shared `FALLBACK_ROUTE` (the runner handles it;
    do not hard-code the target — see routing-discipline).
  - **return nothing (`void`)** → proceed to the next middleware in the chain.

## Two tiers

- [invariant · desired] **Global middlewares** run on every navigation. Each
  implementation is its own file in `{global-middlewares}`; the static, ordered
  `GLOBAL_MIDDLEWARES` array that lists them lives in `{pages-config}` (e.g.
  `{pages-config}/globalMiddlewares.ts`) and is consumed by the router (see `vue-router`).
- [invariant · desired] **Per-route middlewares** attach to specific routes via
  `meta.middleware: Middleware[]` (set through the `page()` / `group()` helpers — see
  the `pages` skill). They run after the global ones.

## Example — close modals on navigation

The route-cleanup the `modals` skill defers here. A global middleware — one file named
`<name>.middleware.ts`, with a local `middleware` const and a **named** `export { middleware }`
(see `closeModals.middleware.ts` in the etalon).
The `{global-middlewares}/index.ts` barrel re-exports it under a descriptive alias
(`export { middleware as closeModalsMiddleware } from './closeModals.middleware'`); register
that alias in the `GLOBAL_MIDDLEWARES` array (see `vue-router`).

## Placement (tokens)

- [invariant · desired] Per-route middleware impl → `{middlewares}/<name>.middleware.ts`.
- [invariant · desired] Global middleware impl → `{global-middlewares}/<name>.middleware.ts`.
- [invariant · desired] The `GLOBAL_MIDDLEWARES` array → `{pages-config}`.
- [invariant · desired] The `Middleware` type → `{pages-types}`.
