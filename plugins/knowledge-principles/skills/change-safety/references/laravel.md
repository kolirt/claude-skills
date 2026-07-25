Rule 10 (do not touch what you do not understand; observable behaviour is someone's dependency) in Laravel.

**An API response shape or an error message text that a client parses.** Renaming a JSON field, or
rewording a validation error string, looks like a harmless polish pass but breaks any client matching
on the old key or the old text — including a client written by a team that never told you it depends
on it.

```
❌ // response key renamed silently: 'total' → 'amount_total'
✅ both keys present, or the rename is named in the summary and the client team is asked
```

**A queue job's payload contract.** Changing the shape of data a job serializes changes what a
still-queued, not-yet-processed job (serialized under the old shape) deserializes into once the new
job class runs — a job dispatched before deploy and processed after it sees a mismatch the code was
never written to handle.

**A migration that changes a column another consumer reads.** Narrowing a column's type, renaming it,
or dropping a nullable that another service's read replica or a report query depends on is a schema
change with readers the migration file cannot see. Establish who reads the column — another service, a
scheduled report, a queued job — before altering it.

**The seemingly pointless guard clause that exists because of a real production incident.** An
`if ($amount <= 0) { return; }` with no comment, sitting before a refund call, reads as dead
defensiveness — until the linked incident it silently prevents is found. Establish why before removing
it; per this rule, "no test covers it" is not evidence that it is dead.

```
❌ // "cleanup": removes the unexplained early return, ships a negative-refund bug again
✅ git blame / linked issue read first; guard kept, or removed with the reason recorded
```

The same caution applies to a middleware ordering in `bootstrap/app.php` or the kernel: reordering
`ThrottleRequests` ahead of `SubstituteBindings` because "it reads better" changes what a request sees
before it is even a defect anyone would call one.
