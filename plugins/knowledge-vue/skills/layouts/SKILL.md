---
name: layouts
description: Use when creating or wiring page layouts in a Vue project — adding a layout, registering it in the Layouts enum, or the layout resolver. Default layouts (DefaultLayout + ErrorLayout) are scaffolded with router setup. Routing itself is the `vue-router` skill; route declarations are `pages`.
---

# layouts (Vue)

How page layouts are created, registered, and resolved. Defer to `page-middlewares`
(by name) for the middleware contract and to `vue-router` (by name) for registering
the resolver in `GlobalMiddlewares`.

Read `../../core/placement.md` first (resolve `{layouts}` / `{route-config}`).

## Create a layout
- [invariant · desired] A layout is a component **`<Name>Layout.vue`** in `{layouts}`.
  It renders the page through a default **`<slot/>`** (NOT a `<RouterView>` inside the
  layout). Header / footer / chrome live in the layout.
- [invariant · desired] **Register** every layout in the `Layouts` enum (routing
  config, `{route-config}`), where the enum value EQUALS the file stem — the resolver
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
  **relative to the middleware file**, so it depends on where the middleware and
  `{layouts}` sit (FSD `02-pages/global-middlewares` → `../layouts`; adjust the relative
  path for non-FSD layouts):
  ```ts
  const imports = import.meta.glob('../layouts/*.vue', { import: 'default' })
  export const layoutMiddleware: Middleware = async (to) => {
    to.meta.layout.component = (await imports[`../layouts/${to.meta.layout.type}.vue`]()) as Component
  }
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
  in `GlobalMiddlewares`). The catch-all / 404 route uses `ErrorLayout`
  (`isError404: true`).
