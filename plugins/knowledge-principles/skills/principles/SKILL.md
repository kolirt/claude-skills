---
name: principles
description: Use whenever writing or editing code in any language or stack — adding a function, changing existing code, reviewing a diff, or deciding how to structure something. Indexes the ten universal programming rules and resolves conflicts between them. Self-activating; no manual inclusion.
---

# Principles (umbrella)

The entry point to the ten universal programming rules. This file is an index and a conflict
authority — it holds no rule of its own. Each rule lives in its own skill and carries its own
obligations, violations, and stack references.

All ten rules are **hard** rules. A violation is a defect, not a preference. There is no
"stylistic disagreement" band in this plugin: either a rule is active and its obligations hold, or
proportionality has declared it silent for this kind of code.

## Read the two core docs first

Both are read **before any rule is applied**, in this order:

1. Read `../../core/precedence.md` — decides **what beats what**. A codified project convention
   always beats a universal principle, and a framework idiom beats architectural purity. A
   mandated wrapper, factory, or registry is compliance, not excess.
2. Read `../../core/proportionality.md` — decides **which rules are active** for this kind of code:
   the three levels, the active/silent lists, and the first-match classification order.

[anti-pattern · desired] Applying a rule without first classifying the level. Skipping
proportionality means enforcing rules that are silent here — reporting a level-1 script for
duplication, or building abstraction into a spike. This is the most common misuse of this plugin.

[invariant · desired] Rule 9 (`security`) is the **security floor**: never overridden by a
convention or an idiom, never silent at any level. Everything below is subordinate to it.

## The ten rules

Pick the rule that owns the question and read that skill; it carries the specifics.

| # | Rule | The rule, in one line | When it decides |
|---|---|---|---|
| 1 | `../clarity/SKILL.md` | Clarity over cleverness | a construct is compact but hard to read; a reviewer has to reconstruct intent |
| 2 | `../abstraction/SKILL.md` | I/O boundaries abstract immediately; domain abstracts on the third real case | introducing a layer, a generic, a config flag, or a shared helper |
| 3 | `../boy-scout/SKILL.md` | Clean up touched lines only | tempted to tidy the file around the change |
| 4 | `../module-boundaries/SKILL.md` | Depend on the contract, not the structure | reaching into another module's internals; splitting or merging modules |
| 5 | `../errors/SKILL.md` | Strict at input · fail fast inside · degrade at output | validation, `try`/`catch`, fallbacks, error shapes |
| 6 | `../state/SKILL.md` | Single source of truth · never mutate what you do not own · illegal states unrepresentable | shared or derived state, in-place mutation, modelling a type |
| 7 | `../naming/SKILL.md` | Name the intent; make effects and dependencies explicit | naming anything; a function that reads as a query but writes |
| 8 | `../performance/SKILL.md` | Known slow patterns are defects; optimisation requires measurement | a query in a loop; any change justified as "faster" |
| 9 | `../security/SKILL.md` | Security by default | defaults, permissions, secrets, anything crossing a trust boundary |
| 10 | `../change-safety/SKILL.md` | Do not touch what you do not understand; observable behaviour is someone's dependency | editing unfamiliar code; changing an output others may rely on |

## Rule versus rule — the conflict table

Each rule states its own conflicts locally. **This table is the authority** when two rules pull
against each other; a local statement that appears to disagree with a row here is read as this row.

| Conflict | Resolution |
|---|---|
| DRY (rule 2) vs decoupling (rule 4) | **Decoupling wins.** Two similar shapes in two modules is cheaper than one shared shape that couples them. Duplication is a cost; coupling is a constraint. |
| Framework idiom vs architectural purity (rules 2, 4) | **The idiom wins.** Band 2 of `../../core/precedence.md` settles it; the principles never reach the question. |
| Minimal diff (rule 10) vs cleanup (rule 3) | **The minimal diff wins.** Cleanup is permitted only on touched lines, and only where the code is understood. |
| Immutability (rule 6) vs performance (rule 8) | **Immutability by default.** A mutable exception requires a measurement, per rule 8 — an argument from intuition is not one. |
| Any principle vs a codified convention | **The convention wins, always.** See `../../core/precedence.md`. |
| Any convention vs rule 9 (`security`) | **Rule 9 wins.** It is the security floor. An insecure default is a defect in the convention; report the conflict, do not silently comply and do not silently rewrite the convention. |

For a genuine collision this table does not cover: **name the conflict in the summary of the work,
state both readings and their cost, and let the user decide.**

[anti-pattern · desired] Resolving an uncovered rule-versus-rule collision silently. A silent
choice becomes precedent the next agent reads as settled, and no one recorded that there was a
choice. Naming it costs one line.

## How to use this index

- **Pick the one rule that owns the question**, read that skill, and apply it from its own text.
  A question usually has one owner; if two rules both seem to own it, that is a conflict — use the
  table above.
- [invariant · desired] **Never paraphrase a rule from this table alone.** The one-liners are
  pointers, not the rule. The obligations, the violation symptoms, and — critically — the
  `What this rule does not claim` section exist only in the rule's own skill, and a rule quoted
  without its limits is routinely applied where it does not reach.
- **Report at the level.** State the proportionality level wherever a finding would otherwise read
  as ambiguous, and cite the rule by number and name: "rule 4 (`module-boundaries`)".
- Systematic cleanup of accumulated mess outside the current diff is not a principles job; that
  work belongs to the audit domain `auditing:code-quality`.

> This file is the maintained index. When a rule skill is added, renamed, or its scope changes, its
> row here is updated in the same change — an index that lags is worse than no index, because it is
> read as complete. The conflict table is updated the same way when a new canonical resolution is
> settled.
