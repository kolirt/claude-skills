Rule 10 (do not touch what you do not understand; observable behaviour is someone's dependency) in Vue.

**A prop default or emitted payload shape a consumer already depends on.** Changing a prop's default
from `false` to `true`, or adding a field to an emitted event's payload object while renaming an
existing one, changes what every parent already listening receives — parents constructed before the
change assumed the old shape.

```
❌ // was: emit('save', { id })  → now: emit('save', { recordId })
✅ emit('save', { id, recordId })  // old key kept, new key added, both named in the summary
```

**A rendered output's ordering treated as incidental when a snapshot depends on it.** A list rendered
in whatever order the source array happens to produce, then reordered "for clarity" during a refactor
— a snapshot test, or a user's expectation of "most recent first," was relying on the old order even
though nothing declared it a contract.

**Removing an apparently unused prop or slot.** A prop with no local reads inside the component may
still be consumed by a parent binding it, or a named slot may be filled by a parent that a search
inside the component alone will not reveal — the search has to include callers, not just the
component's own body.

**The escape path.** Name the parents that pass the prop or listen for the event, state in the summary
exactly what changed and from what to what, and either keep the old prop/event alongside the new one
or get explicit approval to break it outright.

```
✅ "BaseModal's close-on-backdrop-click default changed from true to false;
    3 call sites relied on the old default and were updated to pass it explicitly."
❌ (a refactor summary that mentions the extraction but not the default it flipped)
```

The same applies to a lifecycle-timing change — moving work from `created` to `mounted`, or from a
watcher's immediate run to a lazy one — where a parent's own `nextTick` or `onMounted` ordering
assumed the old timing.
