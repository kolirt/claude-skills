---
name: implement
description: Take a self-contained plan (typically produced by the brainstorm skill in another session) and implement it. Use ONLY when the user provides an existing plan document (pasted text, skill argument, or a file path) and asks to implement it — "implement", "реалізуй план". Not for feature requests without a plan. The plan is authoritative — do not re-interview or re-plan. Asks the user to choose the execution approach: inline, or subagent orchestration for large or parallelizable plans.
---

# Implement a Plan

Take a self-contained plan and execute it. The plan (usually from the `brainstorm`
skill, authored in another session by a stronger model) is the source of truth —
do NOT re-interview the user or redesign the approach.

## Asking the user

This applies to EVERY question this skill puts to the user — a plan-content ambiguity,
the mode choice, the parallel-vs-sequential choice, anything. Send exactly ONE question
per AskUserQuestion call (the `questions` array holds a single item). NEVER batch
several questions into one call, even though the tool allows up to 4: each answer can
change what the next question should be, or whether it is still needed. Ask them one at
a time, in dependency order, and list your recommended answer FIRST with a one-line
reason. (Same one-question discipline as the `brainstorm` skill.)

## Input

The plan is passed as the skill argument, pasted into the message, or given as a file
path — if it is a path, read that file first. It is self-contained (Goal, Context,
Approach, Steps, Out of scope, Risks). Treat it as authoritative; you were not present
when it was written and do not need that history.

## Before executing

1. Read the plan fully.
2. Ground it: for a non-trivial plan, delegate a quick codebase read to a Sonnet
   subagent to confirm the plan's assumptions (file paths, APIs, conventions) still
   hold — a short summary, not raw files.
3. Do NOT re-interview or re-plan: ask the user about the plan's *content* ONLY if it
   is genuinely ambiguous or contradicts the current code — and when you do, one
   question at a time per "Asking the user" above. This says nothing about the
   execution-mode and parallel-vs-sequential questions below — those are asked whenever
   they apply, independently of this rule.
4. Restate in 1–2 lines what you are about to do, then proceed to the Execution
   decisions below (do not begin writing code until the mode is settled).

## Execution

Two decisions govern execution: the **mode** (Inline vs Orchestrate) and, if you
orchestrate, **parallel vs sequential**. Both follow the same rule: assess the plan,
form a recommendation, and ask the user with AskUserQuestion — one question per call per
"Asking the user" above, the option you recommend FIRST, marked `(Recommended)` with a
one-line reason. The one exception, identical for both: when the choice is obvious for a
small plan, pick the safe default yourself and do NOT ask.

Ask Decision 2 only after Decision 1 resolves to Orchestrate, so its recommendation can
react to the mode you settled on.

### Decision 1 — mode

Assess by: number of steps, independence between steps, breadth of files touched.

- **Inline** — execute step by step yourself, writing code and verifying each step
  before the next.
- **Orchestrate** — decompose into subtasks honoring the plan's dependency order, pick
  a model per subtask (below), and dispatch subagents. Review each result before
  integrating.

Ask the user, recommended option first. Exception: when the plan is small enough that
spinning up subagents makes no sense (a single step, or a couple of dependent steps),
choose **Inline** yourself and do NOT ask.

### Decision 2 — parallel vs sequential

Only applies if you orchestrate; Inline is single-threaded by definition.

Two subtasks are **independent** only if they write disjoint files AND neither depends
on the other's output — directly OR transitively. Transitive counts: in a chain
`A → B → C`, `A` and `C` are NOT independent even though neither names the other,
because `C` needs `A`'s result through `B`. Build the dependency graph from the plan
first, then treat as independent only subtasks with no path between them.

A subtask that has no file target of its own — anything that observes the codebase as a
whole, such as running tests, a type-check, a build, or a lint — is NEVER independent:
it depends on every step whose output it could observe, so it always runs sequentially
after them, never in a parallel wave.

- **Parallel** — dispatch independent subtasks concurrently (each dependency wave runs
  its independent members together). Faster, but harder to follow and interleaves output.
- **Sequential** — run everything one after another. Slower, but easier to watch and review.

Ask the user ONCE, up front, recommended option first — the answer is the policy for
every independent set in the plan, not a per-wave question. State which subtasks you
found independent so the choice is informed. Exception: when there is nothing to
parallelize (no two subtasks are independent), choose **Sequential** yourself and do
NOT ask. Subtasks that depend on each other always run sequentially regardless of the
answer; the question only governs the independent ones.

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
