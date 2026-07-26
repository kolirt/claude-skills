---
name: api-contracts
description: Use on demand to audit the interface between client and server across a WHOLE application — 'API audit', 'аудит API', 'contract audit', 'check our endpoints', 'inconsistent responses', 'wrong status codes', 'does the client match the API'. Judges response-shape consistency, error format, status codes, pagination, versioning, and whether the client's expectations match what the server returns. Reports findings, never fixes them and never calls a live endpoint. Not an authorization review (auditing:security), not a storage review (auditing:data), not a retry/timeout review (auditing:reliability). Audits of a PR diff belong to the auditing-prs plugin.
---

# Api-contracts audit

Judges whether the interface between client and server is **consistent and honest**: the same entity
shaped the same way everywhere, errors a client can branch on, status codes that match what happened,
and a client whose expectations match what the server actually sends.

The separating sentence: other domains judge one side of the wire — this domain reports only what two
locations can show, whether that is the two sides of the wire or two clauses of one contract document.

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. Under the dispatcher the snapshot arrives as an input:
detection is not repeated here and the snapshot is not argued with. Invoked directly, this domain
runs detection itself first.

| Fact needed | Used for | When absent |
|---|---|---|
| `api_contract` | Full contract mode — the schema is the declared contract. | Drop to client-internal mode, below. |
| `server` | The implementation side of the contract. | Only the client side is checkable; state it in coverage. |
| `ui` (as the carrier of a client request layer) | The consumer side of the contract. | Only the server side is checkable; state it in coverage. |
| `convention_plugins` | Whether knowledge tier 3 exists this run. | Tiers 1 and 2 run; the missing tier is a coverage line. |

**Three modes, driven by detection.**

- **Full contract mode** — `api_contract` is present and at least one of `server` or `ui` is also
  present. The schema *is* the declared contract, and every divergence between it and the
  implementation, or between it and the client, is a finding.
- **Contract-document-only mode** — `api_contract` is present but both `server` and `ui` are absent.
  Neither implementation side is visible, so the document itself is the whole audit: internal
  consistency of its shape, error format, status codes, pagination, and versioning. Coverage states
  plainly that neither the server nor the client side was visible this run.
- **Client-internal consistency mode** — `api_contract` is absent. The domain checks only whether the
  application's own request and response handling is coherent **with itself**: the same endpoint
  described two ways in two places, a field parsed in one call site and ignored in another, an error
  branch that cannot be produced by the code that raises it. Coverage says explicitly that this run
  ran in this mode and what that excludes.

No mode **invents the missing side** of the contract. Absent a server, the audit does not assume
what the server returns; absent a schema, it does not treat one side's types as a specification. `ui`
being present does not by itself prove a client request layer exists: if reading the unit turns up no
request-making code, the domain records that finding as `skipped: not applicable` with the reason,
rather than assuming a client to audit. The outcome is `skipped: not applicable` only when
`api_contract`, `server`, and `ui` are **all** absent — no contract document and no request surface of
either kind, recorded with the reason.

## 1. What this domain judges

### Response shape consistency

- The same entity is returned with the same shape everywhere it appears — not trimmed in a list and
  expanded in a detail response without that being a declared, consistent rule.
- Collection responses are shaped consistently across endpoints: one envelope convention, not a bare
  array here and a wrapped object there.
- A field's **type is stable** across responses. An id that is a number in one response and a string
  in another is a finding regardless of which is "right".
- Nullability is consistent with what clients handle: a field the server can omit or null, which the
  client dereferences unconditionally.

### Error format

- **One** error shape across the surface. An endpoint inventing its own is a finding even when the
  shape is individually reasonable.
- The shape is machine-readable enough for a client to **branch** on: a stable code or type, not only
  a human sentence that changes with wording.
- A validation error identifies the **field** it concerns, so a client can attach it to an input.
- The error shape a client parses and the error shape the server produces are the same shape.

### Status codes

- The code matches what happened. A failure returning `200` with an error body in it is a finding —
  it forces every client to inspect the body to learn whether the call worked.
- The distinct cases are used rather than collapsed into one code: created, no-content, conflict,
  unprocessable, not-found.
- **Authentication is distinguished from authorisation** — unauthenticated and forbidden are not the
  same answer, and a client cannot recover correctly when they are merged.
- A redirect or a cache-related code is not used to express an application outcome.

### Pagination

- A **consistent mechanism** across collections: page/limit or cursor, not both depending on the
  endpoint.
- The metadata is sufficient to page through — a client can tell whether more exists and how to ask
  for it — without guessing from a short page.
- **Ordering is stable and total**, so pages do not overlap or skip rows as data changes. Sorting by a
  non-unique column with no tiebreaker is a finding.
- Limits are bounded; an unbounded page size is a contract hole here and a load problem elsewhere.

### Versioning and compatibility

- How a **breaking change is expressed** is decided somewhere: a version segment, a media type, an
  additive-only rule. "It has never come up" is the absence, and the absence is the finding.
