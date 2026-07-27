---
name: change-safety
description: Use when removing, rewriting, or "cleaning up" code whose purpose is unclear — an odd guard, a sleep, a redundant-looking check, a commented workaround — and when changing anything a caller can observe — response shape, ordering, timing, error text, default values, or an accidental leniency.
---

# Rule 10 — Do not touch what you do not understand; observable behaviour is someone's dependency

[invariant · desired] **Before removing or altering something that looks pointless, find out why it
exists; and treat every externally observable behaviour as something a caller already depends on.**
This rule forbids **silent** change, not change. Every break has a stated escape path, and taking it
is the normal way to work.

## What this rule requires

### Find out why it exists

- Code that looks pointless is either dead or load-bearing, and the difference is not visible from
  reading it. Establish which before touching it: history, the linked issue, the test that fails when
  it is removed, the caller that depends on it, or the user.
- A guard, a retry, an ordering, a `+ 1`, a narrowed type, a defensive default: assume it was written
  in response to something real until shown otherwise.
- A comment that says "do not remove" without saying why is still evidence. Find the why; do not
  overrule the note.
- If the reason cannot be established, the code is left alone and the fact is noted. That is a
  complete, acceptable outcome — not a stall.

### Treat observable behaviour as a dependency

Anything a caller can see may already be relied upon, whether or not it was designed:

- Output shape and field names, including fields nobody documented.
- Ordering of results that happens to be stable today.
- Timing, latency, and whether a call is synchronous.
- Error text, error codes, and which failure mode is produced.
- Accidental leniency — an input the API tolerates, a nullable that is never null, a case-insensitive
  match that was never specified.
- Default values, and what happens when an optional argument is omitted.

### The escape path — how to change it anyway

A break is permitted, in this order, every time:

1. **Identify who depends on the current behaviour.** Search the callers you can reach; name the ones
   you cannot.
2. **State the change explicitly in the summary of the work.** What behaviour changed, from what to
   what, and who is affected. Silence here is the violation.
3. **Then either** preserve compatibility — keep the old path working, or provide the shim,
   the alias, the deprecation — **or** get the user's explicit approval for the break.

Never step 3 without step 2. An approved break is normal engineering; an unannounced one is a defect
even when the new behaviour is better.

## What violates it

- Deleting something because its purpose is not obvious.
  - ✅ do: establish why the guard is there, then remove it with the reason recorded.
  - ❌ don't: remove it as "dead code" because no test covers it.
- Changing observable behaviour without saying so.
  - ✅ do: "the list is now ordered by created date; previous order was insertion order" in the
    summary.
  - ❌ don't: change ordering as a side effect of a refactor and mention only the refactor.
- Tightening an accidental leniency as a "fix" without announcing it.
- Rewording an error message that a caller matches on, or changing an error code.
- Turning a synchronous call asynchronous, or the reverse, as an internal detail.
- Rewriting a workaround that has a linked issue number, without reading the issue.
- Restoring a "correct" default that the current default was deliberately chosen to override.

## What this rule does not claim

- **It does not require a test for every behaviour before touching it.** Tests are one way to
  establish what a thing does, and often the best one, but this rule demands understanding, not
  coverage. Requiring a characterisation test for every line would stop all work.
- **It does not make deletion forbidden.** Dead code, once established as dead, goes. Understanding
  is the gate; the answer may be "nothing depends on this".
- **It does not extend to internal implementation details no caller can observe.** A private helper's
  name, a local structure, an internal ordering nothing reads: refactor freely. Rule 4
  (`module-boundaries`) defines where the observable surface ends.
- **It does not require a deprecation cycle.** Whether a break needs a shim, a version, or a notice
  period is a project fact — band 1 in `../../core/precedence.md`. This rule requires disclosure and
  approval, not a particular migration mechanism.
- **It does not claim old code is right.** It claims old code had a reason, and the reason must be
  known before it is overruled.
- **It does not turn every change into a negotiation.** Behaviour no caller can observe, and behaviour
  you are changing on the user's own instruction, needs no further gate.

## Conflicts and how they resolve

Read `../../core/precedence.md` first — and its legacy-code clause in particular: code that predates a
convention is untranslated history, not a defect, and is not reported as one.

- **vs rule 3 (`boy-scout`).** The minimal diff wins. Stated from this side, and identically in the
  `boy-scout` skill: cleanup is permitted **only on touched lines** AND **only where the code is
  understood** — both conditions, not either. Where both cannot be satisfied, **leave the code alone
  and note it**: do not expand the diff to understand it, and do not stall the task over it. Record
  the observation and continue. Rule 3 never authorises a change this rule would call unexplained.
- **vs rule 1 (`clarity`).** A confusing construct is not rewritten for readability until it is
  understood. Understand it first; then the rewrite is safe and rule 1 applies in full.
- **vs rule 2 (`abstraction`).** Removing an abstraction that looks speculative is a change like any
  other. Establish whether something depends on it, then take the escape path.
- **vs rule 9 (`security`).** Rule 9 wins. A security defect is closed even when the insecure
  behaviour is depended upon; the dependency is named in the summary, not honoured.
- **vs rule 8 (`performance`).** A known-slow pattern in code you do not understand is reported, not
  rewritten in place.

## Stack references

For how this rule manifests in a Vue codebase, read `references/vue.md`.
For how this rule manifests in a Laravel codebase, read `references/laravel.md`.
