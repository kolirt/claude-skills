# Routing discipline (Vue) — cross-cutting invariants

Applies to ALL routing work — navigation, links, redirects, middlewares, and route
definitions. Referenced by the routing skills (`vue-router`, `pages`,
`page-middlewares`).

- [invariant · desired] Routes are referenced **by name**, never by raw path. Use
  `{ name: RouteNames.X }` (plus `params` / `query` as needed), never a path string.
  - ✅ do: `router.push({ name: RouteNames.Products })`;
    `<RouterLink :to="{ name: RouteNames.Products }">`
  - ❌ don't: `router.push('/products')`; `<RouterLink to="/products">` — why: names survive path refactors and are enum-checked; raw paths break silently.

- [invariant · desired] There is a single, configurable **fallback route**
  (`fallbackRoute`) declared in **`{pages-config}`** (page-layer config, alongside
  `Layouts` and the `GlobalMiddlewares` array) — never hard-coded inside a middleware
  and never in `{routes}/index.ts`. The middleware runner and any "denied → redirect"
  use this constant, so the fallback target changes in exactly one place.
  - ✅ do: `export const fallbackRoute = { name: RouteNames.Home }` in `{pages-config}`;
    middlewares `return fallbackRoute` to bounce.
  - ❌ don't: declare `fallbackRoute` in `{routes}/index.ts`; `return next({ name: RouteNames.Home })` hard-coded in each middleware.

- [invariant · desired] **404 is implicit — never declare a catch-all `*` / `:pathMatch(.*)*`
  route and never create a `NotFoundPage`.** An unmatched URL is detected by a global
  `handle404` middleware that assigns `getDefaultMeta()` (which defaults `layout` to
  `Layouts.Error` with `isError404: true`); the layout middleware then renders `ErrorLayout`,
  which self-renders the 404. The mechanism lives in the `layouts` skill.
  - ✅ do: let an unmatched route fall through to `handle404` → `ErrorLayout`.
  - ❌ don't: add `page(':pathMatch(.*)*', RouteNames.NotFound, …)` or a dedicated 404 page route.
