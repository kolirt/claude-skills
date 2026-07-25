---
name: state
description: Use when adding or changing state — a store, a cached value, a status flag, a field on a shared object, a value passed between layers — or when reviewing duplicated state kept in sync by hand, in-place mutation of an argument, or a cluster of booleans that encodes a status.
---

# Rule 6 — Single source of truth; never mutate what you do not own; illegal states unrepresentable

[invariant · desired] **Every piece of state has exactly one owner, nothing mutates what it does not
own, and illegal combinations are impossible to construct.** Three obligations with one subject: who
is allowed to hold a value, who is allowed to change it, and which combinations are allowed to exist
at all.

## What this rule requires

### One owner; every reader derives

- Each piece of state lives in exactly one place. Every other consumer reads it or derives from it.
  It does not keep a second copy that has to be kept in sync.
- Derived values are computed from the owner, not stored beside it. A total, a count, a "has items"
  flag, a formatted label — all derivations.
- If two places need the value, one of them owns it and the other reads it. "Both get updated by
  whoever remembers" is not an ownership model.

### Never mutate what you do not own

- A value received from a caller, read out of a store, or reached through a shared structure is not
  modified in place. Return a new value, or ask its owner to change it.
- Ownership is the test, not immutability. A value you constructed locally is yours — mutate it
  freely until you hand it out. Once it is someone else's, it is read-only to you.
- Handing a mutable internal structure out of a module is the same defect from the other side: the
  module has given away control of its own state.

### Illegal states unrepresentable

- Prefer a shape in which the invalid combination cannot be constructed over a shape that is
  valid-by-convention and checked afterwards.
- One discriminated status beats a set of independent flags. Three states expressed as three
  booleans admit eight combinations, five of which are bugs waiting to be written.
- A field that exists only in one state belongs inside that state, not next to it. The failure
  message belongs on the failure case, not as a nullable sibling of the result.
- Where the type system cannot express the constraint, the obligation degrades to exactly one
  validated constructor that every instance passes through. It does not degrade to nothing.

## What violates it

- Duplicated state that a human has to keep in sync.
  - ✅ do: store the selected id; derive the selected object by lookup.
  - ❌ don't: store the selected id *and* a copy of the selected object, updated at each call site.
- Mutating an argument or a shared object.
  - ✅ do: return a sorted copy.
  - ❌ don't: sort the array the caller passed in and return nothing.
- Booleans that encode a state machine — three flags with only two legal combinations.
  - ✅ do: one `status` value with the states named.
  - ❌ don't: `isLoading` + `isError` + `isEmpty` maintained independently.
- A `loading` flag that can be true alongside a settled result, so both branches can render at once.
- A cache that no code path invalidates, silently becoming a second, older source of truth.
- Reading a value once into a local and continuing to trust it after the owner may have changed it.

## What this rule does not claim

- **It does not claim all data must be immutable.** A mutable local that you own is fine, and so is
  building up a structure in place before handing it out. The obligation is about ownership, not
  about a persistent-data-structure style.
- **It does not prescribe a state-management library or a store shape.** Which store, which
  reactivity model, whether state is centralised or per-module — all band 1. Read
  `../../core/precedence.md`; if the project has a convention, that convention wins outright.
- **It does not claim every illegal state can be typed away in every language.** Where the type
  system cannot express the constraint, the obligation degrades to one validated constructor, not to
  nothing — but this rule does not demand a type-level proof the language cannot give.
- **It does not own error representation.** How a failure is signalled and where it is handled is
  rule 5 (`errors`); this rule only requires that a failure state and a success state cannot be
  simultaneously representable.

## Conflicts and how they resolve

Read `../../core/precedence.md` first. A convention that mandates a store, a duplication for a cache
layer, or a mutable builder has already settled the question, and this rule has no vote there.

- **vs rule 8 (`performance`).** Immutability by default. A mutable exception — mutating in place to
  avoid a copy — requires a measurement, per rule 8. No measurement, no exception.
- **vs rule 4 (`module-boundaries`).** Single ownership and encapsulation agree: the owner exposes a
  contract for reading and a contract for changing, never the raw structure. Where they seem to
  disagree, the boundary wins — do not reach through a module to "reach the single source".
- **vs rule 1 (`clarity`).** A discriminated status is usually clearer as well as safer. Where making
  a state unrepresentable would demand type machinery a reader cannot follow, take the validated
  constructor instead and keep the reading direct.
- **vs a framework's mutable-by-design API.** Band 2 idiom wins. Mutating the object a framework
  hands you for exactly that purpose is not a violation; it is the API.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
