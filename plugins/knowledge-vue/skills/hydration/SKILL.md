---
name: hydration
description: Use when fixing browser-only state (localStorage-backed, navigator.*, etc.) that cannot be read on the server and must be restored on the client after SSR — registering hydration callbacks and wiring the single runHydrations() call. SSR projects only.
---

# hydration (Vue) — fix browser-only state after mount (SSR projects only)

**If the project has no SSR, this skill is not needed.** Read browser values directly at
module-level initialisation time (see the `stores` skill for the no-SSR branch).

Read `../../core/placement.md` first (resolve `{shared-lib}`, `{app}`).

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

```ts
// {shared-lib}/hydration/index.ts
type HydrationFn = () => void

const registry = new Map<string, HydrationFn>()
let ran = false

export function registerHydration(name: string, fn: HydrationFn): void {
  if (import.meta.env.SSR) return
  if (ran) {
    fn()   // late registrant — run immediately
    return
  }
  registry.set(name, fn)
}

export function runHydrations(): void {
  if (import.meta.env.SSR) return
  registry.forEach((fn) => fn())
  registry.clear()
  ran = true
}
```

## Wiring `runHydrations()` in the root component

```vue
<!-- {app}/App.vue (or the root layout component that wraps <Suspense>) -->
<template>
  <Suspense @resolve="onReady">
    <RouterView />
  </Suspense>
</template>

<script setup lang="ts">
import { runHydrations } from '{shared-lib}/hydration'

function onReady() {
  runHydrations()
}
</script>
```

## Registering a hydration callback in a store

```ts
// {entity}/model/store/index.ts  (SSR project)
import { reactive } from 'vue'
import { get } from '{shared-lib}/local-persistence'
import { registerHydration } from '{shared-lib}/hydration'
import { STORAGE_KEYS } from './keys'

const state = reactive({ authenticated: false })

registerHydration('session', () => {
  state.authenticated = get(STORAGE_KEYS.session.authenticated, false)
})
```

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

stores · ssr
