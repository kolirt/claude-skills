---
name: business-analysis
description: Use on demand to audit a WHOLE application through business-analyst / product-owner eyes — 'business audit', 'бізнес-аудит', 'product holes', 'бізнес-діри', 'монетизація', 'product integrity', 'audit the product', 'what is missing in the product'. Reconstructs the product model from code and reports broken flows, entities without lifecycle, monetization leaks, and intent-vs-implementation contradictions. Read-only — reports findings, never fixes them. Not a code-bug hunt, not a security or performance review. Audits of a PR diff or a set of changes belong to the auditing-prs plugin.
---

# Business-analysis audit

Judges whether the application is a **coherent product**, not whether its code is correct: broken
or dead-end journeys, entities without a lifecycle, monetization that leaks or is absent where the
product evidently intends it, and places where the implementation contradicts the stated intent.

The separating sentence: this domain owns **whether the product is whole** — not whether a given
path crashes, is slow, or is exploitable; those are a neighbour's finding on the same code.

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. The snapshot is produced by the detection script it documents.
Under the dispatcher the **snapshot** arrives as an input: detection is not repeated, and this domain
does not disagree with the facts it was handed. Invoked directly, this domain runs the detection
script itself first.

This domain reconstructs a product model from whatever code exists, so it has almost no hard stack
dependency. It is applicable to nearly any repository that declares a `manifest` or has a product
surface at all, and it rarely reports `skipped: not applicable` — say that plainly rather than
inventing a stack dependency this domain does not have.

| Fact needed | Used for | When absent |
|---|---|---|
| `ui` or `server` (a product surface), or `manifests` (the unit declares a package), or any other surface | Establishes there is a product to reconstruct a model from at all, and locates where a feature or flow begins for the feature map | `skipped: not applicable` only when the unit declares no manifest AND has no surface at all — nothing declared and nothing built (a documentation or configuration tree). Everything else is `your call`, never a skip: a manifest with neither `ui` nor `server` (a CLI tool, a library, a package), and a manifestless unit carrying only a non-product surface such as `data_schema`, `api_contract`, `i18n` or `test_harness` — a schema or a contract still encodes a product's entities and promises |
| `data_schema` | Locating entity definitions for the lifecycle check | Entities reconstructed from whatever persistence code exists directly; if none exists at all, that absence is part of the model, not a skip |
| `convention_plugins` | Whether knowledge tier 3 exists this run | Tiers 1 and 2 run; a coverage line names the missing tier |

The verdict vocabulary belongs to the dispatcher, not to this table: a unit with `ui` or `server` and a
product/strategy description supplied is `recommended` there, and this section describes only the
**reduced** shapes and how far the audit still reaches in each.

The closest this domain comes to `not applicable` is a unit with no surfaces at all and no manifest —
nothing declared, nothing built. Every other reduced shape is `your call` with the audit scoped down
and the reason stated: a `manifest` with neither `ui` nor `server` (a CLI tool, a library, a package), and a
manifestless unit carrying only a non-product surface — a bare `data_schema` still names the entities
a product is built on, and a bare `api_contract` still states the promises it makes to a caller. Scope
the audit to what that unit actually declares; do not skip the domain outright without saying why.

## 1. What this domain judges

### Product model reconstruction

Build this before hunting for holes — findings are differences against the model, so it has to
exist first. State it briefly in the report; it is what makes the findings auditable by the reader.

- **Feature map** — what the application lets someone do, in product terms, not module names.
- **Entities and their lifecycles** — the things the product manages, and for each: how it comes
  into existence, how it changes state, how it ends (closed, cancelled, archived, deleted, expired).
- **Interactions** — which features touch which entities, and where features depend on each other.
- **Monetization points** — where money is supposed to enter or leave: paid gates, plans, limits,
  quotas, trials, billing events. If none exist at all, that is a finding in itself, not an omission
  in the model.

### Broken or dead-end flows

A journey that starts and cannot be completed, or completes into nothing: a state with no exit, a
success path with no confirmation, a step referencing a surface that does not exist.

### Entities without a complete lifecycle

Created but never deletable, activated but never deactivatable, a state that can be entered but not
left, no owner for a terminal transition.

### Monetization leaks or absences

A paid capability reachable without payment, a limit that is displayed but not enforced, a trial
that never terminates, a plan whose difference is not actually implemented, or a product that
evidently intends revenue and has no mechanism for it.

### Intent-vs-implementation contradictions

Documentation or user-visible copy promising behaviour the code does not implement, or implementing
the opposite. This is where the evidence-source priority in the report model pays off.

### Implemented but unreachable

A feature that exists in full and has no path to it from any entry point. Either the product lost
it, or it is dead weight; both are worth reporting.

For each candidate finding, establish the **mechanism** — the causal chain from this code (or this
absence) to the business impact. A finding whose mechanism cannot be stated is an observation, and
belongs in Opportunities or nowhere.

## 2. Impact dimensions

Severity is graded by business impact, never by code shape. The scale itself lives in
`../../core/report-model.md`; these are its meanings here.

- **Money loss** — revenue that the product intends to collect and does not, or spends and should not.
- **User lockout** — a user cannot reach or complete something the product evidently offers them.
- **Monetization leakage** — value delivered without the corresponding paid gate, or a paid gate that
  does not actually gate.
