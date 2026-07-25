---
name: abstraction
description: Use when deciding whether to extract, wrap, generalise, or leave code duplicated — a second or third similar block, a helper "for later", a generic base class with one subclass, a config flag with one value, or a raw HTTP call, filesystem read, clock read, random value, queue publish, or third-party SDK call sitting at a call site.
---

# Rule 2 — I/O boundaries abstract immediately; domain abstracts on the third real case

[invariant · desired] Abstraction is a **timing** question, and the timing depends on which side of
the process edge the code sits on. Anything reaching outside the process is wrapped at first use,
because the call site must never own a transport detail. Domain logic waits for a **third real
occurrence**, because two similar shapes are not yet evidence of one rule. Extracting earlier and
extracting later are both defects; this rule names the moment.

## What this rule requires

- **Wrap an outside-the-process boundary at first use.** No counting, no threshold. The boundary set:
  HTTP and any network call, storage (database, filesystem, cache, browser storage), the clock,
  randomness and id generation, queues and message buses, the environment and config, and every
  third-party SDK.
- **The wrapper's surface is the caller's need, not the vendor's shape.** Vendor types, error
  classes, and status codes stop at the wrapper. Rule 4 (`module-boundaries`) owns the direction of
  that dependency; this rule only says the wrapper exists from call one.
- **Domain logic waits for the third occurrence, and the occurrences must be real.** Real means:
  already written, on a production path, doing the same job for the same reason. A planned case, a
  case that exists only in tests, and a case someone might need next quarter do not count.
- **The counting discipline.** Occurrence 1: write it. Occurrence 2: write it again, and ask whether
  the two answer to the same owner. Occurrence 3: extract — only if all three change together, for
  one reason, on one owner's say-so.
- **A single business fact has a single home from the first duplication.** A tax rate, an eligibility
  threshold, a status vocabulary, a URL contract: if two places must be edited together or the system
  becomes wrong, that is one fact in two places, and it is a defect immediately.
- **No structure built for a case that does not exist.** No extension point, no type parameter, no
  strategy registry, and no config switch whose second value has never been requested.

## What violates it

- ❌ don't: `fetch(...)`, `new Date()`, `Math.random()`, `process.env.X`, a vendor SDK client, or a
  raw query builder call sitting directly in a handler, component, or domain function.
  - ✅ do: call the project's wrapper for that boundary — and where a convention already mandates
    one, use it rather than adding a second.
- ❌ don't: a generic base class, interface, or `<T>` with exactly one implementation added because a
  second "will come".
  - ✅ do: the one concrete implementation, extracted when the third case arrives.
- ❌ don't: extract a shared helper on the second occurrence when the two call sites belong to
  different features and answer to different owners.
  - ✅ do: leave the two shapes separate and let them drift — they were never one rule.
- ❌ don't: a feature flag, options object, or `mode` parameter with one live value.
- ❌ don't: an abstraction whose parameter list is the union of both call sites' needs, so every
  caller passes flags it does not care about.
- ❌ don't: the same threshold, rate, or status string literal in two modules.

## What this rule does not claim

- **DRY is reduced to a timing question here, and the distinction that survives is knowledge versus
  text.** Duplicated *knowledge* — one business fact expressed in two places that must change
  together — is a defect at the **first** duplication. Duplicated *text* — two blocks that merely
  look alike and change for different reasons, on different schedules, at different owners' request
  — **is not duplication at all**, and merging it creates a coupling that did not exist. Two
  occurrences of similar code that answer to different owners stay separate, permanently. "It looks
  the same" is never the argument; "it must change together" is.
- **DIP is covered here only as timing.** This rule says *when* an abstraction comes into existence.
  The "depend on abstractions, not concretions" **direction** — which side declares the contract and
  which side satisfies it — belongs to rule 4 and is stated in the `module-boundaries` skill. Timing
  here, direction there; the pair is complete only when both are read.
- **OCP is reframed as timing only.** "Open for extension, closed for modification" survives here as
  the instruction not to build the seam before the third case. The **design** question — how to shape
  an extension point well once it is warranted — is not covered by this rule or by any of the other
  nine. That gap is deliberate and recorded, not an oversight.
- **KISS is rejected as a rule.** It is not one of the ten and must not be cited as a finding. Rules
  2 and 4 already decide the same questions with checkable criteria — a real third case, a real
  contract — while "prefer the simple solution" is unfalsifiable and collides head-on with
  conventions that mandate indirection. The mandated request wrapper in `../../core/precedence.md`
  is exactly the case: under KISS it looks like excess; under band 1 it is compliance.
- It does not claim an abstraction must be small, or that a wrapper must be hand-written rather than
  a thin re-export. It claims only that the call site does not see the outside world directly.

## Conflicts and how they resolve

Read `../../core/precedence.md` wherever precedence decides the question.

| Pulls against | Resolution |
|---|---|
| A convention mandating a wrapper used by one call site | the convention wins; the wrapper is compliance (`precedence.md`, worked example 1) |
| Rule 4 (`module-boundaries`) — DRY against decoupling | decoupling wins: two similar shapes in two modules is cheaper than one shared shape that couples them |
| Rule 1 (`clarity`) | clarity is served by naming intermediates, not by extracting a module early |
| Rule 3 (`boy-scout`) | a duplication you did not touch is not yours to consolidate today |
| Legacy code predating the convention | not a violation, not reportable (`precedence.md`, legacy section) |

This rule is silent at proportionality level 1 — duplicated parsing in a spike is not a finding.
Read `../../core/proportionality.md`.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
