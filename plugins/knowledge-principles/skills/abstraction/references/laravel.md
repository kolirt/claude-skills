Rule 2 (abstraction) in a Laravel codebase.

**Third-party SDK calls and the clock behind a thin seam.** A payment gateway SDK, an email
provider client, `now()`/`Carbon::now()` read for a business decision, or `Str::uuid()` used as a
domain identifier are boundary calls; wrapping them at first use is compliance, not overreach.

- ✅ do: a small service class or facade the domain calls — `PaymentGateway::charge($order)` — so the
  vendor SDK's types never reach a controller or a model.
- ❌ don't: `\Stripe\Charge::create([...])` called directly inside a controller method or a job.
- Laravel's own facades (`Cache`, `Queue`, `Storage`) already are that seam for their respective
  boundaries — wrapping a facade again adds nothing; the rule is satisfied by using the facade
  itself rather than the raw driver.

**A repository or service layer: speculative versus mandated.** A repository interface built around
one Eloquent model with exactly one implementation, added "in case we swap databases," is the same
generic-base-class violation this rule names generally.

- ✅ do: query the model directly until a second real consumer or a second real data source exists.
- ❌ don't: `UserRepositoryInterface` plus `EloquentUserRepository` with a single binding and a single
  caller.
- Where a project convention already mandates the repository layer everywhere, the convention wins —
  this rule does not get a vote against a codified layout (`../../core/precedence.md`, band 1).

**Duplicated knowledge versus duplicated text between form requests.** A tax rate, a discount
threshold, or a status enum repeated across two `FormRequest` rule arrays is one fact in two places —
a defect at the first duplication, because the two must change together or the system silently goes
wrong. Two `FormRequest` classes that both happen to validate a `name` field with similar-looking
rules, but for genuinely different resources with different owners, are duplicated text and may stay
separate even after a third one appears.

- ✅ do: a single `config()` value or an enum class read by both requests for the shared threshold.
- ❌ don't: `'discount' => 'max:20'` typed into two separate request classes, so raising the cap
  requires remembering both.

**An Artisan command reaching for the clock directly.** A scheduled command deciding "is this the
first day of the month" by calling `now()->day === 1` inline is the clock boundary this rule names
generally — wrapped from the first call, the same as any other I/O boundary, not counted like a
domain shape.

- ✅ do: a named helper — `isFirstOfMonth(): bool` — the command calls, so the business question has
  one place to change if the definition of "first day" ever does.
- ❌ don't: the raw `now()->day === 1` comparison inline, repeated verbatim in a second command later.
