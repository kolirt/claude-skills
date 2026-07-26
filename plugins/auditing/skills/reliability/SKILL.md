---
name: reliability
description: Use on demand to audit whether an application keeps working when something goes wrong and whether anyone would know if it did not — 'reliability audit', 'аудит надійності', 'error handling review', 'what happens when this fails', 'observability', 'logging and monitoring gaps', 'retry and idempotency review'. Covers failure handling, idempotency, multi-step consistency, degradation, and observability across the whole application. Static read; reports findings, never fixes them, never runs or breaks anything. Not speed or cost (that is auditing:performance), not vulnerability hunting (that is auditing:security), not storage invariants (that is auditing:data), and not test coverage. Audits of a PR diff or a set of changes belong to the auditing-prs plugin.
---

# Reliability audit

Judges whether the application keeps working when something goes wrong, and whether anyone would know
if it did not. Observability is folded into this domain deliberately: an unhandled failure and an
invisible failure are the same defect seen from two sides.

The neighbouring domains ask whether the happy path is fast, secure, or correct. This one asks what
happens off the happy path, and who finds out.

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. Under the dispatcher the snapshot arrives as an input —
detection is not repeated and the snapshot is not argued with. Invoked directly, this domain runs the
script itself first.

| Fact needed | Why | When absent |
|---|---|---|
| `server` | Locates the outbound calls, handlers, jobs, retry and timeout logic, and logging surfaces | The failure-handling, idempotency, observability, and operational-surface sub-checks are `skipped: not applicable` |
| `ui` | Locates the degradation-visible-to-the-user questions — what the user sees when a dependency is unavailable | The degradation sub-checks are `skipped: not applicable` |
| `data_schema` | Tells whether a multi-step write has a transactional boundary available to it | The consistency-across-steps sub-checks are limited to what the code shows; recorded in coverage |
| `api_contract` | Names the outbound and inbound contracts whose failure modes are in scope | Enumerate calls from code instead; note the reduced certainty |
| `convention_plugins` | Supplies tier 3 (see section 5) | Tiers 1 and 2 run; coverage names the missing tier |

`server` absent removes the outbound-call, retry, job, and operational sub-checks; `ui` absent removes
the degradation-visible-to-the-user sub-checks; `data_schema` present on its own keeps the
consistency-across-steps sub-checks running — a unit with only a schema and no `server` or `ui` is
still auditable for multi-step write consistency, and does not read as `not applicable`. Only when
`server`, `ui`, and `data_schema` are **all** absent is there nothing to audit, and the whole domain is
`skipped: not applicable` there, wholesale rather than per sub-check. A required fact that is absent
produces `skipped: not applicable` with the reason, never an invented finding and never a guess at what
the finding would have been.

## 1. What this domain judges

### Failure handling at the edges

- Does every outbound call — HTTP, database, queue, cache, filesystem, third-party SDK — have a
  defined behaviour when it fails, and a separate defined behaviour when it never answers?
- Is there a timeout at all, and is it a deliberate value rather than an inherited default nobody
  chose?
- Is a retry bounded, backed off, and safe to repeat — or unbounded, immediate, or applied to an
  operation that must not run twice?
- Does a failure propagate as something the caller can act on, or is it flattened into a null, an
  empty list, or a generic success?
- Does a partial failure leave the system half-applied: two of three writes done, a notification sent
  for a transaction that rolled back, a file uploaded with no record of it?

### Idempotency and duplicate work

- Which operations can be delivered twice — a queue with at-least-once delivery, a webhook the sender
  will retry, a form the user can double-submit, a link that can be opened twice?
- Is each of those safe to apply twice: keyed by an idempotency token, guarded by a unique
  constraint, or written as a state transition that is a no-op the second time?
- Money and state transitions in particular: can a charge, a refund, a credit, a stock decrement, or
  a status change be applied more than once for the same intent?
- Does a job re-executed after a crash repeat side effects it already performed?

