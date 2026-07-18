---
name: business-analysis
description: Use on demand to audit a WHOLE application through business-analyst / product-owner eyes — 'business audit', 'бізнес-аудит', 'product holes', 'бізнес-діри', 'монетизація', 'product integrity', 'audit the product', 'what is missing in the product'. Reconstructs the product model from code and reports broken flows, entities without lifecycle, monetization leaks, and intent-vs-implementation contradictions. Read-only — reports findings, never fixes them. Not a code-bug hunt, not a security or performance review. Audits of a PR diff or a set of changes belong to the auditing-prs plugin.
---

# business-analysis — whole-application product audit

Look at the application the way a business analyst or product owner would: not "is this code
correct" but **"is this a coherent product, and where are the holes"**.

The deliverable is a reconstruction of the product as it actually exists in code, plus the places
where that product is incomplete, self-contradictory, or leaking value.

## What this is and is not

**Is:** a product-integrity audit. Broken and dead-end user journeys, entities that can be created
but never closed out, monetization that leaks or is absent where the product evidently intends it,
and implementations that contradict the stated intent.

**Is not:** a bug hunt, a code-quality review, a security audit, or a performance review. A crash is
somebody else's finding. "Users can subscribe but there is no path to cancel" is this skill's
finding.

**Read-only.** See `../../core/report-model.md` — the audit changes nothing in the repository.

## Impact dimensions (how severity is graded here)

Grade every finding by business impact, never by code shape:

- **Money loss** — revenue that the product intends to collect and does not, or spends and should not.
- **User lockout** — a user cannot reach or complete something the product evidently offers them.
- **Monetization leakage** — value delivered without the corresponding paid gate, or a paid gate
  that does not actually gate.
- **Frequency and reach** — how many users hit it, how often, and whether it is on a core path or an
  edge case.

Map onto the shared `blocker | major | minor` scale in the report model accordingly.

## Method

### 1. Gather evidence

Work **stack-neutrally** — do not assume a framework. Establish how this particular project is
organized before drawing conclusions from it.

- Find the entry points and the project's own conventions: build/run configuration, routing or
  command surfaces, the module layout, and any convention documents the repo carries.
- Collect repository documentation as a truth source: README, `docs/`, specs, ADRs, changelogs.
- **Ask the user once, at the start**, for an optional product/strategy description: what the
  product is meant to be, who pays, what the important flows are. Make clear it is optional and
  proceed either way — do not block the audit on an answer, and do not ask again later.

Record which of the three sources you actually had; the report must disclose it.

### 2. Reconstruct the product model

Build the model before hunting for holes — findings are differences against this model, so it has
to exist first.

- **Feature map** — what the application lets someone do, expressed in product terms, not module
  names.
- **Entities and their lifecycles** — the things the product manages, and for each: how it comes
  into existence, how it changes state, how it ends (closed, cancelled, archived, deleted, expired).
- **Interactions** — which features touch which entities, and where features depend on each other.
- **Monetization points** — where money is supposed to enter or leave: paid gates, plans, limits,
  quotas, trials, billing events. If none exist at all, that is a finding in itself, not an
  omission in the model.

State the model briefly in the report. It is what makes the findings auditable by the reader.

### 3. Detection passes

Run each pass over the reconstructed model:

- **Broken or dead-end flows** — a journey that starts and cannot be completed, or completes into
  nothing: a state with no exit, a success path with no confirmation, a step referencing a surface
  that does not exist.
- **Entities without a complete lifecycle** — created but never deletable, activated but never
  deactivatable, states that can be entered but not left, no owner for terminal transitions.
- **Monetization leaks or absences** — a paid capability reachable without payment, a limit that is
  displayed but not enforced, a trial that never terminates, a plan whose difference is not actually
  implemented, or a product that evidently intends revenue and has no mechanism for it.
- **Intent-vs-implementation contradictions** — documentation or user-visible copy promising
  behaviour the code does not implement, or implementing the opposite. This is where the source
  priority in the report model pays off.
- **Implemented but unreachable** — a feature that exists in full and has no path to it from any
  entry point. Either the product lost it, or it is dead weight; both are worth reporting.

For each candidate finding, establish the **mechanism** — the causal chain from this code (or this
absence) to the business impact. A finding whose mechanism you cannot state is an observation, and
belongs in Opportunities or nowhere.

### 4. Opportunities

Separate section, per the report model: proactive product ideas, explicitly marked as judgment
rather than fact, carrying no severity. Say what they assume about goals nobody stated.

### 5. Report

Produce the report per `../../core/report-model.md` — scope and evidence-source declaration,
findings with evidence locators, opportunities, and the mandatory coverage/blind-spots section.

Confidence follows the truth-source priority: a finding confirmed by the user's own description of
the product is `high`; one visible in code with no external confirmation is `medium`; one resting on
a reconstruction of what the product *probably* intends is `low`. Do not raise confidence because a
finding feels obvious.

Blind spots deserve real specificity here: a single repository is usually one part of a larger
system, so an entity's lifecycle may be closed by a service you cannot see, and a monetization path
may live in a payment provider's configuration rather than in this code. Say so, and say which
findings would be invalidated if that turned out to be the case.
