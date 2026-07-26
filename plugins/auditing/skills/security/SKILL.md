---
name: security
description: Use on demand to audit whether a WHOLE application is safe by default — 'security audit', 'аудит безпеки', 'is this app secure', 'check auth and permissions', 'are we leaking secrets', 'review access control'. Static read of the code: reports missing validation, broken authentication and authorisation, exposed secrets, injection and unsafe rendering surfaces, and capabilities that are open until deliberately closed. Read-only — reports findings, never fixes them and never exploits, probes, or runs anything. Not an availability review (that is auditing:reliability), not a storage-invariant review (that is auditing:data), not a dependency CVE scan, and not a privacy or data-retention policy review. Audits of a PR diff or a set of changes belong to the auditing-prs plugin.
---

# Security audit

Judges whether the application is **safe by default**: whether untrusted input is treated as
untrusted, whether identity and permission are enforced where the data actually leaves the system,
and whether anything is open until someone remembers to close it.

The separating sentence: this domain owns **who can reach what, and what leaks** — not whether the
system stays up (`auditing:reliability`) and not whether the stored shape is correct
(`auditing:data`).

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. Under the dispatcher the **snapshot** arrives as an input:
detection is not repeated, and this domain does not disagree with the facts it was handed. Invoked
directly, this domain runs the script itself first.

| Fact needed | Used for | When absent |
|---|---|---|
| `server` | Locating the enforcement boundary — where a request is actually authorised; the endpoint, authorisation, injection, and mass-assignment sub-checks | No `server` surface in this unit: the server-side sub-checks are `skipped: not applicable`; client-side-only enforcement becomes the central question instead |
| `ui` | Locating rendering sinks, client-visible config, and build output; client-side enforcement and secret-exposure sub-checks | Client-side sub-checks `skipped: not applicable` |
| `data_schema` | The at-rest questions this domain shares with `auditing:data` only — not query construction, which is judged from `server` | That shared sub-check is `skipped: not applicable`; the rest of the domain is unaffected |
| `api_contract` | Enumerating the endpoints that must each carry a check | Endpoints are enumerated from routing instead; coverage says the enumeration is code-derived |
| `convention_plugins` | Whether knowledge tier 3 exists this run | Tiers 1 and 2 run; a coverage line names the missing tier |

When neither `server` nor `ui` is present in a unit, this domain has nothing to enforce and is
`skipped: not applicable` wholesale in that unit. Every skip is recorded in the coverage section
**with the fact that was missing**. A stack this domain does not run on produces no findings — never
invented ones, and never a guess at what a finding would have looked like.

## 1. What this domain judges

### Trust boundaries

- What is treated as untrusted input: request bodies, query and path parameters, headers, cookies,
  uploaded files, webhook payloads, and values read back out of storage that a user once wrote.
- Whether validation happens **at the boundary** the request crosses, or is assumed because the
  caller is "internal". Is any caller actually prevented from reaching the surface directly?
- Whether a constraint is enforced server-side or only in the client: a disabled control, a hidden
  field, a form-level rule, or a client-side guard with no server counterpart.
- Whether validation is allow-list or deny-list, and what reaches the sink on merely unexpected input.

### Authentication and session handling

- Session lifetime: whether a session expires at all, is bounded, or renews silently forever.
- Invalidation: what logout actually does — is server-side state cleared, or is only a client token
  discarded? Can an already-issued token still read data after logout, a password change, or a role
  change?
- Credential handling: how a password or token is transported, logged, echoed back, or put in a URL.
- Password and token storage shape: password-appropriate hashing, or reversible, fast-hashed, plain.
- Whether an expired or revoked session is rejected by the endpoint or merely by the UI.
- Registration, reset, and re-authentication paths: whether they can be used to take over an account
  (unbounded attempts, guessable or non-expiring reset tokens, an unverified email change).

### Authorisation

- A **request-supplied identifier used to fetch a record with no ownership check** — the single most
  common finding in this domain. For each read and each write: whose record is it, and where is that
  ownership asserted?
- Missing per-record checks behind a passing role check: the user may use the feature, but not on
  *this* row.
- Authorisation asserted in the UI while the endpoint stays open: a hidden menu item, a route guard,
  a conditional button — with the underlying handler unguarded.
- Wildcard or over-broad permissions: a role that implies everything, a check that passes on any
  authenticated user, a permission string matched by prefix.
- Privilege widened to make something work: a check relaxed, an admin-only path reused for a normal
  user, a service-level credential used for a user-initiated action.

### Secrets and disclosure

- Secrets in source, fixtures, seeds, test data, committed env files, CI definitions, or loaded
  example files.
- Secrets in client-visible config or build output: inlined into a bundle, exposed through a public
  runtime-config surface, or readable in a served asset.
- Secrets in logs and error reporting: credentials, tokens, or full request bodies written out.
- Verbose errors and stack traces reaching a user: framework debug pages, database messages, file
  paths, or internal exception text returned in a response.
- Internal structure leaking: guessable internal identifiers exposed where an opaque one is expected,
  internal hostnames, directory listings, source maps in a production build.

### Injection and untrusted rendering

- Raw query construction from request data: string-concatenated or interpolated SQL, a raw expression
  passed a user value, a sort or filter column taken from input.
- Command construction from request data, and any evaluation of a user-supplied string.
- Unsanitised HTML rendering: a raw-HTML sink fed user content, unsanitised markdown, an attribute or
  URL sink accepting a user-controlled scheme.
- Unsafe deserialisation of user-supplied payloads.
- Path traversal from user-supplied names used to build a filesystem or storage path.
- Unrestricted file upload handling: type and size established from the client's claim rather than
  the content, executable or served-back locations, an original filename used verbatim.
- Server-side requests built from a user-supplied URL.