### Consistency across steps

- Does a multi-step operation that writes in more than one place have a defined outcome when a later
  step fails — a transaction, a compensating action, or an explicit decision to accept the drift?
- Are there writes that span systems a single transaction cannot cover (a database plus a queue, a
  database plus a payment provider, a database plus a file store), and what is the stated ordering?
- Can records be orphaned — a child written before its parent commits, a reference to a row that was
  never created, an upload with no owner?
- Does a job assume its trigger's state still holds by the time it runs, rather than re-reading and
  re-validating it?
- Is a side effect emitted before the state it describes is durable?

### Observability

- Does a failure produce a signal a human could act on, or does it end in a swallowed exception?
- Do errors reach somewhere durable — a log sink, an error tracker, an alert — rather than a browser
  console or a discarded stream?
- Does the signal carry enough context to identify the affected record, user, or request: an
  identifier, the operation, the inputs that matter?
- Is there any silent catch — a caught error with an empty body, a comment instead of handling, or a
  log line at a level nobody reads?
- Can a degraded state be told apart from a healthy one: does a health signal reflect the
  dependencies the application actually needs, or does it return success unconditionally?
- Are the failures that matter distinguishable from routine noise, or does everything log at the same
  level?

### Degradation

- What does the user see when a dependency is unavailable — a defined degraded state, or a blank
  screen, an infinite spinner, or a stuck disabled button?
- Is a non-essential dependency allowed to take down the page or the request that merely decorates?
- Does a failed load offer a way forward — a retry, a cached value, a reduced view — or a dead end?
- Does a form that failed to submit preserve what the user typed?

### Operational surface

- Is configuration that must be present for the system to run validated at startup, rather than
  failing at first use in front of a user — a missing key, an empty credential, an unset endpoint?
- Does a required value have an unsafe fallback that lets the application start in a broken state?
- Is a scheduled task's failure visible — does a job that stops running produce a signal, or does its
  silence look identical to success?
- Is there any process whose only failure indication is the absence of an expected effect?

## 2. Impact dimensions

Severity is graded by what a real failure would cost, never by how the code looks. The scale itself
lives in `../../core/report-model.md`.

- **blocker** — a single failure loses data, double-charges or double-applies money, or takes a
  primary path down with no recovery: an unguarded retry on a payment, a write path with no
  transactional boundary around a money transfer, a missing required config that fails only in
  production.
- **major** — a failure leaves inconsistent state that someone must repair by hand, or is invisible
  to operators: a half-applied multi-step write, an unmonitored scheduled job, a swallowed exception
  on a write path, a queue consumer with no failure destination.
- **minor** — a recoverable gap or a missing signal that does not hide a real failure: a log line
  without an identifier, a retry with no backoff on a read-only call, a degraded state that is
  correct but unhelpfully worded.

Reach matters: a failure mode on a core path, or one that triggers on ordinary conditions rather than
exotic ones, outranks the same shape on an edge.

## 3. What this domain does NOT cover

- **Speed and cost** — `auditing:performance` owns how long an operation takes, how much it costs,
  and how it scales. This domain owns behaviour under failure, and it owns the timeout as a
  **policy**: whether a bound exists and what happens when it is hit. How low that bound should be
  set for latency reasons is the performance domain's call. Both files state this split, so neither
  is read alone.
- **Vulnerabilities and disclosure** — `auditing:security` owns whether an error message discloses
  too much (a stack trace, an internal path, a credential in a log). This domain owns whether the
  failure is **observable at all**. Stated in both directions: an error rendered to the user with
  internals in it is a security finding; the same error reaching nobody is a reliability finding; an
  error that both leaks internals and never reaches an operator is reported once by each domain from
  its own side, and neither restates the other's judgment.
