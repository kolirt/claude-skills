Rule 6 (single source of truth · never mutate what you do not own · illegal states unrepresentable) in Laravel.

**A model instance mutated inside a helper that did not create it.** A model fetched by the caller
and passed into a helper function is not the helper's to change; the helper returns a new value or
calls a method the model itself exposes.

```
❌ function applyDiscount(Order $order) { $order->total -= 10; return $order->total; }
✅ function discountedTotal(Order $order): int { return $order->total - 10; }
```

**Cached derived values that can disagree with their source.** A `total_amount` column, or a
`Cache::remember()` value, computed from line items and stored beside them, drifts the moment a line
item changes without also updating the cache. Either derive it on read (an accessor, a query) or
invalidate the cache at every write path that can affect it — an uninvalidated cache is a second,
aging source of truth.

```
❌ $order->total_amount = $order->items->sum('price');  // stored, then forgotten
✅ public function getTotalAmountAttribute() { return $this->items->sum('price'); }  // derived
```

**An enum or check constraint making an illegal status impossible versus validating it in five
places.** A `status` column typed as a free string, validated in the controller, the job, and the
observer, still accepts a sixth caller that skips validation. A native enum column (or a database
check constraint) makes the illegal value impossible to store at all, not merely rejected at the
edges the code remembered to check.

```
❌ 'status' => 'string'  // validated ad hoc wherever it is set
✅ 'status' => OrderStatus::class  // backed enum, illegal value cannot be assigned
```

**`config()` read as ambient state.** Reading `config('app.timezone')` deep inside a service is
reading the single owner (the config repository) correctly — the defect is treating a *runtime*
override of config (`config(['app.timezone' => $x])` mid-request) as safe global mutable state that
other code paths then read, rather than as a write to shared state nothing else expects.
