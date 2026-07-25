Rule 4 (module-boundaries) in a Laravel codebase.

**A controller reaching through Eloquent relations into another aggregate's internals.** Walking
`$order->customer->billingProfile->taxId` inside a controller depends on the customer aggregate's
internal relation graph rather than on something the order (or the customer) exposes as a promise.

- ✅ do: ask the object that owns the fact — `$order->customer->taxId()` — and let the customer model
  own the relation walk.
- ❌ don't: chain three relations deep from a controller or a Blade view, so every layer of that
  relation graph is now load-bearing for an unrelated feature.

**A model with a surface no caller needs.** An Eloquent model exposing every relation, every scope,
and a dozen accessors — most called from nowhere — is public-by-default; the unused ones are
promises nobody asked for and a future refactor has to keep honoring anyway.

- ✅ do: keep the relations and scopes real controllers, jobs, and views actually call; add more when
  a real caller needs them.
- ❌ don't: a model with twelve public scopes where two are used, "in case a future report needs
  them."

**The "one reason to change" test applied to a service class.** A single `UserService` that both
enforces business validation on user creation and formats users for a third-party export API has two
owners — the domain rule and the export format change on different schedules, for different reasons.

- ✅ do: split into the domain-facing service and the export formatter, meeting at a stated method
  contract.
- ❌ don't: one class where an export-format change and a validation-rule change both require editing
  the same file for unrelated reasons.

**Eloquent's active-record shape crossing a layer, by framework idiom.** Returning a live Eloquent
model out of a repository into a controller is the framework's documented pattern, not a violation —
where the project's own convention builds on active record, the idiom wins over an architectural
purity claim that this model should have been mapped to a DTO first.

**An event listener reaching past the event's declared payload.** A listener that loads a fresh
model from the database to get data the event's own properties already carry, because it also
happens to know the model's table shape, depends on the schema instead of on the event's contract —
the fix is adding the missing property to the event, not reaching around it.
