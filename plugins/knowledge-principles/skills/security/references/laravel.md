Rule 9 (security by default) in Laravel.

**An identifier from the request used to fetch a record without an ownership check.** Route-model
binding resolves `Invoice $invoice` from the URL segment; it does not confirm the invoice belongs to
the authenticated user.

```
❌ public function show(Invoice $invoice) { return $invoice; }
✅ public function show(Invoice $invoice) {
     $this->authorize('view', $invoice);
     return $invoice;
   }
```

**A policy or gate not applied on a route that returns another user's data.** Defining an
`InvoicePolicy` and calling `$this->authorize()` on the `update` route but not the `show` route leaves
one door open; every route touching the model needs the same gate, not just the one that mutates.

**Mass assignment opening fields the client should not set.** `$fillable` (or an unguarded model)
listing `is_admin` or `status` alongside legitimate fields lets `Model::create($request->all())` set a
privilege the client never should have touched. List only what the client may set; derive the rest
server-side.

```
❌ protected $fillable = ['name', 'email', 'is_admin'];
✅ protected $fillable = ['name', 'email'];  // is_admin set only by a privileged code path
```

**Secrets in fixtures or logs; verbose error output.** A seeder with a real API key "just for local",
or `Log::info($request->all())` on a route that accepts a password field, ships a secret into a
committed file or a log store. `APP_DEBUG` left true in a deployed environment turns every exception
into a stack trace disclosed to the caller — the default for a new environment is debug off, errors
minimal, until deliberately changed.

```
❌ Log::info('login attempt', $request->all());  // logs the password field verbatim
✅ Log::info('login attempt', $request->except('password'));
```