- **Frequency and reach** — how many users hit it, how often, and whether it is on a core path or an
  edge case.

## 3. What this domain does NOT cover

- **Bugs and crashes** — a broken code path that fails regardless of business meaning is
  `auditing:code-quality`'s finding; this domain's finding is the broken *user journey*, not the
  exception behind it.
- **Availability** — whether the system stays up, degrades gracefully, or recovers is
  `auditing:reliability`'s domain entirely.
- **Security enforcement** — whether a gate actually restricts access is `auditing:security`'s
  finding; this domain owns whether the gate should exist at all and whether it reflects the
  intended plan difference. Where a paid feature is reachable without payment, `auditing:security`
  owns the fact that access control failed and this domain owns the fact that a monetization
  boundary was intended there in the first place.
- **Performance** — response times, query cost, and resource use are `auditing:performance`'s
  domain; a slow flow is this domain's finding only when it is slow enough to be a dead end nobody
  completes.
- **Storage invariants** — `auditing:data` owns whether the schema enforces what it claims
  (nullability, uniqueness, cascade behaviour); this domain owns whether the entity's *business*
  lifecycle exists at all, independent of how well the schema enforces it.
- **API contract correctness** — request/response shape, versioning, and schema conformance are
  `auditing:api-contracts`'s domain; this domain treats an endpoint only as a step in a user-facing
  flow.
- **SEO and accessibility** — owned entirely by `auditing:seo` and `auditing:accessibility`; not
  touched here even when a discoverability gap has business consequences.

## 4. How to audit

Work **stack-neutrally** — do not assume a framework. Establish how this particular project is
organized before drawing conclusions from it.

1. Find the entry points and the project's own conventions: build/run configuration, routing or
   command surfaces, module layout, and any convention documents the repo carries.
2. Collect repository documentation as a truth source: README, `docs/`, specs, ADRs, changelogs.
3. Obtain the product/strategy description — what the product is meant to be, who pays, what the
   important flows are. Two paths, never mixed:
   - **Standalone run** — ask the user once, at the start. Make clear it is optional and proceed
     either way; do not block on an answer and do not ask again later.
   - **Orchestrated run (under `audit`)** — a parallel subagent cannot prompt the user. The
     dispatcher asks for this description **after the domain selection**, once this domain is known to
     be running, and hands it down as an **input**; this domain never asks for it and never re-asks.
   - If it arrives empty under either path, that is a recorded coverage fact, not a reason to stop:
     evidence priority falls to repository documentation and code reconstruction.
4. Record which of the three evidence sources were actually available — the report must disclose it.
5. Build the product model (section 1) before running any detection pass over it.
6. For each candidate finding, state the mechanism from code (or absence) to business impact before
   filing it.

**Establishing absence.** A missing lifecycle exit, gate, or confirmation has no `file:line`; use
the `expected surface absent` locator from `../../core/report-model.md`, state where it was
expected, and state how its absence was established — a shared base flow, a generic handler, or a
different module all count as "elsewhere" and must be checked before absence is asserted.

**A note on what a single repository can prove.** An entity's lifecycle may be closed by a service
that is not in this codebase, and a monetization path may live in a payment provider's configuration
rather than in the code. Where a finding's mechanism depends on nothing existing elsewhere, say so
explicitly and let it temper confidence (section 6) rather than asserting the gap as certain.

## 5. Knowledge tiers

- **Tier 1 — universal product-integrity invariants.** Every entity has a path to closure, every
  flow that begins has a completion or an explicit dead end by design, every paid gate that exists
  actually gates. Always applied.
- **Tier 2 — ecosystem general practice.** The model's own knowledge of how products of the detected
  kind (subscription SaaS, marketplace, content platform, …) normally shape lifecycles and
  monetization — trials terminate, cancellation exists next to subscription, a quota that is shown
  is enforced.
- **Tier 3 — codified project conventions.** No `knowledge-*` plugin in this marketplace codifies a
  project's own product or domain conventions today — say so plainly and record it as a coverage
  line rather than implying the check ran. Should such a plugin exist in a session, the dependency is
  **soft**: its absence never blocks tiers 1 and 2.

## 6. Report

Read `../../core/report-model.md` and follow it exactly — output location, finding fields, evidence
locators, severity and confidence, opportunities, run comparison, and the mandatory coverage section.
Nothing from it is restated here.

- **Finding-id prefix: `BA`** — `BA-1`, `BA-2`, … stable within the report.
- Confidence follows the evidence priority the report model already fixes: the product/strategy
  description outranks repository documentation, which outranks reconstruction from code alone.
- **Remediating skill.** A business-integrity finding is usually a bespoke product decision with no
  owning convention skill in this marketplace; leave the field empty in that case rather than
  forcing a match. Name a fully-qualified `knowledge-*` skill only when the fix is genuinely a
  delivery-layer convention (for example, wiring a missing cancellation action through an existing
  form pattern).
- Opportunities here are typically proactive monetization or flow ideas the product does not yet
  pursue — mark them per the report model, never mixed into findings.
- The bridge to fixing is `auditing:remediate`. This audit names findings and stops.
