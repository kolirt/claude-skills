# Proportionality — which rules are active

All ten rules are hard rules. Proportionality does not soften them; it decides **which of them are
in scope for a given piece of code**. Precedence decides what beats what — read `precedence.md` for
that. This file decides what is even being asked.

## The three levels

```
LEVEL 1  throwaway script, spike, prototype, one-off migration helper
         active   1 clarity · 7 naming · 9 security · 10 change safety
         silent   2 abstraction · 3 boy-scout · 4 boundaries · 5 errors · 6 state · 8 performance

LEVEL 2  code inside an existing application
         active   all ten
         silent   none

LEVEL 3  new public surface
         active   all ten; 5 and 9 applied strictly
         silent   none
```

**What "strictly" adds at level 3.** Rule 5 (`errors`): every input is validated at the boundary,
including input arriving from an internal caller that "cannot" send it wrong — the caller is not
evidence. Every failure mode has a defined, documented output shape; no path exits by exception
default or by returning an unspecified value. Rule 9 (`security`): every default denies rather than
permits, so an omitted flag, an unset scope, or a missing role check fails closed; every field that
crosses out of the surface is chosen explicitly rather than serialised wholesale.

## The security floor is not a dial

[invariant · desired] **Rule 9 (`security`) is active at every level.** It is a floor, not a
proportionality dial: there is no kind of code cheap enough, short-lived enough, or private enough
to earn an insecure default. A spike that hardcodes a token, a migration helper that disables
verification, a prototype that logs credentials — each is a defect at level 1 exactly as it is at
level 3.

`precedence.md` calls this the **security floor** and owns the argument for it. Do not re-derive it
here; defer to that file. The level machinery in this file can silence six rules; it can never
silence rule 9.

## What "silent" means

A silent rule is **not repealed**. It is descoped from enforcement, not from truth.

- The agent does **not spend effort** enforcing it: no refactor to satisfy it, no extra structure
  built for it, no rework of working code in its name.
- The agent does **not report** it as a defect at that level. A level-1 script with duplicated
  parsing logic is not a rule 2 finding.
- The agent **still does not deliberately do the thing the rule forbids.** Silence removes the
  obligation to fix, never the licence to break. If the natural way to write the line already
  satisfies a silent rule, write it that way.

[anti-pattern · desired] Treating silence as permission. "Rule 6 (`state`) is silent here, so I will
mutate the caller's array" inverts the mechanism: the rule was silenced to avoid *cost*, not to
authorise *harm*. Silence means "not audited"; it never means "inverted".

[anti-pattern · desired] Reporting a silent rule as a finding. It is noise at that level, and it
trains the reader to discount the report.

## Classifying a change — first match wins

Run the three tests in this exact sequence and stop at the first that fires.

```
1. Does the change add or alter an endpoint, route, migration, schema, auth/session path,
   money path, or a package's public export?              -> LEVEL 3
2. Does the change live inside an existing application's source tree?   -> LEVEL 2
3. Otherwise (scratch script, spike, generated helper, throwaway)       -> LEVEL 1
```

[invariant · desired] **Level is decided by what kind of code it is, never by diff size.** A
three-line endpoint is level 3. A 500-line scratch script is level 1. Nothing climbs a level for
being long and nothing drops a level for being short.

## Worked examples

### Example 1 — the prototype that ships an endpoint

**Situation.** A spike, explicitly labelled a prototype, throwaway after the demo. It adds one route
that reads a query parameter and returns a JSON blob.

**Naive reading.** It is a prototype, therefore level 1, therefore rules 5 (`errors`) and 6 (`state`)
are silent and the parameter can be trusted as-is.

**Correct resolution.** Level 3. Validate the parameter at the boundary, give the failure path a
defined shape, deny by default.

**Why.** Test 1 asks about an endpoint and fires before test 3 ever runs. "Prototype" is a statement
about intent; the route is a statement about surface, and only the surface is checkable. Labels do
not demote code.

### Example 2 — the one-off migration helper against production data

**Situation.** A script written to run exactly once, rewriting a column across every row of a live
production table. It will be deleted afterwards.

**Naive reading.** One-off, deleted after use — the level-1 list, so rule 5 is silent and errors can
surface however they surface.

**Correct resolution.** Level 3.

**Why.** Test 1 names migrations. A migration is level 3 regardless of how long the file survives,
because its blast radius is the data, not the file. Contrast the inverse case on the same axis: a
helper sitting inside the application tree that only a developer's local script imports still reaches
test 2 and is level 2 — living in the tree is enough, being unreachable in production is not a
discount.

Both examples run the same order and differ in axis: a label claiming a lower level, and a lifetime
claiming one. The order does not read either claim.

## How to apply this file

- Consult it **once per unit of work**, before any rule is applied. The level is an input to the
  rules, not a conclusion drawn from them.
- **State the level** wherever a report or summary would otherwise be ambiguous — a finding that
  reads as thin is usually a level that was never stated.
- If the level is genuinely unclear after all three tests, **ask**. Do not assume.

[anti-pattern · desired] Assuming level 1 to avoid work. This is the failure mode the clause above
exists to prevent: the cheaper level is always the more attractive guess, so a guess that lands on
level 1 is the one to distrust. Classify by the three tests, or ask — never by what the tests would
cost if they fired.
