---
name: implement
description: Take a self-contained plan (typically produced by the brainstorm skill in another session) and implement it. Use ONLY when the user provides an existing plan document (pasted text, skill argument, or file) and asks to implement it — "implement", "реалізуй план". Not for feature requests without a plan. The plan is authoritative — do not re-interview or re-plan. Executes in hybrid mode: inline for simple plans, subagent orchestration for large or parallelizable ones.
---

# Implement a Plan

Take a self-contained plan and execute it. The plan (usually from the `brainstorm`
skill, authored in another session by a stronger model) is the source of truth —
do NOT re-interview the user or redesign the approach.

## Input

The plan text is passed as the skill argument or pasted into the message. It is
self-contained (Goal, Context, Approach, Steps, Out of scope, Risks). Treat it as
authoritative; you were not present when it was written and do not need that history.

## Before executing

1. Read the plan fully.
2. Ground it: delegate a quick codebase read to a subagent to confirm the plan's
   assumptions (file paths, APIs, conventions) still hold. Return a short summary,
   not raw files.
3. Ask the user ONLY if the plan is genuinely ambiguous or contradicts the current
   code. Otherwise proceed without questions.
4. Restate in 1–2 lines what you are about to do, then start.

## Execution — hybrid (auto)

Choose the mode per plan, automatically, from its size and structure:

- **Inline** — simple or linear plan (few steps, one area of the codebase, steps
  depend on each other): execute step by step yourself, writing code and verifying
  each step before the next.
- **Orchestrate** — large or parallelizable plan (many steps, independent chunks,
  broad file surface): decompose into subtasks honoring the plan's dependency
  order, pick a model per subtask (below), and dispatch subagents — in parallel
  where subtasks are independent, sequentially where they depend on each other.
  Review each subagent's result before integrating.

Decide by: number of steps, independence between steps, and breadth of files touched.

## Model selection (per subtask)

Before dispatching a subagent, pick a model by difficulty and state the pick with a
one-line rationale:

- Trivial / mechanical (rename, move, boilerplate) → haiku
- Standard implementation → sonnet
- Tricky, architectural, or high-blast-radius → opus

## Verification

- After each step or subtask, verify with whatever the project actually has:
  type-check, lint, and tests if wired; otherwise a targeted smoke-check.
- Report failures with the real output — never claim success you did not observe.
- Steps requiring human action (browser clicks, external systems, UX judgement)
  belong to the user: report them as pending, do not mark them done.

## Discipline

- Do NOT commit unless the user explicitly asks.
- Respect the plan's "Out of scope". If something must change beyond the plan, flag
  it to the user and get agreement — do not silently expand scope.
- Answer in the user's language.
