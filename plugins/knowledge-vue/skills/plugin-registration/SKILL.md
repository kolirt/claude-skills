---
name: plugin-registration
description: Use when wiring a Vue plugin into the app (installing + registering a package the developer's way). Owns the developer's plugin-registration discipline; capability skills (e.g. modals, vue-router) defer to it by name instead of restating it.
---

# plugin-registration (Vue)

The developer's discipline for registering ANY Vue plugin (modal, router, toast, …).
Capability skills that install a package defer to THIS skill for registration — they
never restate these steps.

Read `../../core/placement.md` first for the `{plugins}` and `{initial-plugins}`
tokens; paths resolve in the active architecture doc.

## The principle

Four invariants govern every plugin registration, regardless of which package or how
many plugins the project has:

- [invariant · desired] **One factory per package.** Each Vue plugin gets a single
  `create<Name>()` factory function in its own file under `{plugins}/<name>.ts`. All of
  that package's configuration lives inside the factory — nothing leaks out. No inline
  `app.use(Raw, opts)` and no `new X()` call in a bootstrap root.
  - ✅ do:
    ```ts
    // {plugins}/modal.ts
    import { createModal as createModalMaster } from '@kolirt/vue-modal'
    export function createModal() {
      return createModalMaster({ /* package config lives here, not in a bootstrap root */ })
    }
    ```
  - ❌ don't:
    ```ts
    // a bootstrap root
    app.use(createModalMaster({ groups: { /* ... */ } })) // inline config — never
    ```
  - why: the factory file keeps each plugin's wiring/config in one place and keeps
    bootstrap roots a thin list of `app.use(...)` calls.

- [invariant · desired] **Fresh-vs-shared is the only decision a factory makes.** If a
  plugin holds per-request state, its factory takes `{ ssr }` and returns a fresh
  instance — never a module-level singleton reused across requests. If it holds no
  per-request state, the factory returns the same kind of instance every call and
  sharing is safe.

- [invariant · desired] **One composition point.** `createApp({ ssr })` (CSR-only
  projects: `createApp()`), living in `{initial-plugins}`, calls each factory and
  `app.use`s them in order, then returns the app plus any instances the caller needs
  (e.g. a router or head client used outside of `app.use`).

- [invariant · desired] **Bootstrap roots are dumb.** A bootstrap root calls only
  `createApp(...)` — it never builds, configures, or `app.use`s anything itself.
  `{plugins}/index.ts` is a pure barrel (re-exports only, no logic).
  - [anti-pattern · desired] There is NO `installPlugins(app, …)` aggregator function
    and no duplicated build/registration logic between entry points. If more than one
    bootstrap root needs the same app, they both call the same `createApp` — the
    duplication to avoid is in *building* the app, not in calling it.
  - aside: bootstrap roots are commonly named `entryClient`/`entryServer` (SSR) or
    `main.ts` (CSR) as a recommended default — the rule above applies regardless of
    what the file is called.

- [invariant · desired] [runtime: nuxt] → this whole principle is replaced by
  `defineNuxtPlugin` + Nuxt auto-registration; see `core/runtimes/nuxt.md`.

## Head/unhead — canonical illustration

The head/unhead integration is the clearest example of "fresh-vs-shared" in practice:
it needs a different build per environment (server vs client) and, under SSR, a fresh
instance per request.

```ts
// {plugins}/head.ts
import type { VueHeadClient } from '@unhead/vue'
export async function createHead(options: { ssr?: boolean }): Promise<VueHeadClient> {
  const { createHead: createUnhead } = options.ssr
    ? await import('@unhead/vue/server')
    : await import('@unhead/vue/client')
  return createUnhead() as VueHeadClient
}
```

The app factory registers it exactly like any other plugin: `app.use(await createHead({ ssr }))`.
Do NOT export a bare config blob and create the instance ad-hoc inside a bootstrap root.

## Related skills (by name)

vue-router · modals · project-init
