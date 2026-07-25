Rule 2 (abstraction) in a Vue codebase.

**The I/O half — a boundary call sitting unwrapped inside a component.** `fetch`, `axios`,
`localStorage`/`sessionStorage`, `Date.now()`/`new Date()`, `crypto.randomUUID()`, and any third-party
SDK client are outside-the-process boundaries; a component or composable calling them directly is an
unwrapped seam from the first line, not the third.

- ✅ do: a composable or module that owns the call — `useUserStore().fetch()`, a storage wrapper, a
  clock function — called by the component.
- ❌ don't: `onMounted(() => { const res = await fetch('/api/users') })` inline in a component, or
  `localStorage.getItem(...)` read directly in a `computed`.
- Where a project convention already mandates a specific request wrapper or storage module, that
  convention decides the shape of the wrapper — this rule only insists a wrapper exists at all.

**The domain half — three components sharing a shape before a composable is extracted.** Two
components with a similar `ref` + `watch` pair are not yet a pattern; a composable extracted at the
second occurrence, before a third real consumer exists, is speculative generality the same way an
early domain abstraction is anywhere else.

- ✅ do: write the second component's local state again, plainly duplicated, and extract
  `useSortableList()` only once a third component needs the same behaviour for the same reason.
- ❌ don't: a generic `useEntityState<T>()` composable with one call site, built because "the next
  page will probably need it too."
- Honest limit: a house convention may mandate the composable-extraction pattern from the first call
  site regardless of occurrence count — that is band 1's decision, not this rule's, and this rule
  defers to it where it applies.

**Duplicated knowledge versus duplicated text in props.** Two sibling components each hard-coding the
same status-to-color mapping is one business fact in two places — a defect immediately. Two
components that happen to both have a `size: 'sm' | 'md' | 'lg'` prop, driven by different design
needs, are duplicated text and may legitimately diverge.

- ✅ do: pull the status-to-color mapping into one named source both components read, the moment the
  second copy appears — it is knowledge, not style.
- ❌ don't: leave the same `{ pending: 'gray', active: 'green', closed: 'red' }` object typed out in
  two components, so a new status added to one is silently missing from the other.

**A router guard reaching for a raw boundary call.** A navigation guard that reads
`localStorage.getItem('token')` directly to decide whether to redirect is the same unwrapped
I/O-boundary problem as inside a component — the guard is still call-site code, not the wrapper
itself.
