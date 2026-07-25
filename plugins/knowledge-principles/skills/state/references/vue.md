Rule 6 (single source of truth · never mutate what you do not own · illegal states unrepresentable) in Vue.

**A prop mutated in place versus emitted back to its owner.** A prop is owned by the parent; the
child only reads it. Writing into it directly changes the parent's state without the parent knowing.

```
❌ props.user.name = newName
✅ emit('update:name', newName)
```

**Derived data copied into a `ref` and kept in sync by hand versus `computed`.** A second `ref` that
mirrors another value needs a watcher to stay correct, and a watcher is a manual sync a human must
remember to write correctly forever. `computed` has no sync step because it never drifts.

```
❌ const total = ref(0); watch(items, () => total.value = items.value.length)
✅ const total = computed(() => items.value.length)
```

**Three booleans encoding a request lifecycle that has only three legal states.** `isLoading`,
`isError`, `isEmpty` as independent refs admit combinations none of the three states describe —
loading and error true together compiles and renders both branches. A single discriminated `status`
ref (`'idle' | 'loading' | 'error' | 'success'`) makes the illegal combination impossible to hold.

**SSR/client state that must have exactly one owner.** State hydrated from the server and then
re-derived on the client — a `ref` seeded from an SSR payload that a client-only `onMounted` also
recomputes — creates two writers for one value; whichever runs last silently wins. The server-provided
value is the owner during hydration; client code reads it and refines it, it does not independently
recompute and overwrite it. Which composable owns the hydration write is a project convention where
one exists — see the project's SSR/hydration wiring rather than reinventing it here.

**A cache with no invalidation.** A `computed` wrapping an API result, memoized once and never
recomputed when its source refs change, becomes a second source of truth that quietly ages. Vue's own
`computed` already invalidates on dependency change — the defect appears only when someone bypasses it
with a manually memoized `ref`.
