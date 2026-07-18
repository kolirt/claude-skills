---
name: layouts
description: Use when creating or wiring page layouts in a Vue project — adding a layout, registering it in the Layouts enum, or the layout resolver. Default layouts (DefaultLayout + ErrorLayout) are scaffolded with router setup. Routing itself is the `vue-router` skill; route declarations are `pages`.
---

# layouts (Vue)

How page layouts are created, registered, and resolved. Defer to `page-middlewares`
(by name) for the middleware contract and to `vue-router` (by name) for registering
the resolver in `GlobalMiddlewares`.

Read `../../core/placement.md` first for the `{layouts}` / `{pages-config}` /
`{global-middlewares}` / `{pages-types}` tokens; paths resolve in the active architecture doc.
- [invariant · desired] This skill applies under runtime = vite-vue; under Nuxt, routing/pages/layouts/middleware are Nuxt-owned (file-based) — see core/runtimes/nuxt.md.


## Create a layout
- [invariant · desired] A layout is a component **`<Name>Layout.vue`** in `{layouts}`.
  It renders the page through a default **`<slot/>`** (NOT a `<RouterView>` inside the
  layout). Header / footer / chrome live in the layout.
- [invariant · desired] **Register** every layout in the `Layouts` enum (page-layer
  config, `{pages-config}`), where the enum value EQUALS the file stem — the resolver
  globs by it. Creating a layout = create `<Name>Layout.vue` **and** add its `Layouts`
  entry.
  ```ts
  export enum Layouts { Default = 'DefaultLayout', Error = 'ErrorLayout' }
  ```
- [preference · desired] A layout may **extend / reuse another layout** — e.g.
  `ErrorLayout` renders inside `DefaultLayout` to share its shell:
  ```vue
  <!-- ErrorLayout.vue -->
  <template>
    <DefaultLayout><NotFound /></DefaultLayout>
  </template>
  ```

## meta.layout + resolution
- [invariant · desired] `meta.layout` shape (part of the `RouteMeta` augmentation —
  see `vue-router`): `{ type: Layouts; component: null | Component; isError404: boolean }`.
  `type` is set per route (enum), `component` is filled at runtime, `isError404` flags
  error / 404 routes.
- [invariant · desired] A **global layout middleware** resolves the component from the
  enum via `import.meta.glob` and is registered in `GlobalMiddlewares` (see
  `vue-router`); author it per the `page-middlewares` contract. The glob path is
  **relative to the middleware file**, so compute it from where `{global-middlewares}` and
  `{layouts}` resolve in the active architecture doc — the two tokens sit at different
  depths per architecture, so never copy a literal glob between projects.
  Author it per the `page-middlewares` contract — own file
  `{global-middlewares}/layout.middleware.ts`, `Middleware` type from `{pages-types}`, named
  `export { middleware }`, re-exported from the barrel as `layoutMiddleware`:
  ```ts
  // {global-middlewares}/layout.middleware.ts
  import type { Middleware } from '{pages-types}'

  // <rel> = the path from {global-middlewares} to {layouts}, per the active architecture
  // doc — the two tokens sit at different depths per architecture. Both literals below
  // must use the SAME <rel>, or the lookup key will not match a glob entry.
  const imports = import.meta.glob('<rel>/*.vue', { import: 'default' })

  const middleware: Middleware = async (to) => {
    to.meta.layout.component = (await imports[`<rel>/${to.meta.layout.type}.vue`]()) as Component
  }

  export { middleware }
  ```
- [invariant · desired] The app shell renders the resolved layout dynamically around
  `<RouterView>`:
  ```vue
  <component :is="route.meta.layout?.component ?? 'div'">
    <RouterView />
  </component>
  ```

## Default scaffold (triggered by router setup)
- [invariant · desired] On router/layout setup, scaffold **`DefaultLayout`** and
  **`ErrorLayout`**, the `Layouts` enum, and the layout resolver middleware (registered
  in `GlobalMiddlewares`).

## 404 handling — implicit mechanism (no catch-all route)

- [invariant · desired] Do **NOT** declare a catch-all `*` / `:pathMatch(.*)*` route
  and do **NOT** create a `NotFoundPage` route. 404 is handled implicitly:
  1. `getDefaultMeta()` (in `{pages-utils}`) defaults `layout` to `Layouts.Error`
     with `isError404: true`.
  2. A **global `handle404` middleware** (`{global-middlewares}/handle404.middleware.ts`)
     assigns the default meta when a route has empty meta (unmatched URL). Register it
     **first** in the `GlobalMiddlewares` array:
     ```ts
     // {global-middlewares}/handle404.middleware.ts
     import type { Middleware } from '{pages-types}'
     import { getDefaultMeta } from '{pages-utils}'

     const middleware: Middleware = (to) => {
       if (!Object.keys(to.meta).length) to.meta = getDefaultMeta()
     }

     export { middleware }
     ```
  3. The layout middleware resolves the component → `ErrorLayout`, which **self-renders**
     the 404 content. No page component is needed for 404.
