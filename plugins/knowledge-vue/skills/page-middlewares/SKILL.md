---
name: page-middlewares
description: Use when writing a route/page middleware or guard in a Vue app — a single middleware that runs on navigation (per-route or global). Owns how a middleware is authored; the vue-router skill wires them into the router.
---

# page-middlewares (Vue)

How to author a **single** middleware. Wiring middlewares into the router (the
`beforeEach` runner, the ordered chain) belongs to the `vue-router` skill — defer to
it by name; do not restate it here.

Read `../../core/disciplines/routing-discipline.md` first (route-by-name + the shared
`fallbackRoute`).
Read `../../core/placement.md` first (resolve `{middlewares}` / `{global-middlewares}` /
`{pages-config}` / `{pages-types}`).

## Middleware contract

- [invariant · desired] A middleware is a function `(to, from) => false | void | object`.
  The `Middleware` **type** lives in `{pages-types}` (`02-pages/types.ts`, alongside `Route`)
  — never in any `config/`:
  ```ts
  // {pages-types}
  type Middleware = (
    to: RouteLocationNormalized,
    from: RouteLocationNormalized
  ) => false | void | object | Promise<false | void | object>
  ```
  - **return an object** → it is a route location → redirect there (the runner passes
    it to `next(value)`). Build it **by name**: `return { name: RouteNames.Login }`.
  - **return `false`** → bounce to the shared `fallbackRoute` (the runner handles it;
    do not hard-code the target — see routing-discipline).
  - **return nothing (`void`)** → proceed to the next middleware in the chain.

## Two tiers

- [invariant · desired] **Global middlewares** run on every navigation. Each
  implementation is its own file in `{global-middlewares}`; the static, ordered
  `GlobalMiddlewares` array that lists them lives in `{pages-config}` (e.g.
  `{pages-config}/globalMiddlewares.ts`) and is consumed by the router (see `vue-router`).
- [invariant · desired] **Per-route middlewares** attach to specific routes via
  `meta.middleware: Middleware[]` (set through the `page()` / `group()` helpers — see
  the `pages` skill). They run after the global ones.

## Example — close modals on navigation

The route-cleanup the `modals` skill defers here. A global middleware — one file named
`<name>.middleware.ts`, with a local `middleware` const and a **named** `export { middleware }`:
```ts
// {global-middlewares}/closeModals.middleware.ts
import { closeAllModals, isOpened } from '@kolirt/vue-modal'

import type { Middleware } from '{pages-types}'

const middleware: Middleware = async () => {
  if (isOpened.value) await closeAllModals({ ignoreGuard: true, instantExit: true })
}

export { middleware }
```
The `{global-middlewares}/index.ts` barrel re-exports it under a descriptive alias
(`export { middleware as closeModalsMiddleware } from './closeModals.middleware'`); register
that alias in the `GlobalMiddlewares` array (see `vue-router`).

## Placement (tokens — resolve via `placement.md`)

- [invariant · desired] Per-route middleware impl → `{middlewares}/<name>.middleware.ts`.
- [invariant · desired] Global middleware impl → `{global-middlewares}/<name>.middleware.ts`.
- [invariant · desired] The `GlobalMiddlewares` array → `{pages-config}`.
- [invariant · desired] The `Middleware` type → `{pages-types}` (`02-pages/types.ts`).
