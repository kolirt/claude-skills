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

Read `references/plugin.md` and reproduce it — it holds the complete files for a
representative plugin factory and both barrels: the `{plugins}` barrel and the
`{initial-plugins}` barrel. The etalon shows the trivial, shareable factory shape
(`validationKit.ts`, no options); it does not duplicate the modal/router/query module
internals owned by their own skills. `{initial-plugins}/httpRequest.ts` — the imperative
bootstrap initialiser the `{initial-plugins}` barrel re-exports — is **not** reproduced
here either; it is owned by the `http-request` skill's `http-request-module.md` etalon.
The project-type-specific, SSR-aware factory (`head.ts`, taking `{ ssr }` and returning
a fresh per-request instance) is **not** reproduced here — it lives in the active
project type's own bootstrap etalon instead: `core/references/bootstrap-csr.md` or
`core/references/bootstrap-ssr.md` (see the `csr` / `ssr` docs under
`core/project-types/`). The `createApp` composition point and every bootstrap/entry
file are likewise owned by those etalons, not this one — they differ between CSR and
SSR (sync vs async, `createApp` vs `createSSRApp`, one entry file vs two).

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
  projects: `createApp()`, sync, no options), living in `{initial-plugins}`, calls
  each factory and `app.use`s them in order, then returns the app plus any instances
  the caller needs (e.g. a router or head client used outside of `app.use`). Its
  concrete shape is owned by the active project type's etalon (`core/references/
  bootstrap-csr.md` / `bootstrap-ssr.md`), not restated here — see `## Files` above.

- [invariant · desired] **Bootstrap roots are dumb.** A bootstrap root calls only
  `createApp(...)` plus the imperative bootstrap initialisers exported from
  `{initial-plugins}` (e.g. wiring the http-request client to the query client) and the
  mount call — it never builds, configures, or `app.use`s anything itself. `{plugins}/index.ts`
  is a pure barrel (re-exports only, no logic).
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

The head/unhead integration is the clearest example of "fresh-vs-shared" in practice.
On SSR, `createHead` takes `{ ssr }`, picks the server or client build of `@unhead/vue`
accordingly, and returns a fresh instance per call; the app factory registers it exactly
like any other plugin (`app.use(await createHead({ ssr }))`) and never builds a bare
config blob ad-hoc inside a bootstrap root. On CSR there is no server build to pick
between, so `createHead()` takes no options and resolves synchronously — see
`core/project-types/csr.md`.

## Related skills (by name)

vue-router · modals · project-init
