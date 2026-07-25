---
name: module-boundaries
description: Use when a caller reaches into another module's internals — importing an internal path instead of the entry point, chaining through one object to a second object's fields, exporting everything from an index, leaking a vendor or ORM type across a layer, or a module that changes for two unrelated reasons.
---

# Rule 4 — Depend on the contract, not the structure

[invariant · desired] A caller may depend on what a module **promises** and on nothing else. The
declared surface is the contract; field layout, storage choice, helper functions, and file
organisation are structure, and structure changes without notice. Every dependency on structure is a
break waiting for someone else's refactor. This rule is the whole of the boundary question — it
consolidates separation of concerns, cohesion, coupling, encapsulation, single responsibility,
interface segregation, and the Law of Demeter into one test each.

## What this rule requires

- **Callers use the declared surface only.** The module's entry point, its exported functions, types,
  and events. Anything not exported is not available, and anything exported is a promise you now have
  to keep.
- **No reaching through.** You may ask the object you hold for what you need; you may not navigate
  through it into a second object's internals. Diff test: more than one dot into a *foreign* object's
  data is a boundary break. A fluent API you own, chained on itself, is not.
- **The surface is as narrow as real consumers need.** Export what someone calls today. An export
  whose only caller is gone is deleted; public-by-default is a boundary defect. A consumer that needs
  three of a twenty-method surface should be given the three.
- **The "one reason to change" test** — the named test that carries the surviving content of SRP.
  List the reasons this module would have to change. If two of those reasons come from **different
  owners** — different stakeholders, different domains, different release cadences — the module has
  two reasons and should be two modules. The converse is the cohesion half: code that always changes
  together belongs together, and splitting it invents a boundary that has to be crossed on every
  edit. Apply it as a question with a listable answer, never as a judgement about tidiness.
- **Dependency direction: policy names, mechanism satisfies.** The domain declares the capability it
  needs; the adapter, the client, the driver conforms to it. Vendor and framework types stop at the
  adapter. *When* that abstraction is created is not decided here — that is timing, and the
  `abstraction` skill owns it. Direction here, timing there: the two together are the whole of DIP,
  and neither is complete alone.

## What violates it

- ❌ don't: import `feature/internal/helpers` from another feature.
  - ✅ do: import the feature's entry point, and add an export there if the need is real.
- ❌ don't: `order.customer.address.city` inside a handler.
  - ✅ do: ask the order for what you need — `order.shippingCity()` — and let the order module own the
    walk.
- ❌ don't: return a live ORM model or a vendor response object out of a repository into domain code,
  so the domain now depends on the driver. (Where a framework idiom is built on exactly that model —
  active record, framework-native collections — the idiom wins; see the conflicts table.)
- ❌ don't: re-export a module's entire internals from its index "so imports are shorter".
- ❌ don't: one module that changes when the tax rules change **and** when the PDF layout changes.
  - ✅ do: two modules, one owner each, meeting at a stated contract.
- ❌ don't: a shared `utils` bucket that every layer imports and every feature extends — it has no
  owner, so it has no contract.
- ❌ don't: reproduce a module's internal invariant at a call site (re-deriving a status, re-applying a
  rounding rule) because the module did not expose it.

## What this rule does not claim

- **SRP, ISP, cohesion, and SoC are folded into one boundary question, and their separate
  vocabularies are gone.** Do not report "this violates ISP" or "poor cohesion" — those labels are
  not part of this plugin's language. Report the checkable thing instead: which contract is being
  bypassed, or which module has two reasons to change. The loss is real: the four ideas had four
  different diagnostic flavours, and this rule keeps only their tests.
- **It does not prescribe a module size or a file layout.** No line count, no file-per-class, no
  folder shape, no layer names, no hexagonal or clean-architecture mandate. Where code lives is a
  project convention, band 1 — read `../../core/precedence.md`. A one-function module and a
  four-hundred-line module can both be correct here.
- **It does not claim every dependency must be inverted.** Inversion earns its cost where the
  dependency crosses out of the process, or where two owners meet. A domain function calling another
  domain function directly is correct; wrapping it in an interface for symmetry is speculative
  generality and rule 2 (`abstraction`) rejects it.
- It does not claim a module may have only one public function, or that a narrow surface must stay
  narrow forever. Surfaces grow with real consumers.

## Conflicts and how they resolve

Read `../../core/precedence.md` wherever precedence decides the question.

| Pulls against | Resolution |
|---|---|
| Rule 2 (`abstraction`) — DRY against decoupling | decoupling wins: two similar shapes in two modules is cheaper than one shared shape that couples them |
| A framework idiom that crosses the boundary by design (active record, container-resolved services, framework collections in the domain) | the idiom wins, band 2 — architectural purity does not get a vote there |
| A convention defining module layout, barrels, or entry-point shape | the convention wins, always |
| Rule 1 (`clarity`) | a narrow surface sometimes costs a mapping step; the answer is to name that step, not to skip the boundary |
| Rule 3 (`boy-scout`) | a boundary break outside your touched lines is reported, not repaired in this diff |
| Rule 8 (`performance`) | crossing a boundary is not a measured cost until it is measured; without a measurement, the boundary stands |

This rule is silent at proportionality level 1. Read `../../core/proportionality.md`.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
