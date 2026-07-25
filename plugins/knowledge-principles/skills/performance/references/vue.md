Rule 8 (known slow patterns are defects; optimisation requires measurement) in Vue.

**A request fired per list item.** Rendering a list of parents and issuing one API call per row inside
each item component is the query-inside-a-loop pattern restated in a UI shape.

```
❌ <UserCard v-for="id in ids" :key="id" :user="useFetch(`/users/${id}`)" />
✅ const users = useFetch('/users', { params: { ids } })  // one request for the set
```

**An unbounded list rendered without windowing.** A `v-for` over a collection with no page size and no
virtualization is fine at ten items and a defect at ten thousand — the DOM node count grows with total
data instead of with what is visible. Cap it, paginate it, or virtualize it.

**Work repeated per render that could be hoisted.** A regex compiled, a formatter constructed, or a
static list built fresh inside a `computed` or a render function on every dependency change instead of
once at module or setup scope.

```
❌ const formatted = computed(() => new Intl.NumberFormat('en-US').format(value.value))
✅ const formatter = new Intl.NumberFormat('en-US')  // built once, outside the computed
   const formatted = computed(() => formatter.format(value.value))
```

**A watcher that recomputes the world.** A `watch` on a broad, high-frequency source (an entire
reactive object, a scroll position) that reruns an expensive full recomputation on every tick instead
of narrowing the source or debouncing.

```
❌ watch(reactiveFilters, () => recomputeEntireDataset(), { deep: true })
✅ watch(() => reactiveFilters.category, () => recomputeCategory())  // narrowed to what changed
```

**The measured half.** Replacing a `computed` with a hand-rolled memoization, or switching a `v-for`
key strategy for speed, is not adopted on the strength of "this should render faster" — it ships with
the number measured before the change, per this rule's second half.
