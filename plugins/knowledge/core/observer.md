# Proactive observer — DESIGN ONLY (not built in increment 1)

> Status: design intent for a later increment. Nothing in increment 1 activates
> this. **Notify-only**: read-only, advisory, conservative. It runs while the
> developer works in ANY project and **never writes anywhere** — not the current
> project, not another project, not the plugin repo. It only TELLS the developer.

## Mode A — novel pattern
Notice a repeated, deliberate pattern not yet captured. Say "I noticed this
pattern" + a written description. Write nothing. The developer later carries the
description into the codification action **in the plugin repo**, or discards it.

## Mode B — conflict with an existing skill
When the developer's request contradicts a documented skill, do NOT comply
silently. Stop and ask which it is:
- **knowledge progression** → the approach evolved, the skill is stale → the
  developer may later update the skill (codification, in the repo);
- **mistaken / one-off** → **defend the skill** ("your documented approach is X —
  skill `<name>` says Y") and stay on the skill until the developer confirms.

Guard strength is graduated: `invariant` → strong guard; `preference` → lighter.

## Non-owner use
A non-owner gets the read-only benefit (rules drive the agent) and may receive
these notifications, but cannot codify — there is no repo for them to write to.

## Conservatism
Propose only on a repeated, deliberate, not-yet-captured pattern — never on every
micro-decision (noise risk).
