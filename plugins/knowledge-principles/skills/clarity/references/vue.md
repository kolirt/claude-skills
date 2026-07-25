Rule 1 (clarity) in a Vue codebase.

**Template expressions that hide a decision.** A template is read at a glance, not stepped through —
an inline expression that branches on more than one condition forces the reader to simulate it.

- ✅ do: `<span>{{ statusLabel }}</span>` backed by a `computed` named for what it answers.
- ❌ don't: `<span>{{ user.active ? (user.verified ? 'Active' : 'Pending') : 'Disabled' }}</span>` —
  a nested ternary inside a template, doing three jobs at once.

**A `computed` that earns its name versus one that doesn't.** A `computed` should name a question a
reader would ask, not just wrap an expression for the sake of wrapping it. The test is the same
one-sentence test rule 1 states generally: if the expression is already a single clear step,
inlining it is fine — templates are allowed simple property access and simple comparisons.

- ✅ do: `const isOverdue = computed(() => invoice.dueAt < now.value)` — names the question.
- ❌ don't: repeating `invoice.dueAt < now.value` inline in three places in the template and in two
  sibling components — the repetition is evidence the name is missing, not that a shared module is
  needed (that timing question belongs to the `abstraction` skill).

**Destructuring that loses reactivity.** `const { name } = props` or `const { count } = toRefs`-less
destructuring of a reactive object silently freezes the value at the moment of destructuring. The
reader sees a plain variable and expects it to update; it does not, and the surprise is exactly what
this rule forbids.

- ✅ do: read `props.name` directly in the template or a `computed`, or destructure through
  `toRefs`/`toRef` when a local binding is genuinely needed.
- ❌ don't: `const { name } = props` used later as if it tracked prop changes.

**Implicit truthiness on a loading/empty/error trio.** `v-if="items"` conflates "not yet loaded",
"loaded and empty", and "failed" into one falsy check, exactly the coercion problem rule 1 names
generally — three states collapsed onto one branch.

- ✅ do: separate flags or a small status value — `v-if="status === 'loading'"`,
  `v-else-if="status === 'error'"`, `v-else-if="items.length === 0"` — each branch visible on its own
  line.
- ❌ don't: `v-if="items && items.length"` used as a stand-in for "request succeeded", so an
  in-flight request and a failed one render identically to an empty list.

**A watcher whose callback buries the decision it reacts to.** `watch(source, (v) => v > 10 &&
v < 100 ? doThing() : doOther())` forces the reader to unpack the condition before finding out what
the watcher is actually for.

- ✅ do: `watch(source, (v) => { if (inRange(v)) doThing(); else doOther(); })` with the range test
  named.
