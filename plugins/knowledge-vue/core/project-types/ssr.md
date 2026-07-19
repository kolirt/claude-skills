# SSR bootstrap (Vue) — server-rendered project type

Read `../placement.md` first for the `{app}`, `{initial-plugins}`, `{plugins}` tokens;
paths resolve in the active architecture doc.

This doc owns the **SSR bootstrap process**: the per-request app factory, the two
bootstrap roles, selective rendering, and the server/client hand-off. It applies only
to a project whose type was decided as SSR (see `project-init`). The CSR carve-out
lives in the sibling `csr.md`.

Read `../references/bootstrap-ssr.md` and reproduce it — it holds the complete
`index.html` (with its SSR placeholder comments), the per-request
`{initial-plugins}/createApp.ts` factory, the `entryClient.ts` / `entryServer.ts`
entry files, and the server bootstrap (`server/index.ts`, `server/tsconfig.json`,
`server/render.ts` — the template-fill handler that turns a `render()` result into
a response).

## The per-request factory

Vue SSR requires a **per-request app factory** in `{initial-plugins}`: every incoming
request gets a fresh, isolated `app`, `router`, `queryClient`, and `head`. A
module-level singleton **holding per-request or per-user data** anywhere in the
factory's import graph is a race condition — parallel requests share the same Node
process and will read/overwrite each other's state. This does not ban module-level
state as such: a module-reactive store scoped to CSR-only UI concerns (see the
`stores` skill) is fine precisely because it never carries per-request data on the
server — it stays at its default value for every request and is only meaningful
after client hydration.

- [invariant · desired] The factory is composed from the plugin factories in
  `{plugins}` (e.g. `createRouter`, `createVueQuery`, `createHead`) and registered via
  `app.use(...)` — never an inline `new QueryClient()` or similar ad-hoc instance
  built inside the factory.
- [invariant · desired] The client bootstrap (`entryClient.ts`) **always** creates
  the app with `createSSRApp`, never Vue's plain `createApp` — even though `ssr`
  is `false` on the client, the app must still **hydrate** the server-rendered
  markup rather than mount fresh over it. Branching between `createSSRApp` and
  `createApp` on `ssr` would break hydration. Plain `createApp` belongs to CSR
  only (see `csr.md`) — an SSR project never uses it.

  ```ts
  // ✅ {initial-plugins}/createApp.ts — fresh instances on every request
  export async function createApp({ ssr }: { ssr: boolean }) {
    const app = createSSRApp(Root)                   // always createSSRApp — SSR hydrates, never mounts fresh
    const router = createRouter({ ssr })
    const vueQuery = createVueQuery({ ssr })          // plugin factory from {plugins}
    const head = await createHead({ ssr })            // plugin factory from {plugins}
    app.use(router).use(vueQuery).use(head)           // register via the plugin factories
    return { app, router, queryClient: vueQuery.queryClient, head }
  }

  // ❌ module-level singleton — leaks across parallel requests
  const queryClient = new QueryClient()
  export async function createApp({ ssr }: { ssr: boolean }) { … }
  ```

- [invariant · desired] **SSR guards**: nothing in the `createApp` import graph may
  access `window`, `document`, `localStorage`, or `BroadcastChannel` at **module
  top-level**. Defer browser-only reads via `registerHydration` (see the `hydration`
  skill) or guard inline with `if (!import.meta.env.SSR)`.

## Two bootstrap roles

`{app}` holds exactly **two** bootstrap roles, identified by what they do, not by
name (recommended default names: `entryClient.ts` / `entryServer.ts`, camelCase):

- **Client bootstrap** — runs in the browser: mounts the app, wires client-only
  handlers, and reconciles hydration state.
- **Server bootstrap** — runs per-request on the server: renders the app (or a CSR
  shell), derives the HTTP status, and serializes state for hand-off to the client.

Both import `createApp` (and any imperative initialisers) from `{initial-plugins}`;
the factory itself is never inlined into either bootstrap file.

### Server bootstrap — ordered sequence

1. Call `createApp({ ssr: true })` — per-request factory; no module-level singleton in its
   import graph may hold per-request or per-user data.
2. Register a top-level error handler that catches `abort(statusCode)` signals thrown
   during route guards or prefetch.
