---
name: pages
description: Use when creating a page or a route in a Vue project — adding a route, a page component, or a redirect. Covers the route-declaration conventions only; installing/configuring vue-router is the `vue-router` skill, authoring a middleware is `page-middlewares`.
---

# pages (Vue) — create a page / route

How to declare routes and pages. This skill assumes the router is already set up
(`vue-router` skill). If a route needs a middleware, author it via `page-middlewares`
and attach it through `meta.middleware`.

Read `../../core/disciplines/routing-discipline.md` first (route-by-name + `fallbackRoute`).
Read `../../core/placement.md` first (resolve `{routes}` / `{pages-utils}` / `{pages-types}` /
`{pages-config}` / `{shared-config}` / `{pages-ui}`).

## Rules

- [invariant · desired] Route records are **never written by hand** — always via the
  builders `page()`, `group()`, `redirect()`.
- [invariant · desired] All page components are **lazy**: `() => import(...)` — never eager.
- [invariant · desired] Every route has a **dedicated page component**, named
  `<Name>Page.vue` (PascalCase + the `Page` suffix — e.g. `HomePage.vue`,
  `ProductsPage.vue`), placed in `{pages-ui}`. The route's lazy `component` imports it.
- [invariant · desired] Route names come from the **`RouteNames` enum** in
  `{shared-config}`, never inline strings (enforced by the builder types).
- [invariant · desired] `meta` is **always fully shaped** (`layout`, `middleware`,
  `ssr?`); the builders guarantee it — never a route with a missing `meta`.
- [invariant · desired] Layout is an **enum value** (`Layouts.X` in `{pages-config}`),
  not a component reference; the layout component is resolved by the global layout
  middleware (see `vue-router`).
- [invariant · desired] Routes are **split by domain**: one `{routes}/<domain>.ts` per
  domain, composed in `{routes}/index.ts` with spread:
  `export const routes = [...defaultRoutes, ...blogRoutes]`. The shared `fallbackRoute`
  (routing-discipline) is declared here too.
- [invariant · desired] A public page is NOT "done" until its baseline SEO is closed:
  title, description, canonical, OG, `twitter:card`, viewport, `meta.ssr`, and a
  `BreadcrumbList` (emitted via `useJsonLd`; the type is owned by the `structured-data`
  skill) if the page is deeper than home — all via the `seo` delivery skill. Private /
  dashboard pages → `noindex`. Defer the principles to the `knowledge-seo` skills by
  name (`meta-tags`, `social-preview`, `structured-data`); the `seo` skill is the Vue
  delivery layer.
  - ✅ DO apply baseline SEO to every public page component before marking it done.
  - ❌ DON'T ship a public page without baseline SEO — a page shipped without it is a
    defect a human SEO specialist would otherwise have to flag.

## Builders (live in `{pages-utils}`)

One builder per file (`page.ts`, `group.ts`, `redirect.ts`, plus `getDefaultMeta` in
`meta.ts`); `{pages-utils}/index.ts` is a barrel that re-exports each by name. The `Route`
and `Middleware` types they reference come from `{pages-types}` (`02-pages/types.ts`) — never
from any `config/`.

```ts
// page(): name is RouteNames-constrained; meta is fully reset (no leftover error fields);
//         metaOverrides deep-merges layout instead of replacing it.
export function page(
  path: string,
  name: RouteNames,
  component: () => Promise<Component>,
  metaOverrides: Partial<RouteMeta> = {}
): Route {
  const meta: RouteMeta = {
    layout: { type: Layouts.Default, component: null, isError404: false },
    middleware: []
  }
  const { layout, ...rest } = metaOverrides
  Object.assign(meta, rest)
  if (layout) Object.assign(meta.layout, layout)
  return { path: `/${path}`, name, component, meta }
}

// group(): immutable (no in-place mutation); group middleware is PREPENDED
//          (runs before page middleware — auth guards first).
export function group(
  meta: { prefix?: string; layout: Layouts; middleware?: Middleware[]; ssr?: boolean },
  routes: Route[]
): Route[] {
  return routes.map((route) => ({
    ...route,
    path: meta.prefix ? `/${meta.prefix}${route.path}` : route.path,
    meta: {
      ...route.meta,
      layout: { ...route.meta.layout, type: meta.layout },
      middleware: meta.middleware
        ? [...meta.middleware, ...route.meta.middleware]   // prepend group middleware
        : route.meta.middleware,
      ssr: meta.ssr !== undefined && route.meta.ssr === undefined ? meta.ssr : route.meta.ssr
    }
  }))
}

// redirect(): redirect-by-name builder. Static target, or forward the matched route
//             params (a FUNCTION) for dynamic paths — a static `{ id: ':id' }` would
//             pass the literal string ':id', not the matched value.
export function redirect(
  path: string,
  to: RouteNames,
  forwardParams = false
): RouteRecordRedirect {
  return {
    path: `/${path}`,
    redirect: forwardParams ? (routeTo) => ({ name: to, params: routeTo.params }) : { name: to },
  }
}
```

## Usage

```ts
// {routes}/blog.ts
export default [
  ...group({ layout: Layouts.Default, ssr: true, middleware: [authMiddleware] }, [
    page('blog/:slug', RouteNames.BlogArticle, () => import('{pages-ui}/BlogArticlePage.vue')),
  ]),
  redirect('old-blog/:slug', RouteNames.BlogArticle, true), // forward :slug
]

// {routes}/index.ts — compose domains + declare the shared fallback (routing-discipline)
import blogRoutes from './blog'
import defaultRoutes from './default'
export const routes = [...defaultRoutes, ...blogRoutes]
export const fallbackRoute = { name: RouteNames.Home }
```

## Placement (tokens — resolve via `placement.md`)
- [invariant · desired] Route files → `{routes}/<domain>.ts` + `{routes}/index.ts`.
- [invariant · desired] `RouteNames` enum (cross-layer) → `{shared-config}`.
- [invariant · desired] `Layouts` enum (page-layer) → `{pages-config}`.
- [invariant · desired] Route builders (`page`/`group`/`redirect`/`getDefaultMeta`) →
  `{pages-utils}`, one per file + a barrel `index.ts`.
- [invariant · desired] `Route` / `Middleware` types → `{pages-types}` (`02-pages/types.ts`).
- [invariant · desired] Page components → `{pages-ui}` (e.g. `<domain>/<Name>Page.vue`).
