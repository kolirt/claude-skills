---
name: performance
description: Use when writing or reviewing code that touches data volume or a hot path — a query inside a loop, an unbounded list, repeated work per item, a blocking synchronous call — and when someone proposes an optimisation, a cache, a denormalisation, or a hand-rolled fast path.
---

# Rule 8 — Known slow patterns are defects; optimisation requires measurement

[invariant · desired] **A pattern already known to be pathological is a defect the moment it is
written; every other optimisation requires a measurement first.** The two halves are deliberately
asymmetric. One is a floor you may not sink below without evidence; the other is a gate you may not
pass without evidence.

## What this rule requires

### First half — the known-slow list needs no measurement

These are defects on sight. Do not write them, and do not leave them in a diff you touched.

- **A query inside a loop over a result set.** One query per row, or per item, where one query over
  the set would do. Fetch the related data in one round trip.
- **An unbounded result set.** A read with no limit, no pagination, and no ceiling — correct on
  today's data, an outage on next year's.
- **Work repeated per item that could be done once.** Recompiling a pattern, re-reading config,
  re-resolving a dependency, re-sorting an unchanged collection inside the loop body.
- **A synchronous call on a hot path that blocks everything behind it.** A remote call, a filesystem
  read, or a heavy computation placed where every request must wait for it.
- **An operation whose cost grows with total data rather than with the page.** Counting, summing, or
  filtering the whole table in application code to render twenty rows.

Fixing one of these is not "optimising". It is writing the thing correctly the first time.

### Second half — everything else is gated on a measurement

- Any other change made for speed — restructuring, adding a cache, denormalising, batching,
  precomputing, hand-rolling a faster path, trading immutability for in-place mutation — requires a
  measurement taken **before** the change.
- The measurement is **named in the change**: what was measured, on what input, and the number. A
  commit message, a comment at the non-obvious code, or the summary of the work. An unnamed
  measurement is the same as none.
- A cache additionally states what invalidates it. A cache with no stated invalidation is a
  correctness defect, not a performance improvement.
- Absent a measurement, choose the clearer implementation. Rule 1 (`clarity`) decides by default.

## What violates it

- Deferring a known-slow pattern because nothing has broken yet.
  - ✅ do: load the related records for the whole set in one query.
  - ❌ don't: loop the parents and fetch each child inside the loop, "for now".
- An unbounded read.
  - ✅ do: paginate, or cap with an explicit maximum and handle the overflow.
  - ❌ don't: fetch everything and slice in memory.
- An optimisation with no evidence behind it.
  - ✅ do: measure, record the number, then change the code.
  - ❌ don't: replace a readable transformation with an index-arithmetic loop because it "should be
    faster".
- A cache added to hide a query inside a loop instead of removing the loop.
- Micro-tuning inside a function whose cost is dominated by a remote call it makes.
- A benchmark that measures a case the product never runs.

## What this rule does not claim

- **"Premature optimisation is the root of all evil" is not a licence to write a known-slow
  pattern.** The maxim governs the second half of this rule only. The first half is not optimisation
  at all, and deferring it with that quotation is a misreading this rule explicitly rejects.
- **It does not set a performance budget or a target.** Latency targets, throughput goals, payload
  ceilings, and Core Web Vitals thresholds are project facts — band 1 in `../../core/precedence.md`.
  This rule never invents a number.
- **It does not name a profiler, a benchmark harness, or a measurement methodology.** Which tool,
  which environment, how many runs: the project decides. This rule only requires that a measurement
  exist and be named.
- **It does not claim slow code is always the algorithm's fault.** Diagnosis is the measurement's job.
- **It does not rank the known-slow list.** All five are defects; none is a lesser offence.
- **It does not cover systematic performance auditing outside the current diff.** Sweeping a codebase
  for accumulated slowness belongs to the audit domain `auditing:code-quality`.

## Conflicts and how they resolve

Read `../../core/precedence.md` first. Where a convention mandates a data-access layer, a caching
wrapper, or an eager-loading mechanism, that decision stands — the convention's shape is compliance,
and this rule works inside it.

- **vs rule 6 (`state`).** Immutability by default. Mutating in place to avoid a copy is a second-half
  optimisation and requires a measurement, per this rule.
- **vs rule 1 (`clarity`).** With no measurement, clarity wins outright. With a measurement, the
  faster path is permitted — and then it carries a note saying why it looks the way it does, so the
  next reader does not "simplify" it back.
- **vs rule 2 (`abstraction`).** An abstraction layer is not removed for speed on suspicion. Measure
  first; a layer with a measured cost may be bypassed, and the bypass is named.
- **vs rule 3 (`boy-scout`).** Finding a known-slow pattern outside your touched lines does not
  license rewriting the file. Fix it if it is on the lines you touched; otherwise report it and move
  on.
- **vs rule 10 (`change-safety`).** A faster implementation that changes ordering, timing, or result
  shape is an observable change. It goes through rule 10's escape path.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
