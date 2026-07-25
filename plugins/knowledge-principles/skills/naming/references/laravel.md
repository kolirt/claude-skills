Rule 7 (name the intent; make effects and dependencies explicit) in Laravel.

**A scope or accessor whose name promises a query and performs a write.** A local scope or an Eloquent
accessor reads as inert from the call site; a caller chaining `Order::active()` does not expect a row
to be touched.

```
❌ public function scopeActive($query) { $this->last_checked_at = now(); return $query->where(...); }
✅ public function scopeActive($query) { return $query->where('status', 'active'); }
```

**A service method whose dependencies arrive from a facade instead of the signature.** A method that
calls `Auth::user()` or `Cache::get()` deep inside instead of receiving the user or the cache as a
parameter hides what it needs; two callers in two different auth contexts get silently different
behaviour from an identical call. Where the facade is the framework's documented way to reach a
request-scoped singleton, that is the idiom (see the rule's own note on DI containers and
module-scoped clients); the defect is a facade standing in for a dependency the method could have
declared.

```
❌ public function charge(Order $order) { $user = Auth::user(); ... }
✅ public function charge(Order $order, User $payer) { ... }
```

**An artisan-style action name that understates its effect.** A job or command named `SyncInventory`
that also emails a low-stock alert as a side effect; a caller reading the name has no reason to expect
an email. Either the name grows to cover the effect, or the effect moves to its own listener triggered
by an event the sync dispatches.

```
❌ class SyncInventory { public function handle() { /* sync + also sends email */ } }
✅ class SyncInventory { public function handle() { /* sync, dispatches InventoryLow event */ } }
```

The same test applies to a request-validation rule named `Unique` that also normalises the input it
checks, or a `form request` `authorize()` that silently mutates the request — the name of the hook
promises a check, not a write.
