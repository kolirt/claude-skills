Rule 5 (errors) in a Laravel codebase.

**A form request as the strict input boundary.** `FormRequest::rules()` is where inbound data is
validated for shape and meaning before a controller method's first line runs; a controller that
accepts a plain `Request` and pulls fields out ad hoc, checking some and trusting others, has moved
the boundary check into the middle of handler logic.

- ✅ do: a `FormRequest` with a `rules()` array covering every field the controller relies on; the
  controller receives only validated data.
- ❌ don't: `$request->input('email')` used directly in a controller with no form request behind it,
  relying on the database to reject a bad value later.

**Swallowing an exception in a job so a failure never surfaces.** `try { $this->charge(); } catch
(\Throwable $e) {}` inside a queued job's `handle()` method silently ends the job — no retry, no
`failed()` callback, no record that the charge never happened.

- ✅ do: let the exception propagate so Laravel's queue worker marks the job failed and `failed()`
  runs, or catch narrowly and re-throw with the context that identifies the failure.
- ❌ don't: an empty catch in a job, leaving the queue table's "processed" count wrong about what
  actually happened.

**The exception handler as the degrade-at-output position.** `app/Exceptions/Handler.php`'s
`render()` method is the output edge: it is where an internal exception becomes a defined JSON error
shape or a defined error page — never a raw stack trace, and never the database driver's message
verbatim, reaching an API client or a browser.

- ✅ do: map exception types to a defined response shape in `render()`; log the full detail with a
  correlation id, return the safe message.
- ❌ don't: let `config('app.debug')` leak stack traces in a path a real caller can reach outside
  local development.

**Internal tolerance between your own components is a design choice, not a defect.** A service
class that accepts either a `Money` value object or a plain integer cents value from another service
you also own, and normalizes it internally, is not Postel's Law violated — both sides are yours, both
change together, and the normalization is a documented design choice rather than boundary laxity.

**A middleware that is itself a trust boundary.** Auth and validation middleware sit before the
controller for exactly this reason — a route with no form request and no middleware guarding it
pushes the boundary check into the controller body, past whatever side effects run first.