### Dangerous defaults

- A new endpoint, field, or capability that is **open until deliberately closed**: routing that
  exposes a handler by convention, a resource that serialises every attribute, a permission model
  whose default is allow.
- Mass-assignment surfaces: a request payload bound wholesale to a model or an update statement,
  where an unexpected key changes ownership, role, price, or state.
- Permissive CORS: a wildcard origin, an origin reflected from the request, credentials allowed
  alongside a broad origin.
- Debug mode shape: whether debug is off by default, how it gets turned on, and whether a debug or
  profiling surface is reachable in a deployed configuration.
- Missing baseline response hardening on surfaces rendering user content; session cookie flags.

## 2. Impact dimensions

Severity is graded by security impact, never by code shape. The scale itself lives in
`../../core/report-model.md`; these are its meanings here.

- **blocker** — data of one user is reachable by another; authentication is bypassable; a secret is
  exposed; or remote code execution is reachable.
- **major** — a real exposure gated by a condition the attacker does not control (a specific role, a
  non-default configuration, a state they cannot force), or a disclosure that meaningfully helps an
  attacker reach one of the above.
- **minor** — a hardening gap with no demonstrated path: a defence that would help but whose absence
  does not, on its own, let anyone through.

A tangle of authorisation code that leaks nothing is not a finding; one missing ownership check is a
blocker.

## 3. What this domain does NOT cover

- **Availability** — whether the system stays up under load, abuse, or failure is owned by
  `auditing:reliability`: timeouts, retries, rate limits as a capacity control, and degradation.
  This domain owns rate limiting only where its absence enables credential attacks; the
  resource-exhaustion side belongs to `auditing:reliability`.
- **Storage invariants** — `auditing:data` owns whether the schema enforces what it claims:
  constraints, nullability, uniqueness, cascade behaviour, index existence. The seam runs both
  ways: **this domain owns PII exposure** — a field reaching a caller who should not see it, a log,
  or a bundle — while **`auditing:data` owns PII at rest as a schema fact**: which columns hold
  personal data and how they are declared. A finding about a personal field being *returned* is
  `SEC`; a finding about that field's declaration or storage shape is `DATA`.
- **Privacy and data-retention policy** — lawful basis, consent, retention periods, deletion
  obligations, and regulatory posture are **out of the plugin's scope entirely**. No domain covers
  them; do not report them and do not imply a sibling will.
- **Dependency CVE scanning** — vulnerable or outdated packages are **out of scope**. There is no
  `dependencies` domain in v1, so nobody in this plugin covers it; say so plainly in coverage rather
  than filing it, deferring it to a sibling, or leaving the reader to assume it was checked.
- **Monetisation gates** — `auditing:business-analysis` owns a paid gate that does not gate as a
  product hole; this domain owns it only when that gate *is* the access control.

## 4. How to audit

Static reading only. **No exploitation, no probing, nothing is run** — no request is sent, no payload
tried, no credential used, no tool executed against a running system.

Order of work:

1. Read the boundary first: routing and endpoint definitions, middleware or filter chains, and the
   authentication mechanism. Establish where a request becomes trusted.
2. For each surface that reads or writes data, follow the identifier: where it comes from, and where
   ownership and permission are asserted between the request and the store.
3. Read the rendering and query sinks, then walk backwards to see what can reach them; read
   configuration and build output last, for secrets, defaults, and disclosure.

**Establishing absence.** A missing check has no `file:line`; use the `expected surface absent`
locator from `../../core/report-model.md`, state where the check was expected, and state how you
established it is not applied elsewhere — a global middleware, a base class, a policy layer, or a
guard further up the chain all count as elsewhere. Absence is established by reading **every path
that reaches the resource**. If that enumeration could not be exhaustive, the coverage section says
so, naming what was not reachable from here.

**Findings versus notes.** A finding names a concrete surface and the mechanism by which someone
reaches what they should not. An **unverified exploit path is a finding with `confidence: medium`
and its assumption written into `assumptions`** — never an asserted breach, and never phrased as
though it had been demonstrated. A defence you would add with no path behind it is `minor` or an
opportunity, not a blocker.

## 5. Knowledge tiers

- **Tier 1 — universal invariants.** Everything in section 1: input is untrusted until validated at
  the boundary, identity and ownership are enforced where the data leaves, secrets stay out of
  source and client, sinks are never fed raw input, defaults are closed. Always applied.
- **Tier 2 — ecosystem general practice.** The detected framework's **own documented security
  mechanisms** — its validation layer, its authentication and session handling, its authorisation or
  policy layer, its escaping and mass-assignment protections, its CSRF and CORS handling, its debug
  and secret-management conventions. A framework mechanism bypassed by hand-rolled code is a tier-2
  finding.
- **Tier 3 — codified project conventions.** From `knowledge-principles:security` when that plugin
  is available this session. The dependency is **soft**: absent means tiers 1 and 2 run normally and
  a coverage line records `tier 3 unavailable — knowledge-principles not present in this session`.
  That line is a coverage fact, not a finding.

## 6. Report

Read `../../core/report-model.md` and follow it exactly — output location, finding fields, evidence
locators, severity and confidence, opportunities, run comparison, and the mandatory coverage
section. Nothing from it is restated here.

- **Finding-id prefix: `SEC`** — `SEC-1`, `SEC-2`, … stable within the report.
- **Remediating skill.** Name the fully-qualified skill that owns the fix when one exists, and leave
  the field empty when none does. Framework-level enforcement usually has no owning skill in this
  marketplace; delivery-layer fixes may name a `knowledge-*` skill (for example the client-side
  request layer for a token handling fix). Never a bare name — always fully qualified.
- The bridge to fixing is `auditing:remediate`. This audit names findings and stops.
