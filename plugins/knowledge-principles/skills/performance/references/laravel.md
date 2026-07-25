Rule 8 (known slow patterns are defects; optimisation requires measurement) in Laravel.

**A query inside a loop over a result set (N+1) and its eager-loading fix.** The archetypal case this
rule names directly: fetching a collection, then accessing a relation inside a loop over it, issues one
query per row.

```
❌ foreach (Order::all() as $order) { echo $order->customer->name; }
✅ foreach (Order::with('customer')->get() as $order) { echo $order->customer->name; }
```

**An unbounded `all()` where pagination or chunking is required.** `Model::all()` returned to a
controller or looped for a batch job loads every row into memory; correct on a small table, an outage
once it grows. `paginate()` for a response, `chunk()` or `cursor()` for a batch job — a cost that grows
with the page, not with the table.

```
❌ Order::all()->each(fn ($o) => $mailer->send($o));
✅ Order::query()->chunk(200, fn ($orders) => $orders->each(fn ($o) => $mailer->send($o)));
```

**A cost that grows with total rows rather than with the page.** Loading a whole table to count,
sum, or filter in PHP where the database can do it in one aggregate query (`->count()`, `->sum()`,
`->where()`) instead of `->get()->count()`.

```
❌ Order::all()->where('status', 'paid')->count();  // filters in PHP after loading everything
✅ Order::where('status', 'paid')->count();  // filters and counts in the database
```

**The measured half.** A `Cache::remember()` wrapped around a query, or a denormalised column added to
avoid a join, is justified in the change by the measurement it responds to — the query time observed,
on what data volume — not by "this table will probably get big." Without that measurement, the
readable query stands, per this rule's default to clarity. The cache also states what invalidates it —
which write path clears the key — or it is a correctness defect wearing a performance improvement.
