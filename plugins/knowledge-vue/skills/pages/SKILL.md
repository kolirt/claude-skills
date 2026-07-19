---
name: pages
description: Use when creating a page or a route in a Vue project — adding a route, a page component, or a redirect. Covers the route-declaration conventions only; installing/configuring vue-router is the `vue-router` skill, authoring a middleware is `page-middlewares`.
---

# pages (Vue) — create a page / route

How to declare routes and pages. This skill assumes the router is already set up
(`vue-router` skill). If a route needs a middleware, author it via `page-middlewares`
and attach it through `meta.middleware`.

Read `references/routes.md` and reproduce it — it holds the complete files for the
route builders, the route domain records, the routing types and a representative page
component.

Read `../../core/disciplines/routing-discipline.md` first (route-by-name + `FALLBACK_ROUTE`).
- [invariant · desired] This skill applies under runtime = vite-vue; under Nuxt, routing/pages/layouts/middleware are Nuxt-owned (file-based) — see core/runtimes/nuxt.md.

Read `../../core/placement.md` first for the `{routes}` / `{pages-utils}` / `{pages-types}` /
`{pages-config}` / `{shared-config}` / `{pages-ui}` tokens; paths resolve in the active architecture doc.

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
  `export const routes = [...defaultRoutes, ...blogRoutes]`.
- [invariant · desired] Do **NOT** declare a catch-all `*` / `:pathMatch(.*)*` route
  and do **NOT** create a `NotFoundPage` — 404 is handled implicitly by the `handle404`
  global middleware and `ErrorLayout` (see the `layouts` skill).
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
and `Middleware` types they reference come from `{pages-types}` — never
from any `config/`. Full implementations are in `references/routes.md`; reproduce them
as written, not from memory.

- `page()` resets `meta` via `getDefaultMeta()` and forces `layout.type` back to
  `Layouts.Default` **and `layout.isError404` back to `false`**, then merges
  `metaOverrides` on top with a shallow `Object.assign` — passing a partial `layout`
  override replaces the whole `layout` object, it does not merge into it.
- `group()` mutates each route's `path`/`meta` in place (no cloning) and, when
  `middleware` is set, pushes the group's middleware onto the end of each route's
  existing `meta.middleware` array — group middleware therefore runs *after* any
  middleware the route already carried, not before.
- `redirect()` builds a redirect-by-name route record, reusing `getDefaultMeta()` +
  `Layouts.Default` + `isError404: false` the same way `page()` does so it composes
  inside `group()`. Pass
  `forwardParams: true` (a function target) to forward the matched route's params to
  the destination; the default static target does not carry params.
- `getDefaultMeta()` is also the meta the `handle404` global middleware assigns to an
  unmatched route (`Layouts.Error` + `isError404: true`), which is why it defaults to
  the error layout rather than `Layouts.Default` — `page()` and `redirect()` both
  override that default back to `Layouts.Default` for real routes.

## Usage

See `references/routes.md` for the full route-domain files (`{routes}/blog.ts` composing
`page()`, `group()`, and `redirect()`, and `{routes}/index.ts` spreading the per-domain
arrays together).

## Placement (tokens)
- [invariant · desired] Route files → `{routes}/<domain>.ts` + `{routes}/index.ts`.
- [invariant · desired] `RouteNames` enum (cross-layer) → `{shared-config}`.
- [invariant · desired] `Layouts` enum and `FALLBACK_ROUTE` constant (page-layer) → `{pages-config}`.
- [invariant · desired] Route builders (`page`/`group`/`redirect`/`getDefaultMeta`) →
  `{pages-utils}`, one per file + a barrel `index.ts`.
- [invariant · desired] `Route` / `Middleware` types → `{pages-types}`.
- [invariant · desired] Page components → `{pages-ui}` (e.g. `<domain>/<Name>Page.vue`).
