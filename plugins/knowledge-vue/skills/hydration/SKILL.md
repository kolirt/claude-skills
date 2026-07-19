---
name: hydration
description: Use when fixing browser-only state (localStorage-backed, navigator.*, etc.) that cannot be read on the server and must be restored on the client after SSR — registering hydration callbacks and wiring the single runHydrations() call. SSR projects only.
---

# hydration (Vue) — fix browser-only state after mount (SSR projects only)

**Hydration is a sub-concern of SSR, not a standalone mechanism** — `runHydrations()` is wired
into the root component's `<Suspense @resolve>` handler (see the active project-type doc,
`core/project-types/ssr.md`). It exists only because the server rendered a fallback that the
client must reconcile.

**If the project has no SSR, this skill is not needed at all.** With CSR/SPA there is no server
render to reconcile — read browser values directly at module-level initialisation time (see the
`stores` skill's no-SSR branch). Whether a project is SSR or CSR is determined by step 0 of
`vue-work` (`projectType`), detected or asked once and then assumed here.

Read `../../core/placement.md` first for the `{shared-lib}`, `{app}` tokens; paths resolve in the active architecture doc.

Read `references/hydration.md` and reproduce it — it holds the complete files for the
hydration registry only. The store that registers a callback is owned by the `stores`
skill's `store.ssr.md` etalon (see below).

## Why hydration is needed

Under SSR the server renders with default state (no browser APIs). The client receives the
HTML and must restore the real values — values that only exist in the browser
(`localStorage`, `sessionStorage`, `navigator.*`). Doing this restore too late (e.g. after
the first user interaction) causes a flash of wrong state. Doing it inside `onMounted`
scatter the restore logic across every component that needs it. The `hydration` utility
centralises all restores into a single, ordered, synchronous pass.

## Placement

`{shared-lib}/hydration` — a small hand-written utility module, not a package.

## Rules

- [invariant · desired] `registerHydration(name, fn)` is called at **module level** — not
  inside `setup()`, not in a lifecycle hook (`onMounted`, `onServerPrefetch`, …). The store
  module calls it when the module is first evaluated.
- [invariant · desired] The callback `fn` is **synchronous**. No promises, no `await`.
  Values that require async resolution must be prefetched and cached elsewhere before
  hydration runs.
- [invariant · desired] `runHydrations()` is called **exactly once**, in the root app
  component's `<Suspense @resolve>` handler — not in `onMounted`, not in the client entry
  file. This ensures all async setup (SSR data, plugin init) has settled before browser
  values overwrite server defaults.
- [invariant · desired] Both `registerHydration` and `runHydrations` are **no-ops on the
  server** — guarded by `import.meta.env.SSR`. They are safe to import at module level in
  isomorphic code.
- [invariant · desired] A **late registrant** — a `registerHydration` call that arrives after
  `runHydrations()` has already executed — runs its callback immediately (synchronously at
  registration time). This covers lazily loaded chunks that register after the root suspense
  resolves.

## Implementation

The module follows the `{shared-lib}` barrel discipline: `index.ts` re-exports only; the
registry implementation lives in a sibling `registry.ts` — see `references/hydration.md`
for the complete pair of files.

## Wiring `runHydrations()` in the root component

The single call site lives in the root component's `<Suspense @resolve>` handler. That
file is owned by the `layouts` skill (`{app}/App.vue`, wrapping `<RouterView>`); its
etalon (`references/layouts.md`) shows the complete wiring and is not duplicated here.

## Registering a hydration callback in a store

A store registers its callback at module level and reads its persisted value through the
`persistence` skill's wrapper, keyed by a `STORAGE_KEYS` entry declared in a sibling
`keys.ts` file (never an inline string literal at the call site) — see the `stores`
skill's `store.ssr.md` etalon for the complete store file (hydration is SSR-only, so the
SSR variant is the one that applies here).

## Use cases

Values that have a safe server-side default but whose real value is only available in the
browser:
- `localStorage`- or `sessionStorage`-backed store fields (via the `persistence` skill).
- `navigator.language`, `navigator.onLine`, `matchMedia` results.
- Cookie values read via `document.cookie` (when not forwarded to the server).

✅ do:
- Call `registerHydration` once per store module, at module evaluation time.
- Keep the callback synchronous; read storage via the `persistence` skill by name.
- Place `runHydrations()` in exactly one `<Suspense @resolve>` handler in the root component.

❌ don't:
- Call `registerHydration` inside `setup()` or a lifecycle hook.
- Pass an async function as the hydration callback.
- Call `runHydrations()` in `onMounted` or in the client entry file.
- Use this pattern in a non-SSR project — read storage directly at init time instead.

## Related skills (by name)

stores · persistence
