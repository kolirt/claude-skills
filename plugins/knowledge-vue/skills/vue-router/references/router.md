# vue-router — router factory etalon

Full-file etalon for the router setup: `createRouter` factory, SSR history-mode branch, and the single `beforeEach` middleware runner. Route declarations and middleware authoring are owned by the `pages` and `page-middlewares` skills (only imported here, tokenised); middlewares and the router bounce via `FALLBACK_ROUTE`, never a hardcoded route name.

`{pages-config}` and `{shared-config}` barrels are not reproduced here — they ship with the `page-middlewares` and `pages` skills' etalons respectively. On a flat `src/` (non-FSD), these paths resolve unchanged.

## Files

- `{plugins}/router.ts`
- `{pages-config}/fallbackRoute.ts`

**File:** `{plugins}/router.ts`
```ts
import type { Component } from 'vue'
import { type Router, createMemoryHistory, createRouter as createRouterMaster, createWebHistory } from 'vue-router'

import { routes } from '{routes}'
import { GLOBAL_MIDDLEWARES, Layouts, FALLBACK_ROUTE } from '{pages-config}'
import type { Middleware } from '{pages-types}'

declare module 'vue-router' {
  interface RouteMeta {
    layout: {
      type: Layouts
      component: null | Component
      isError404: boolean
    }
    middleware: Middleware[]
    ssr?: boolean
  }
}

function createMiddleware(router: Router) {
  router.beforeEach(async (to, from, next) => {
    const middlewares = [...GLOBAL_MIDDLEWARES, ...((to.meta.middleware ?? []) as Middleware[])]

    for (const middleware of middlewares) {
      const value = await middleware(to, from)

      if (typeof value === 'object') return next(value)

      if (value === false) return next(FALLBACK_ROUTE)
    }

    return next()
  })
}

export function createRouter({ ssr = false }: { ssr?: boolean } = {}) {
  const router = createRouterMaster({
    history: ssr ? createMemoryHistory() : createWebHistory(import.meta.env.BASE_URL),
    linkActiveClass: 'is-active',
    linkExactActiveClass: 'is-exact-active',
    routes
  })

  createMiddleware(router)

  return router
}
```

**File:** `{pages-config}/fallbackRoute.ts`
```ts
import { RouteNames } from '{shared-config}'

export const FALLBACK_ROUTE = { name: RouteNames.Home }
```
