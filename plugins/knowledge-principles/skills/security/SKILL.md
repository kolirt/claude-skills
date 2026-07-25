---
name: security
description: Use when adding or changing anything that crosses a trust boundary — an endpoint, a public field, a permission, a role check, a token, a lookup by an id from a request — and when reviewing authorisation, input handling, secrets in code or logs, or an error message that may leak internals.
---

# Rule 9 — Security by default

[invariant · desired] **The default denies, outside input is untrusted, secrets stay out of every
artifact, and every component runs on the narrowest privilege that lets it work.** This rule is the
**security floor**: it is never overridden by a convention or a framework idiom, and it is never
silent at any proportionality level.

Read `../../core/precedence.md` for why the floor sits outside the three bands.
Read `../../core/proportionality.md` for why the level machinery cannot switch this rule off.
Neither is re-argued here.

## What this rule requires

### The default denies

- A new endpoint, route, field, capability, or configuration flag is **closed until it is deliberately
  opened**. Access is granted by an explicit decision, never inherited by omission.
- Authorisation is enforced where the data is reached — on the server, in the handler or the data
  layer. A hidden button is not a permission.
- A new field added to a response is opt-in. Serialising an entity and then removing what should not
  ship is the wrong direction: list what ships.
- A failure in an authorisation check denies. It does not fall through to allow.

### Outside input stays untrusted

- Input that entered from outside the trust boundary is untrusted **regardless of which internal
  caller passes it on**. Passing a request value through three internal layers does not launder it.
- Validate at the boundary, and never reconstruct trust from the shape of the call stack.
- An identifier that arrives in a request identifies a *candidate*, not an entitlement. Every lookup
  by such an identifier is followed by an ownership or scope check before the record is used.
- Anything interpolated into a query, a command, a path, a template, or markup is escaped by the
  mechanism built for it — never by hand-rolled string work.

### Secrets stay out

- Secrets never reach source, fixtures, seed data, logs, error messages, analytics payloads, or
  anything client-visible. Not "temporarily", not in a test.
- A secret that has been committed is treated as compromised and rotated. Deleting the line is not
  the fix.
- Errors crossing the boundary say what the caller must do, not what the system is made of.
  Rule 5 (`errors`) owns the shape; this rule owns the disclosure limit.

### Narrowest privilege

- A component, a credential, a token, a role, a database user gets exactly the privilege it needs for
  its job — no more, and not "the same as the one next to it".
- **Privilege is never widened to make a test pass, a script run, or a local setup easier.** If the
  narrow privilege does not work, the answer is a correct grant, not a broader one.
- Scope is bounded in time as well as reach: tokens expire, elevated sessions end, temporary access is
  actually temporary.

## What violates it

- Authorisation checked in the UI only.
  - ✅ do: enforce the check server-side; let the UI mirror it for usability.
  - ❌ don't: hide the control and leave the endpoint open.
- A record fetched by an identifier taken from the request with no ownership check.
  - ✅ do: scope the lookup to the authenticated principal.
  - ❌ don't: fetch by id and trust that the caller only knows their own ids.
- A wildcard permission, a role granted "all", or a catch-all admin check standing in for a specific
  one.
- A token, key, password, or connection string in a fixture, a seed, a sample config, or a test.
- Verbose errors that disclose internals — stack traces, query text, file paths, dependency versions,
  or "user not found" versus "wrong password" where that distinction leaks account existence.
- Validation performed only on the client, or re-derived from a value the client controls.
- A permission check that logs and continues.

## What this rule does not claim

- **It is not a substitute for a security review or a threat model.** This rule is a floor for
  everyday code, not an assessment of the system. It does not model an attacker, rank risks, or
  clear a design.
- **It names no specific framework mechanism.** Which guard, which policy object, which middleware,
  which escaping helper, which secret store — band 1 or band 2. The mechanism is the project's; the
  obligation is this rule's.
- **It does not cover privacy or data retention.** What may be collected, how long it is kept, what
  must be erasable, jurisdictional obligations — deliberately out of scope for the ten rules. Their
  absence here is not permission.
- **It does not set an authentication or cryptographic policy.** Password rules, algorithm choices,
  key lengths, session lifetimes: project facts. This rule requires that a decision exist and be
  narrow, not a particular value.
- **It does not claim every input needs a schema.** It claims untrusted input is never trusted
  because an internal caller handed it over.

## Conflicts and how they resolve

Read `../../core/precedence.md`. This rule is the one place where the ordering inverts: a convention
or an idiom that appears to require an insecure default is a defect **in the convention**. Report the
conflict, comply with neither silently, and let the user decide — do not quietly rewrite the
convention either.

- **vs rule 5 (`errors`).** They meet at the error message. Rule 5 wants a useful failure; this rule
  caps what may be disclosed across the boundary. The cap wins: log the detail internally, return the
  actionable minimum.
- **vs rule 1 (`clarity`).** An explicit allow-list is longer than an implicit default. Take the
  length.
- **vs rule 8 (`performance`).** A check is not skipped, cached, or moved off the hot path for speed
  without an equally safe replacement. A measurement does not buy an exception here.
- **vs rule 3 (`boy-scout`).** A security defect found outside your touched lines is not a boy-scout
  cleanup to skip. It is reported even when it is not fixed.
- **vs convenience during development.** A local shortcut that widens privilege is a change to the
  code, and it ships. There is no "only in dev" carve-out in this rule.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
