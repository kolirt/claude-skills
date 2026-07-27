---
name: naming
description: Use when naming a function, variable, type, module, or flag, or when reviewing a name that describes its implementation instead of its purpose — and when a signature hides what it reads or changes — ambient singletons, global reads, unannounced side effects, a helper that quietly writes.
---

# Rule 7 — Name the intent; make effects and dependencies explicit

[invariant · desired] **A name states what the thing is for, and a signature discloses what the thing
needs and what it changes.** Reading a call site is enough to know the purpose, the inputs, and the
consequences. Anything a caller cannot see from the call site is a defect, not a convenience.

## What this rule requires

### Name the intent, not the mechanism

- A name says what the thing is for, in the vocabulary of the problem. It does not describe the data
  structure, the algorithm, the library, or the loop that happens to be inside today.
- The name survives a rewrite of the implementation. If replacing a map with a query forces a rename,
  the name was describing the mechanism.
- One concept, one word, across the codebase. The same idea named three ways reads as three ideas.
- Length follows scope: a two-line block tolerates a short name; a module-level export does not.

### Disclose what it needs

- A function's parameters are what it needs. A dependency reached through a global, a module-level
  singleton, an ambient context, or a static accessor is a hidden input, and the caller cannot see it.
- A function that behaves differently depending on state it never received is not testable and not
  readable. Make the dependency a parameter, or make the reliance explicit in the type.
- Configuration and environment are inputs like any other. Reading them deep inside a call chain
  hides them from every caller above.

### Disclose what it changes

- Any effect a caller would care about — a write, a network call, a mutation of an argument, a
  cache eviction, a log that something depends on — is visible from the signature and the name.
- A name that reads as a pure question does not perform a write. A getter that lazily persists, a
  validator that normalises the input, a formatter that increments a counter: all surprises.
- A boolean parameter that switches behaviour hides a second function inside the first. Name the two
  behaviours instead.

## What violates it

- A name describing construction rather than purpose.
  - ✅ do: `activeSubscribers`
  - ❌ don't: `filteredUserArray`
- A dependency read from ambient state.
  - ✅ do: pass the clock, the current user, the config in.
  - ❌ don't: reach for a global singleton in the middle of a domain function.
- An effect invisible at the call site.
  - ✅ do: `loadProfile()` for something that performs I/O.
  - ❌ don't: `profile` as a property getter that issues a request on first read.
- A name that lies by omission: `validate` that also trims and rewrites the input; `find` that also
  creates the record when it is missing.
- Vague names that carry no intent — `data`, `info`, `handle`, `process`, `manager`, `util` — where a
  concrete one exists.
- Negated names combined with negation at the call site (`if (!isNotReady)`).
- An abbreviation that is not already the domain's own word.

## What this rule does not claim

- **CQS survives only as "a function does exactly what it promises".** The stricter
  command/query separation — a function either returns a value or changes state, never both — is
  deliberately **not** enforced here. A function may return the record it created, pop and return an
  item, or return the number of rows it wrote. The obligation is honest disclosure, not purity.
- **It does not prescribe a naming convention.** Casing, prefixes and suffixes, Hungarian shapes,
  `get`/`set` conventions, file-name style, whether booleans start with `is` — all of that is band 1
  or band 2 in `../../core/precedence.md`. A project convention or a framework idiom decides, and this
  rule has no vote once one exists.
- **It does not forbid dependency injection frameworks or module-scoped clients.** A container that
  makes a dependency explicit in the constructor satisfies this rule; the defect is the *hidden*
  read, not the indirection.
- **It does not require every effect to be pushed to the edges.** That structural question belongs to
  rule 2 (`abstraction`) and rule 4 (`module-boundaries`). Here, an effect merely has to be visible.
- **It does not claim a good name removes the need for a comment.** It claims the name must not
  contradict what the code does.

## Conflicts and how they resolve

Read `../../core/precedence.md` first. Where a convention or a framework idiom fixes a naming shape
or mandates an ambient accessor — a request-scoped context, a facade, a framework-provided global —
that decision stands and this rule does not reopen it.

- **vs rule 1 (`clarity`).** They pull the same way; when they disagree it is over length. A precise
  long name beats a short cryptic one, but a name so long that the call site stops being readable has
  traded one defect for another. Rule 1 decides at the call site.
- **vs rule 4 (`module-boundaries`).** Disclosure stops at the contract. A signature reveals what the
  caller needs to know, not the module's internals — naming the collaborators a caller must supply is
  disclosure; naming private mechanics in the signature is a leak.
- **vs rule 10 (`change-safety`).** A name is observable. Renaming a public symbol to satisfy this
  rule is a behaviour change under rule 10 — it needs the escape path there, not a silent edit.
- **vs a legacy vocabulary.** Consistency with the surrounding domain language beats a locally better
  name. Rename the concept everywhere, or keep the existing word; do not introduce a second synonym.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
