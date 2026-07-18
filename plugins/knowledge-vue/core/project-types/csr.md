# CSR bootstrap (Vue) — client-only project type

Read `../placement.md` first for the `{app}`, `{initial-plugins}`, `{plugins}` tokens;
paths resolve in the active architecture doc.

This doc owns the **CSR bootstrap process** for a project whose type was decided as
CSR/SPA (see `project-init`) — the carve-out against `ssr.md`. Every other convention
(FSD, stores, http-request, TanStack, modals) works the same regardless of project
type; only the bootstrap differs.

## The app factory

`{initial-plugins}` still holds a single `createApp()` factory, composed **exactly
like SSR** — the same plugin factories from `{plugins}` (e.g. `createRouter`,
`createVueQuery`, `createHead`), registered via `app.use(...)`, never an inline
`new QueryClient()` or similar ad-hoc instance:

```ts
// ✅ {initial-plugins}/createApp.ts
export async function createApp() {
  const app = _createApp(Root)
  const router = createRouter()                     // plugin factory from {plugins}
  const vueQuery = createVueQuery()                  // plugin factory from {plugins}
  const head = await createHead({ ssr: false })      // plugin factory from {plugins}
  app.use(router).use(vueQuery).use(head)
  return { app, router, queryClient: vueQuery.queryClient, head }
}
```

- [invariant · desired] `createApp()` takes **no `ssr` parameter of its own** — there
  is no server render path, so there is nothing for `createApp` itself to branch on,
  and `createSSRApp` is never used. It still `await`s the `createHead` plugin factory
  and passes it the fixed CSR value `{ ssr: false }`, because that factory's own
  signature (shared with SSR, see `plugin-registration`) is async and takes an options
  object — that is a property of the plugin factory, not of `createApp`. This makes
  `createApp()` itself `async` even though it has no `ssr` parameter.

## A single bootstrap root

`{app}` holds exactly **one** bootstrap role (recommended default name `main.ts`),
identified by behaviour: it calls `createApp()` and then `mount`, nothing else.

- [invariant · desired] There is no server bootstrap counterpart. A CSR project never
  has a second entry file that renders on the server.

  ```ts
  // ✅ {app}/main.ts — the single bootstrap root
  const { app, router } = await createApp()
  router.isReady().then(() => app.mount('#app'))
  ```

## What CSR does not need

- [invariant · desired] No `dehydrate` / `renderToString` / state-injection step.
  There is no server render, so there is no query-client snapshot to serialize into
  the HTML and no `<`-escaping concern.
- [invariant · desired] No SSR-reconcile hydration path. The SSR `<Suspense @resolve>
  → runHydrations()` sequence exists to replay browser-only reads that a server
  render deferred; CSR has no server render to reconcile against, so browser-only
  state (`localStorage`, `navigator.*`, etc.) is read **directly at init** instead of
  through that reconcile path. See the `hydration` skill for the underlying
  browser-only-state pattern and the `stores` skill for where that state lives.
- No selective-render branching (`meta.ssr`), no server status-code derivation, no
  `<ClientOnly>` SSR-portal escape hatch — none of these have meaning without a
  server render.

## Head management

The head integration is still a **plugin factory** in `{plugins}` —
`createHead({ ssr: false })` returns the client `unhead` instance. The app factory
`await`s it and registers the result via `app.use(head)` like any other plugin, same
as SSR. See the `plugin-registration` skill for the canonical factory pattern.

## Related skills (by name)

hydration · stores · seo · tanstack-query
