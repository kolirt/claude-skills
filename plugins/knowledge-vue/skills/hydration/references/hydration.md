# Hydration registry — full-file etalon

The registry module, split into a pure barrel + its implementation. The entity
store that registers a hydration callback (`{entity}/session/model/store/*`)
is owned by the `stores` skill's `store.ssr.md` etalon (SSR-only), not
reproduced here. The root wiring (`<Suspense @resolve="runHydrations">`) is
owned by the `layouts` skill's `{app}/App.vue` etalon.

Deliberate deviation: the source project keeps this as a flat `index.ts`; this
etalon splits it into `registry.ts` so `index.ts` stays a pure barrel per
`core/placement.md`.

## Files

- `{shared-lib}/hydration/index.ts`
- `{shared-lib}/hydration/registry.ts`

**File:** `{shared-lib}/hydration/index.ts`
```ts
export { registerHydration, runHydrations } from './registry'
```

**File:** `{shared-lib}/hydration/registry.ts`
```ts
type HydrationCallback = () => void

interface QueueEntry {
  name: string
  fn: HydrationCallback
}

const queue: QueueEntry[] = []
let drained = false

function invoke(entry: QueueEntry): void {
  try {
    entry.fn()
  } catch (err) {
    console.error(`[hydration] ${entry.name}`, err)
  }
}

export function registerHydration(name: string, fn: HydrationCallback): void {
  if (import.meta.env.SSR) return
  if (drained) {
    invoke({ name, fn })
    return
  }
  queue.push({ name, fn })
}

export function runHydrations(): void {
  if (import.meta.env.SSR) return
  drained = true
  const entries = queue.splice(0)
  for (const entry of entries) invoke(entry)
}
```