3. `await router.push(url)` → `await router.isReady()`.
4. [invariant · desired] **404 status**: check BOTH shapes on the resolved route, because a
   project may use either. `matched.length === 0` catches an unmatched URL in a project with
   no catch-all route; `meta.layout?.isError404` catches the project that DOES declare a
   catch-all — there the catch-all matches, so `matched.length` is 1 and the first check alone
   would answer 200 for a page rendering the 404 screen. Either condition → respond with a real
   **404**. Returning 200 for an unmatched URL (soft-404) is a defect.
5. [invariant · desired] **Selective SSR**: check `to.meta.ssr`. When
   `to.meta.ssr !== true`, return a CSR shell (empty HTML document, `ssr: false`) so
   the browser completes the render as a SPA; only call `renderToString(app)` when
   `to.meta.ssr === true`. A declared `meta.ssr` that is never read is a defect.
6. `await renderToString(app)` (SSR routes only).
7. [invariant · desired] **State injection**: `dehydrate(queryClient)`, then serialize
   into the HTML as `window.__INITIAL_STATE__`, escaping every `<` as the JSON
   unicode escape `\u003c` (which JSON parses back to `<` unchanged, so the payload
   is identical) before it is written into the inline `<script>`. See
   `../references/bootstrap-ssr.md` (`server/render.ts`) for the complete escaping code.

   An unescaped `<` inside the serialized data lets a literal `</script>` sequence
   terminate the inline script tag early and inject markup after it. Swapping `<` for
   its HTML entity (`&lt;`) or any other cosmetic replacement does NOT satisfy this —
   the payload must remain valid JSON that a browser's HTML parser cannot mistake for
   a tag boundary, and `\u003c` is the only substitution that does both.
8. `head.render()` → head tags string.
9. Return `{ html, state, headPayload }` to the server adapter.

### Client bootstrap — ordered sequence

1. Call `createApp({ ssr: false })`.
2. Init client-only handlers: unauthorized/notification listeners via an
   `initHttpRequest(queryClient)` initialiser imported from `{initial-plugins}`,
   `BroadcastChannel` setup, etc. — none of this runs on the server.
3. [invariant · desired] **Hydration order**: the query-state hand-off
   (`hydrate(queryClient, window.__INITIAL_STATE__)`) happens **before**
   `app.mount()`. This reconcile is owned by the query plugin (its own
   factory/initialiser), not inlined into `entryClient.ts` — the bootstrap
   root never declares `Window.__INITIAL_STATE__` or calls `hydrate` itself.
   See the `tanstack-query` skill for where this lives.
4. `await router.isReady()`.
5. `app.mount('#app')`.
6. Root component `<Suspense @resolve>` fires → `runHydrations()` — **after** mount.
   The `hydration` skill owns `runHydrations`; do not inline its logic here.

- [invariant · desired] `<ClientOnly>` wraps DOM-portal targets (modal mount point,
  toast mount point) specifically — it is **not** a general SSR escape hatch. Using
  it to hide arbitrary components defeats SSR parity.

## Head management

The head integration is a **plugin factory** in `{plugins}` — `createHead({ ssr })`
dynamically imports the server or client `unhead` build and returns the instance. The
factory in `{initial-plugins}` calls `await createHead({ ssr })` and registers the
result via `app.use(head)` like any other plugin. Call `head.render()` in the server
bootstrap after `renderToString` completes. See the `plugin-registration` skill for
the canonical factory pattern.

## HTTP semantics — cross-links to knowledge-seo

- A page that fails to match a route must return a **real HTTP 404**, not a 200
  response with a client-rendered error UI. This "no soft-404" principle lives in the
  **`canonicalization-and-redirects`** skill.
- Initial HTML content must match the hydrated DOM. The principle lives in the
  **`javascript-seo`** skill.

## Mode-aware build

See the **`project-init`** skill for the `build:dev` / `build:prod` scripts that pass
`--mode development|production` into both SSR bundles (client and server). The server-bootstrap
compile itself is mode-agnostic — a plain `tsc --project server/tsconfig.json` — and takes no
`--mode` flag.

## Related skills (by name)

hydration · stores · seo · tanstack-query
