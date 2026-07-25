---
name: boy-scout
description: Use when a change lands in messy code and the diff starts growing — "while I'm here" refactors, renaming beyond the edit, reformatting a file, migrating a file to a newer pattern, or deciding whether a stale comment, dead branch, or bad local name next to your edit is yours to fix.
---

# Rule 3 — Clean up touched lines only

[invariant · desired] You may leave the code you touch better than you found it, and the unit of
"touch" is the **line**, never the file, the module, or the pattern. Cleanup rides along with a change
that was already justified; it never becomes the justification. A diff whose hunks cannot each be
traced to the task has stopped being the task.

## What this rule requires

- **The line is the unit.** Cleanup is permitted on lines your change already modifies, and on lines
  your change made wrong (a comment that is now false, an import your edit orphaned).
- **Permitted on a touched line:** rename a local to what it actually holds; delete a branch your
  change made dead; correct or delete a stale comment; drop a now-unused import; collapse a condition
  that your change made redundant.
- **Not permitted:** reformatting the file, renaming across the module, reordering functions,
  migrating the file to a newer pattern, tightening types elsewhere, bumping a dependency, or fixing
  a neighbouring bug that nobody asked about. Those are separate, named pieces of work.
- **Two gates, both required.** A line may be cleaned only if it is **touched** and the code around it
  is **understood** (rule 10, `change-safety`). Passing one gate is not enough.
- **Where both gates cannot be satisfied, leave it and say so.** If you must change a line inside
  code you do not fully understand, make the minimal change, clean nothing, note what you left and
  why — then continue. Do not stall the task on it, and do not clean speculatively to compensate.
- **The diff test.** For every changed line, a reviewer can name one reason and that reason is the
  task. A hunk whose only reason is "it was untidy" fails.

## What violates it

- ❌ don't: fix a bug on line 40 and reformat the whole file because the formatter was never run.
  - ✅ do: change line 40; leave the file's formatting alone (formatting is band 1 anyway).
- ❌ don't: rename a parameter you touched and then chase the rename through every caller.
  - ✅ do: rename the local; leave the exported name and its callers for a named refactor.
- ❌ don't: convert the surrounding functions to the pattern the project uses today because the file
  predates it.
  - ✅ do: write your change in the current pattern; leave the neighbours as untranslated history.
- ❌ don't: delete a branch that looks dead but whose deadness you did not verify — that is a rule 10
  violation wearing this rule's clothes.
- ❌ don't: add unrelated `TODO` comments or defensive checks "while I'm here".
- ❌ don't: leave a comment on a line you edited that your edit made false. Bounding cleanup is not an
  excuse to skip it where it applies.

## What this rule does not claim

- **Broken Windows is narrowed to the diff.** Accumulated mess **outside** the lines you touched is
  deliberately not addressed by this rule: a file badly named throughout, a dead abstraction nobody
  calls, a stale pattern repeated in fifty places. None of it becomes actionable because you edited
  one line nearby, and none of it is a principles finding. Systematic cleanup of accumulated mess
  belongs to the audit domain `auditing:code-quality`, which exists precisely so this rule does not
  have to grow. The narrowing is recorded here as a real loss: this rule will not clean a codebase,
  only stop it degrading at the point of change.
- **It does not claim the mess is acceptable.** It claims this rule is not the instrument. Naming the
  mess in your report is correct; expanding the diff to fix it is not.
- **The rule 3 × rule 10 interaction.** Cleanup is permitted only on touched lines **and** only where
  the code is understood. The `change-safety` skill states the same interaction from the other side:
  do not touch what you do not understand. Neither rule licenses the other — both gates are open, or
  the line stays.
- It does not set a diff-size budget. A large change that is all task is fine; a small change that is
  half taste is not.
- It does not govern which cleanups are *worth* doing when the file is the subject of the task. A
  deliberate refactor task touches every line it means to, and this rule has nothing to bound.

## Conflicts and how they resolve

Read `../../core/precedence.md` wherever precedence decides the question.

| Pulls against | Resolution |
|---|---|
| Rule 10 (`change-safety`) — cleanup against the minimal diff | the minimal diff wins; cleanup is permitted only on touched lines AND only where the code is understood |
| Rule 1 (`clarity`) and rule 7 (`naming`) | an unclear or badly named symbol you did not touch stays as it is; the naming rules apply to lines in your diff |
| Rule 2 (`abstraction`) | a duplication outside your diff is not consolidated today, even at the third case, unless the task is that consolidation |
| A convention the file predates | legacy code is untranslated history, not a violation, and not a licence to modernise the file (`precedence.md`, legacy section) |
| Rule 9 (`security`) | the security floor is never silent: an insecure default you can see is **reported** even when it sits outside your touched lines. Whether the fix lands in this diff or a separate one is the user's call — leaving it unreported is not an option |

This rule is silent at proportionality level 1 — a spike is not held to ride-along cleanup.
Read `../../core/proportionality.md`.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
