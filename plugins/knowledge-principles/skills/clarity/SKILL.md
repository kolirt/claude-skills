---
name: clarity
description: Use when writing or reviewing code a reader must understand with no context — nested expressions, chained ternaries, clever one-liners, implicit truthiness or coercion, a decision hidden in a default argument or an assignment inside a condition, or a construct whose correctness depends on knowing a language trick.
---

# Rule 1 — Clarity over cleverness

[invariant · desired] Code is written for the next reader, and the next reader is an agent or a
developer with **no context**: no memory of the discussion, no knowledge of what the author was
thinking, no author to ask. The code must be understandable on one pass, at normal reading speed, by
someone who knows the language but not this codebase. Where understanding costs a second pass, the
code is wrong even when the behaviour is right.

## What this rule requires

- **The direct reading.** A reader who reads the block once, top to bottom, arrives at what it does.
  No mental simulation of evaluation order, no consulting the language's coercion table, no reverse
  engineering from the tests.
- **Named intermediates over nested expressions.** When an expression composes more than one
  non-obvious step, each step gets a name that says what it is. The name is the explanation. A
  comment that translates an expression into English is evidence the expression should have been
  split.
- **No puzzle constructs.** If correctness depends on knowing a trick — precedence beyond ordinary
  arithmetic, evaluation order, the truthiness of an empty value, a short-circuit used as a
  statement, a side effect inside a ternary — write the trick out as ordinary control flow instead.
- **Every decision is visible at the line where it is made.** A branch, a guard, an early return: the
  reader can point at the code that chose.
- **One-sentence test.** State what the block does in one sentence without saying "and then it also".
  If you cannot, the block is doing two things — rule 4 (`module-boundaries`) applies as well.

## What violates it

- **Clever one-liners** that fuse a guard, a computation, and a return.
  - ✅ do: `if (!user) return null` on its own line, then the computation on the next.
  - ❌ don't: `return user && user.perms.length && grant(user)` — the return type changes with the
    input and the reader has to work out which value escapes.
- **Chained ternaries** standing in for a branch, or a ternary whose arms have side effects.
- **Implicit coercion carrying meaning.** Relying on `0`, `""`, an empty collection, and a missing
  value collapsing into one falsy branch when those cases mean different things.
  - ✅ do: test the condition you mean — the count, the presence, the emptiness.
  - ❌ don't: `if (!count)` when zero and absent must be handled differently.
- **Control flow that hides a decision:** a behavioural choice buried in a default argument value, an
  assignment inside a condition, an exception steering the normal path, a boolean parameter that
  flips what a function does (rule 7 (`naming`) owns how such a parameter must be named — this rule
  objects to the hidden branch itself).
- **A comment that restates the code** instead of code that needs no restating.

## What this rule does not claim

- **It does not claim short is clear.** Brevity is not the metric. A dense line and a ten-line block
  that reads straight through — the block wins. Line count, character count, and "fewer statements"
  are never arguments under this rule, in either direction.
- **It does not license rewriting working code for taste.** This rule governs code you are writing
  or already changing. Rephrasing a working, understood construct because you would have written it
  differently is diff expansion: rule 3 (`boy-scout`) limits cleanup to touched lines and rule 10
  (`change-safety`) forbids touching what you have not understood. A file of terse-but-working code
  is not a defect list.
- **It does not override an idiom the framework itself is clever about.** Where the normal way to
  express something in that stack is terse — a destructuring pattern, a pipeline, a macro, a
  framework's magic accessor — the idiom wins. It reads as clear to anyone fluent in the stack, and
  unrolling it makes the code stranger, not clearer. See `../../core/precedence.md`, band 2.
- **It does not define a style standard.** Line width, brace placement, import order, formatter
  configuration are band 1 — the project decides, and this rule has no vote.

## Conflicts and how they resolve

Read `../../core/precedence.md` wherever precedence decides the question.

| Pulls against | Resolution |
|---|---|
| A convention that mandates ceremony around trivial input | the convention wins; the ceremony is compliance, not clutter (`precedence.md`, worked example 2) |
| A framework idiom that is deliberately terse | the idiom wins, band 2 |
| Rule 2 (`abstraction`) | clarity is not a reason to extract an abstraction early. Naming intermediates is clarity; creating a module is rule 2's timing question |
| Rule 3 (`boy-scout`) and rule 10 (`change-safety`) | the minimal diff wins — an unclear line you did not touch stays untouched |
| Rule 8 (`performance`) | a measured hot path may justify a less direct construct; rule 8 requires the measurement, and the construct carries a comment naming it. Without a measurement, clarity wins |

This rule is active at every proportionality level, including level 1 — a throwaway script is read
by the next agent too. Read `../../core/proportionality.md`.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
