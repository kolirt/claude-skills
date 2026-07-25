Rule 1 (clarity) in a Laravel codebase.

**Chained collection pipelines that must be re-read to be understood.** A five-link
`->filter()->map()->groupBy()->flatMap()->reduce()` chain is a puzzle construct the moment a reader
has to trace what shape each link hands to the next.

- ✅ do: split the chain at the point where its purpose changes, and name the intermediate:
  `$activeUsers = $users->filter(fn ($u) => $u->active);` then operate on `$activeUsers`.
- ❌ don't: one unbroken chain where the comment above it translates the chain into English — that
  comment is the sign the chain should have been split.

**Implicit model magic in place of an explicit query.** Dynamic properties, magic scopes, and
accessor side effects read as clever until a reader who does not know this model's internals hits
them and has to go find the definition to know what a line does.

- ✅ do: an explicit query or a named scope method whose name states the condition:
  `User::query()->whereActive()->get()`.
- ❌ don't: relying on an undeclared dynamic property (`$user->is_premium` conjured by `__get`) where
  a real, declared accessor or a plain query column would read the same and cost nothing.

**Blade conditionals that encode business rules.** `@if($user->subscription && $user->subscription->plan === 'pro' && !$user->subscription->cancelled_at)`
buried in a view is a decision hidden from the code that owns it, and it duplicates a rule the model
should state once.

- ✅ do: `@if($user->hasActivePlan('pro'))` — the view asks a named question; the model answers it.
- ❌ don't: the raw multi-field condition inline in the template.

**Form request rules that hide the decision in array shape.** A validation rule array built with
conditional array-merging inline (`array_merge($base, $condition ? [...] : [])`) forces the reader to
mentally assemble the final rule set rather than reading it directly.

- ✅ do: build the array with an explicit `if` block that assigns into a named variable before
  `return`, so the reader sees each branch as a statement.
- ❌ don't: a single `return` expression nesting two ternaries and a merge, where the final rule set
  can only be known by evaluating all three at once.

**A query condition that relies on Eloquent's implicit boolean coercion.** `where('deleted_at', null)`
reads differently from `whereNull('deleted_at')` only in intent, but stacking several loosely-typed
`where` calls where the comparison operator is implied by the value's type is the same coercion
problem this rule names generally — the reader must know Eloquent's inference rules to know what is
being asked.

