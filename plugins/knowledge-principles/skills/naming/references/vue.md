Rule 7 (name the intent; make effects and dependencies explicit) in Vue.

**A `computed` named for its implementation rather than its meaning.** The name should say what the
value is, not how it was produced.

```
❌ const filteredMappedUsers = computed(() => users.value.filter(u => u.active).map(u => u.name))
✅ const activeUserNames = computed(() => users.value.filter(u => u.active).map(u => u.name))
```

**A composable whose signature hides which globals or singletons it touches.** `useCart()` that
internally reaches for a module-level singleton store, a route from `useRoute()`, and a session read
from `localStorage`, with none of it visible in the call `useCart()`. A caller cannot tell what it
depends on without opening the file. Where the dependency is genuinely ambient by framework design —
`useRoute()`, `inject()` from a provided context — that is the idiom, not the violation; the defect is
reaching for a *module-scoped singleton* import that a parameter or an injected token could have made
explicit instead.

**An event name that does not say what happened.** `emit('update')` or `emit('change')` from a form
field tells the parent nothing it can act on without inspecting the payload.

```
❌ emit('change', newValue)
✅ emit('update:email', newValue)
```

**A function called `getX` that also writes.** `getUser()` that lazily creates the user record on
first call reads as a pure lookup and is not; the name promises a query and performs a command. This
rule does not require splitting every function into pure query and pure command (see the naming
skill's CQS note) — it requires that the name not contradict the write.

```
❌ getUser(id)  // creates the row if missing
✅ getOrCreateUser(id)
```
