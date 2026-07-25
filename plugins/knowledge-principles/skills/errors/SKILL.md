---
name: errors
description: Use when handling input or failure — validating a request payload, message, or config; an empty catch block or a caught error that is only logged; an ignored error return value; a fallback that hides a real failure; a try/catch wrapping a whole function; or deciding what a user or calling system sees when something breaks.
---

# Rule 5 — Strict at input, fail fast inside, degrade at output

[invariant · desired] A failure has three positions and one obligation at each. At the **trust
boundary** you validate and reject: nothing unverified enters. **Inside**, you fail loudly and
immediately: an invalid state is never carried forward. At the **output edge** facing a user or a
calling system, you degrade to a defined, useful failure: never a stack trace, never a raw driver
message, never a silent empty result standing in for a break. Getting the position wrong is the
defect — strictness at the output edge is as wrong as tolerance at the boundary.

## What this rule requires

| Position | Obligation |
|---|---|
| Trust boundary, inbound | Validate shape **and** meaning before the first line of handler logic. Reject with a defined error. Do not coerce, repair, or invent a default for a required field |
| Inside the module | Values are already trusted, so a broken invariant is a bug: raise at the point of detection, with the context that identifies it |
| Output edge | Produce a failure the caller's contract lists: a defined type or status, a message that says what to do next, and a recorded correlation to the internal cause |

- **What counts as a trust boundary:** request payloads, query parameters, headers, uploaded files,
  third-party responses, webhook and queue messages, environment and config values, CLI arguments,
  and data read back from storage whose writers you do not control.
- **Fail fast inside means at the point of detection**, not three frames later where the symptom
  surfaces. That is what makes the trace point at the cause. Rule 6 (`state`) owns making the invalid
  state unrepresentable in the first place; this rule owns what happens when one is detected anyway.
- **Every caught error is handled or re-raised with context.** Handled means it recovers to a state
  the contract defines. "Logged and continued" is handling only when continuing is the defined
  behaviour and the code says so.
- **Catch narrowly.** Wrap the statement that can fail and the failure type it produces.

## What violates it

- ❌ don't: an empty catch — `catch {}`, `except: pass`, `if err != nil { }`.
  - ✅ do: handle it, or re-raise it with context added.
- ❌ don't: catch, log, and fall through into the happy path as if nothing happened.
- ❌ don't: ignore a returned error value or an unchecked status code — an unread failure is a
  swallowed failure.
- ❌ don't: a fallback that hides a real failure — an empty list, a zero, a stale cached value returned
  when the lookup broke, so the caller cannot tell "no data" from "the query failed".
  - ✅ do: make the two outcomes distinguishable; a fallback is legitimate only when it is the defined
    behaviour and the failure is still recorded.
- ❌ don't: one try/catch spanning the whole function body, so which statement failed is unknowable.
  - ✅ do: wrap the risky statement.
- ❌ don't: validate in the middle of handler logic, after side effects have already run.
- ❌ don't: collapse an exception into a boolean or a null, losing the reason.
- ❌ don't: leak an internal message, query fragment, path, or stack frame to an external caller —
  that is also a rule 9 (`security`) violation, and rule 9 is the floor.
- ❌ don't: signal success in the transport while reporting failure in the body, unless a convention
  defines exactly that envelope — then the convention wins.

## What this rule does not claim

- **Postel's Law is rejected at trust boundaries specifically, and nowhere else.** "Be liberal in what
  you accept" is a defect **where the input's author is outside your control**: there, a lenient parse
  silently invents data and the invention is discovered far away, in a different system, much later.
  This is not a blanket claim that tolerance is always wrong. **Inside a module, between components you
  own, accepting several shapes and normalising them is a design choice, not a defect** — you control
  both sides, both change together, and a wrong guess is bounded and visible. Do not carry
  boundary strictness inward as ceremony.
- **It does not prescribe an error-representation mechanism.** Exceptions, result or either types,
  error return values, panics, error envelopes — the choice belongs to band 1 (project convention) or
  band 2 (language and framework idiom); read `../../core/precedence.md`. This rule constrains *where*
  you check and *what reaches the edge*, never which type carries the failure.
- **It does not require defensive checks everywhere.** Re-validating trusted internal values at every
  layer is the failure mode this rule's positional structure exists to prevent: the check lives at the
  boundary, once. Defensive programming is consolidated here in that narrowed form only.
- **It does not define resilience policy.** Retries, timeouts, backoff, circuit breakers, dead-letter
  handling are infrastructure decisions the project makes; this rule only insists the failure is not
  lost while they run.
- It does not claim every failure must reach the user. A degraded outcome may be a partial page, a
  queued retry, or a reduced feature — as long as it is defined and recorded, not silent.

## Conflicts and how they resolve

Read `../../core/precedence.md` wherever precedence decides the question.

| Pulls against | Resolution |
|---|---|
| A convention mandating a validation layer or an error envelope | the convention wins; routing even a single field through it is compliance (`precedence.md`, worked example 2) |
| Rule 9 (`security`) — a useful message against a safe one | rule 9 wins, it is the security floor: the safe message goes out, the detail goes to the log under a correlation id |
| Rule 1 (`clarity`) | narrow try/catch and boundary validation add lines; that is structure, not clutter — clarity has no claim against it |
| Rule 8 (`performance`) | validation cost is not an optimisation target until it is measured; without a measurement, validation stays |
| Rule 3 (`boy-scout`) and rule 10 (`change-safety`) | a swallowed error on a line you did not touch is reported, not repaired in this diff |

This rule is silent at proportionality level 1 and applied **strictly** at level 3 — read
`../../core/proportionality.md` for what strictly adds.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