- Whether a client pinned to the current shape would break **silently**: a removed field, a narrowed
  type, a renamed key, a status code that changed meaning.
- Deprecation signalling, if any exists — a marked-deprecated field or endpoint still returned, with
  no stated removal path.

### Client-server agreement

- What the client's **own request/response types claim** versus what the server actually returns.
- A client parsing a field the server never sends — the client's type is a fiction and the code path
  depending on it is dead or crashing.
- A client ignoring an error case the server can produce, so that failure surfaces as a blank screen
  or a stuck state.
- Request direction too: a required parameter the client never sends, or an optional one it always
  sends and the server ignores.

## 2. Impact dimensions

Severity is graded by contract impact, never by code shape. The scale itself lives in
`../../core/report-model.md`.

- **blocker** — a client cannot reliably tell success from failure, or a documented contract is
  contradicted by the implementation on a **primary** path.
- **major** — an inconsistency a client must special-case: a shape, a code, or a pagination rule that
  differs for one endpoint and forces branching that should not exist.
- **minor** — cosmetic or documentation-level divergence with no behavioural consequence: a stale
  description, an unused declared field, an inconsistent name that nothing depends on.

## 3. What this domain does NOT cover

- **Whether an endpoint should be reachable at all, and what it discloses**, belongs to
  `auditing:security` — authentication, authorisation, over-fetching sensitive fields. This domain
  owns only whether the *shape and the code* of the answer are consistent and honest. Both files
  state this seam.
- **The storage shape behind the response** belongs to `auditing:data` — constraints, types at rest,
  nullability in the schema. This domain owns the shape on the wire. Both files state this seam.
- **Timeout and retry behaviour of a call** belongs to `auditing:reliability` — what happens when the
  call is slow, fails, or is repeated. This domain owns what a successful or failed answer looks like,
  not how it is retried.
- **Whether the endpoint set serves the product's flows** belongs to `auditing:business-analysis` — a
  missing capability is its finding, an incoherent shape is this one's.
- Response size, payload weight and request volume belong to `auditing:performance`.

## 4. How to audit

Static reading only. Do **not** call a live endpoint, start a server, or generate a client.

1. Read the **route definitions** first: they enumerate the surface and bound the audit.
2. Read the **controllers/handlers** for what each route actually returns, including its failure
   branches, and the **serialisers/resources** for the shape it returns them in.
3. Read the **client's request layer**: its request builders, its response types, its error handling.
4. Read the **schema** if one exists — in full contract mode it is the declared contract and takes
   priority over both implementations, per the source priority in `../../core/report-model.md`.
5. **Establishing an inconsistency means citing two locations.** A contract finding with one location
   quoted is not evidence — it is a suspicion. In full contract mode and client-internal mode those
   two are the two sides of the wire, or a schema locator plus an implementation locator. In
   **contract-document-only** mode there is no second side to cite and the rule does not relax into
   one locator: the two locations are both **inside the document** — the two endpoints whose error
   shapes disagree, the two collection responses paginated differently, the declared type and the
   example that contradicts it. A finding that would need an implementation to prove is not available
   in this mode; coverage says so instead of the report implying it.
6. An absent convention — no error format, no pagination rule, no versioning decision — has no
   `file:line`. Use the `expected surface absent` locator, naming where the convention was expected
   and how you established it is not declared elsewhere.
7. What makes a finding rather than a note: a consumer would have to change behaviour, special-case
   an endpoint, or guess. Stylistic disagreement with a consistently applied convention is not a
   finding.

## 5. Knowledge tiers

- **Tier 1 — universal contract invariants.** Consistent shapes, one branchable error format, codes
  that match outcomes, total ordering under pagination, no silent breaking change, both sides
  agreeing.
- **Tier 2 — the detected stack's documented conventions.** The server framework's own idioms for
  resources/serialisers, validation-error shape, status-code helpers and route conventions; and the
  client library's conventions for typing and error propagation.
- **Tier 3 — codified project conventions.** For a Vue client, `knowledge-vue:http-request` and
  `knowledge-vue:tanstack-query` supply the project's request-layer and caching conventions when those
  skills are available this session. No plugin codifies the server side of the contract today. Every
  such dependency is soft: absent means tiers 1 and 2 run normally plus one coverage line naming the
  missing tier.

## 6. Report

Read `../../core/report-model.md` and follow it as written; nothing from it is restated here.

- Finding-id prefix: **`API`** — `API-1`, `API-2`, …
- State which of the three modes the run used — full contract, client-internal consistency, or
  contract-document-only — in the report's scope declaration and again in coverage. In
  contract-document-only mode coverage also states that no implementation side was visible, so
  nothing in the report is a claim about what the server returns or what the client sends.
- `remediating skill` is fully qualified when a skill owns the fix — a client-side request-layer fix
  may be owned by `knowledge-vue:http-request` — and left empty when none does.
- Never read `panel-integration.md`: that is dispatcher-only.
