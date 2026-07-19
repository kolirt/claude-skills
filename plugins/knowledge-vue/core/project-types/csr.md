# CSR bootstrap (Vue) — client-only project type

Read `../placement.md` first for the `{app}`, `{initial-plugins}`, `{plugins}` tokens;
paths resolve in the active architecture doc.

Read `../references/bootstrap-csr.md` and reproduce it — it holds the complete
`index.html`, the sync `{initial-plugins}/createApp.ts` factory, and the single
`{app}/main.ts` bootstrap root. That etalon is the SSR bootstrap reduced to its
client half; there is no independent CSR reference project.

This doc owns the **CSR bootstrap process** for a project whose type was decided as
CSR/SPA (see `project-init`) — the carve-out against `ssr.md`. Every other convention
(FSD, stores, http-request, TanStack, modals) works the same regardless of project
type; only the bootstrap differs.

## The app factory

`{initial-plugins}` still holds a single `createApp()` factory, composed from the
same plugin factories in `{plugins}` (e.g. `createRouter`, `createVueQuery`,
`createHead`), registered via `app.use(...)`, never an inline `new QueryClient()`
or similar ad-hoc instance. Unlike SSR, this factory is fully **synchronous**:

```ts
// ✅ {initial-plugins}/createApp.ts
export function createApp() {
  const app = _createApp(Root)                      // Vue's createApp, never createSSRApp
  const router = createRouter()                     // plugin factory from {plugins}
  const vueQuery = createVueQuery()                  // plugin factory from {plugins}
  const head = createHead()                          // plugin factory from {plugins} — sync here
  app.use(router).use(vueQuery).use(head)
  return { app, router, queryClient: vueQuery.queryClient, head }
}
```

- [invariant · desired] `createApp()` takes **no options at all** — there is no
  server render path, so there is nothing for it to branch on, and `createSSRApp`
  is never used; CSR uses Vue's own `createApp`.
- [invariant · desired] `createHead()` is called **synchronously, with no
  arguments**, and `createApp()` itself is **sync** — CSR never needs the async,
  `{ ssr }`-branching `createHead` shape that SSR's per-request factory uses (see
  `plugin-registration` for that contrast). A CSR project's `createHead` may import
  the client `unhead` build directly at module scope instead of dynamically
  switching on `ssr`.
- See `../references/bootstrap-csr.md` for the complete `createApp.ts` to
  reproduce — this etalon is owned here, not by `plugin-registration` (whose
  etalon only shows the `{plugins}` factories/barrel this file imports).

## A single bootstrap root

`{app}` holds exactly **one** bootstrap role (recommended default name `main.ts`),
identified by behaviour: it calls `createApp()`, registers client-only handlers via
`initHttpRequest(queryClient)`, awaits `router.isReady()`, then `mount`s.

- [invariant · desired] There is no server bootstrap counterpart. A CSR project never
  has a second entry file that renders on the server. See `../references/bootstrap-csr.md`
  for the complete `main.ts`.

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

The head integration is still a **plugin factory** in `{plugins}` — `createHead()`
returns the client `unhead` instance synchronously, with no arguments. The app
factory calls it directly (no `await`) and registers the result via `app.use(head)`
like any other plugin. See the `plugin-registration` skill for the canonical
fresh-vs-shared factory pattern (illustrated there with the SSR-aware shape).

## Related skills (by name)

hydration · stores · seo · tanstack-query
