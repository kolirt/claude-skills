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
  (`fallbackRoute`) declared **where the routes list is defined** — never hard-coded
  inside a middleware. The middleware runner and any "denied → redirect" use this
  constant, so the fallback target changes in exactly one place.
  - ✅ do: `export const fallbackRoute = { name: RouteNames.Home }` next to the routes;
    middlewares `return fallbackRoute` to bounce.
  - ❌ don't: `return next({ name: RouteNames.Home })` hard-coded in each middleware.
