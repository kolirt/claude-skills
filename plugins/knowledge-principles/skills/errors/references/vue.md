Rule 5 (errors) in a Vue codebase.

**Validation at the form boundary versus trusting a parent component.** A form component receiving
user keystrokes is a trust boundary — the input is unverified until checked — and must validate
before submission logic runs. A child component receiving typed props from a parent it is composed
with is not a trust boundary; re-validating an already-typed, already-constrained prop on every
render is the defensive-programming ceremony this rule rejects.

- ✅ do: validate the form's fields before calling the submit handler; trust a prop typed and
  supplied by a sibling component in the same app.
- ❌ don't: re-checking `props.count >= 0` inside a presentational component when the only caller
  already guarantees it.

**A `catch` that renders an empty list and hides a failed request.** `catch (e) { items.value = [] }`
with no further signal makes "nothing to show" and "the request broke" look identical to the user and
to the next developer reading the state.

- ✅ do: `catch (e) { error.value = e; items.value = [] }` and render the error state distinctly from
  the empty state.
- ❌ don't: swallow the exception and let the empty-list UI stand in for a failure silently.

**A global error handler that degrades usefully at the output edge.** `app.config.errorHandler` (or
an error boundary component) is the output edge for uncaught render/composition errors — its job is
to show a defined fallback and record the failure, never to let a raw stack trace or a blank white
screen reach the user.

- ✅ do: log the error with enough context to find it, and render a defined fallback UI.
- ❌ don't: leave the default behavior of an uncaught error silently blanking the page with nothing
  recorded.

**A composable's internal `watch` callback throwing.** An error thrown inside a `watch`/`watchEffect`
callback is Vue's own "fail fast inside" position — let it surface (or explicitly handle it with
`onErrorCaptured`) rather than wrapping the whole callback in a silent try/catch that discards it.

**A rejected `Promise` from a composable's async action left unhandled.** A component that calls
`await submitForm()` without a `try`/`catch`, when `submitForm` can reject, leaves the caller in an
unspecified state on failure — the same unread-failure problem as an ignored error return value,
expressed through an unhandled rejection instead.