- **Storage invariants** — `auditing:data` owns schema-level guarantees: constraints, nullability,
  foreign-key delete behaviour, cascade semantics, migration safety. This domain owns the
  **multi-step write that can half-apply** and the runtime behaviour when a write fails. A missing
  foreign key is a data finding; a write sequence with no transaction around it is a reliability
  finding.
- **Contract shape** — `auditing:api-contracts` owns whether a response matches its declared schema.
  This domain owns what the caller does when the call fails or never returns.
- **Test coverage** — not audited. There is no `testing` domain in v1, so "this failure path is
  untested" is never a finding here. Coverage says plainly that test adequacy was out of scope.
- **Whether the feature should exist** — `auditing:business-analysis` owns that.

## 4. How to audit

Static reading only. No chaos testing, no fault injection, no running anything, no breaking a
dependency to see what happens.

1. Enumerate the **failure surface** first: every point where this codebase depends on something that
   can be slow, absent, or wrong — outbound clients, database access, queue producers and consumers,
   webhook receivers, scheduled tasks, file and cache access, third-party SDKs, and startup
   configuration reads.
2. For each surface, read the call site and then the layers around it. A wrapper, an interceptor, a
   middleware, a global handler, or a framework default may already supply the handling — check
   before concluding it is missing.
3. Trace the **write paths**: for each operation that writes in more than one place, follow it to the
   end and state what remains if step *n* succeeds and step *n+1* does not.
4. Trace the **signal paths**: for each failure the code does handle, follow the handling to its
   destination and establish whether it lands somewhere a human sees.
5. Establishing that a failure path is **missing** means reading the paths that could fail and
   finding no handling — in the call site, in its wrappers, and in any global handler. Use the
   `expected surface absent` locator from `../../core/report-model.md`, name where handling was
   expected, and name the layers you checked. Say plainly where this could not be exhaustive:
   handling may live in a framework default whose behaviour depends on configuration, in
   infrastructure outside the repository (a proxy timeout, a queue's own retry policy, a platform
   restart), or in a service this codebase only calls. Those go in coverage as blind spots.

A finding requires a stated mechanism: this dependency fails in this ordinary way, and this is the
resulting state or the resulting silence. A theoretical failure with no path to it is an opportunity,
not a finding. Confidence follows the report model: unverifiable infrastructure assumptions cap a
finding at `medium` or `low`.

## 5. Knowledge tiers

Tiers are defined in `../../core/report-model.md`; this section says what fills them here.

- **Tier 1 — universal invariants.** Every outbound call has a defined failure and timeout behaviour;
  a retried operation is idempotent; a multi-step write has a defined outcome on partial failure; no
  failure is silent; required configuration is validated before use; a degraded dependency produces a
  defined user-visible state.
- **Tier 2 — the framework's documented mechanisms.** The detected stack's own failure handling,
  transaction boundaries, queue and job retry semantics, exception reporting, and logging facilities,
  used as documented rather than reinvented at the call site.
- **Tier 3 — codified project conventions**, only when a `knowledge-*` plugin supplies them. The
  candidates are `knowledge-principles:errors` and `knowledge-principles:change-safety`. Both
  dependencies are **soft**: absent, the domain runs on tiers 1 and 2 and coverage records "tier 3
  unavailable" with the plugin named. That is a coverage fact, carrying no severity.

## 6. Report

Read `../../core/report-model.md` and follow it as written — output location, finding fields,
evidence locators, severity, confidence, opportunities, run comparison, the mandatory coverage
section, and the closing hand-off. Nothing from it is restated here.

- **Finding-id prefix:** `REL` — `REL-1`, `REL-2`, in report order.
- **Remediating skill:** every finding names the fully-qualified skill that owns the fix where one
  exists — `knowledge-principles:errors` for a handling or signalling defect,
  `knowledge-principles:change-safety` for a risky change path, a stack-specific data-access skill
  for a transactional boundary. Leave it empty when no skill owns the fix. The audit never applies
  the fix; `auditing:remediate` turns findings into a plan.
