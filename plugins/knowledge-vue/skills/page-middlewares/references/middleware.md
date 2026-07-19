# page-middlewares — middleware etalon

Full-file etalon for authoring middlewares: two per-route guards (`auth`,
`guest`), two global middlewares (`handle404`, `closeModals`), the
`GLOBAL_MIDDLEWARES` array, and their barrels. Router wiring is owned by
`vue-router`, not reproduced here. `{global-middlewares}/layout.middleware.ts`
is owned by the `layouts` skill's `layouts.md`; `{pages-types}`
(`Middleware`/`Route`) by the `pages` skill's `routes.md`;
`{pages-config}/fallbackRoute.ts` by `vue-router`'s `router.md` — none are
reproduced here, only token-imported. Owned-file re-exports (e.g.
`layout.middleware`) must use the token form, never a relative import.

## Files

- `{pages-config}/globalMiddlewares.ts`
- `{pages-config}/index.ts`
- `{global-middlewares}/index.ts`
- `{global-middlewares}/closeModals.middleware.ts`
- `{global-middlewares}/handle404.middleware.ts`
- `{middlewares}/index.ts`
- `{middlewares}/auth.middleware.ts`
- `{middlewares}/guest.middleware.ts`

**File:** `{pages-config}/globalMiddlewares.ts`
```ts
import { closeModalsMiddleware, handle404Middleware, layoutMiddleware } from '{global-middlewares}'

export const GLOBAL_MIDDLEWARES = [handle404Middleware, layoutMiddleware, closeModalsMiddleware]
```

**File:** `{pages-config}/index.ts`
```ts
export { Layouts } from '{pages-config}/layouts'
export { GLOBAL_MIDDLEWARES } from './globalMiddlewares'
export { FALLBACK_ROUTE } from '{pages-config}/fallbackRoute'
```

**File:** `{global-middlewares}/index.ts`
```ts
export { middleware as closeModalsMiddleware } from './closeModals.middleware'
export { middleware as handle404Middleware } from './handle404.middleware'
export { middleware as layoutMiddleware } from '{global-middlewares}/layout.middleware'
```

**File:** `{global-middlewares}/closeModals.middleware.ts`
```ts
import { closeAllModals, isOpened } from '@kolirt/vue-modal'

import type { Middleware } from '{pages-types}'

const middleware: Middleware = async function () {
  if (isOpened.value) {
    await closeAllModals({ ignoreGuard: true, instantExit: true })
  }
}

export { middleware }
```

**File:** `{global-middlewares}/handle404.middleware.ts`
```ts
import type { Middleware } from '{pages-types}'
import { getDefaultMeta } from '{pages-utils}'

const middleware: Middleware = async function (to) {
  if (!Object.keys(to.meta).length) to.meta = getDefaultMeta()
}

export { middleware }
```

**File:** `{middlewares}/index.ts`
```ts
export { middleware as authMiddleware } from './auth.middleware'
export { middleware as guestMiddleware } from './guest.middleware'
```

**File:** `{middlewares}/auth.middleware.ts`
```ts
import { Views, open } from '{widget}/sidebar'

import { useSessionStore } from '{entity}/session'

import { FALLBACK_ROUTE } from '{pages-config}'
import type { Middleware } from '{pages-types}'

const middleware: Middleware = function () {
  const { isAuthenticated } = useSessionStore()

  if (!isAuthenticated.value) {
    // client-only: `open` mutates the module-level sidebar widget state, which under
    // SSR is shared across concurrent requests — opening it here would leak into
    // other visitors' responses. The redirect below still bounces the server-side visitor.
    if (!import.meta.env.SSR) open(Views.Login)
    return FALLBACK_ROUTE
  }
}

export { middleware }
```

**File:** `{middlewares}/guest.middleware.ts`
```ts
import { useSessionStore } from '{entity}/session'

import { FALLBACK_ROUTE } from '{pages-config}'
import type { Middleware } from '{pages-types}'

const middleware: Middleware = function () {
  const { isAuthenticated } = useSessionStore()

  if (isAuthenticated.value) {
    return FALLBACK_ROUTE
  }
}

export { middleware }
```
