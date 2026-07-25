# Precedence — what beats what

The ten rules are universal principles. They are the **weakest** of the three kinds of instruction
a codebase carries. This file fixes the ordering so no rule is ever used to argue against a decision
the project already made.

## The three bands

Strongest first. A higher band settles the question; lower bands do not get a vote on it.

| # | Band | What it is |
|---|------|------------|
| 1 | **Codified project convention** | a `knowledge-*` convention plugin, or the project's own `CLAUDE.md` |
| 2 | **Framework idiom** | how it is normally done in that framework |
| 3 | **Universal principle** | `knowledge-principles` |

[invariant · desired] **A principle never overrides a convention.** Where a convention mandates a
wrapper, a factory, a base class, a registry, or any other indirection, the principles have no vote:
the existing wrapper **is compliance, not excess**. An agent that removes, inlines, or bypasses a
mandated indirection in the name of a principle has broken the project, not improved it.

[anti-pattern · desired] Reporting a band-1 or band-2 structure as a principle violation. If a rule
seems to condemn something the convention requires, the rule is out of scope there — stop, do not
report, do not refactor.

## Worked examples — indirection that is compliance

### Example 1 — the mandated request wrapper

**Situation.** A project convention states that every backend call goes through one shared request
wrapper; raw `fetch`/HTTP-client usage at a call site is forbidden. A new feature needs exactly one
endpoint, so the wrapper is used by a single call site.

**Naive principle reading.** Rule 2 (`abstraction`) says domain abstractions wait for the third real
case. One call site, one abstraction — therefore speculative generality, therefore delete the
wrapper and call the client directly.

**Correct resolution.** Keep the wrapper. Use it. Report nothing.

**Why.** Band 1 already decided, so rule 2 never reaches the question. The wrapper is also an I/O
boundary, which rule 2 abstracts immediately in any case — but the convention alone is sufficient.

### Example 2 — the mandated validation layer

**Situation.** A convention requires that every inbound payload pass through a declared schema or
validation object before any handler logic runs — including endpoints whose payload is a single
field that the handler would obviously reject anyway.

**Naive principle reading.** Rule 1 (`clarity`) prefers the direct reading, and rule 2 objects to
ceremony around trivial input: a whole schema file for one boolean is indirection with no payoff.

**Correct resolution.** Declare the schema. Route the single field through it like every other
payload.

**Why.** The convention buys uniformity — one place where input contracts are read, one failure
shape — and that value exists only if the layer has no exceptions. A principle cannot trade away a
guarantee it does not own.

Both examples share the same mechanism and differ in axis: transport indirection versus an
input-contract layer. Neither is a judgment call at the call site.

## Same-band conflict

Two conventions can genuinely contradict each other. Resolve by **specificity — the more specific
file wins**:

1. A convention scoped to exactly this surface beats a general one covering the whole domain.
2. The project's own `CLAUDE.md` beats a general convention plugin, because it is closer to the
   code it governs.

If, after both tests, the two are of genuinely equal specificity and genuinely contradictory, the
agent **stops and asks the user**. It does not pick.

[anti-pattern · desired] Guessing at a tie. Guessing is the failure mode this clause exists to
prevent: a silent choice between two mandated conventions installs an unrecorded third convention,
and the next agent reads the code as precedent. Asking costs one question; guessing costs a
convention.

## Legacy code that predates a convention

Code written before its convention existed is **not** a principle violation and must not be reported
as one. It is untranslated history.

- Touching it is governed by rule 3 (`boy-scout`) — clean up **touched lines only**, not the file
  around them.
- Understanding it before changing it is governed by rule 10 (`change-safety`).
- Systematic cleanup of accumulated mess **outside the current diff** is not a principles job at
  all. That work belongs to the audit domain `auditing:code-quality`.

[anti-pattern · desired] Expanding a small change into a file-wide modernisation because the
surrounding code predates the convention.

## The security floor

Rule 9 (`security`) is the one exception to everything above.

- It is **never overridden** by a convention or by a framework idiom.
- It is **never silent** at any proportionality level.
- If a convention appears to require an insecure default, that is a **defect in the convention**.
  The agent reports the conflict and does not silently comply. It also does not silently "fix" the
  convention: it names the conflict and lets the user decide.

Read `proportionality.md` for the level machinery and for which rules are active or silent at each
level. The security floor is the only rule that machinery cannot switch off.

## How to apply this file

Resolve any question in this order, and stop at the first band that answers it:

1. **Convention** — is there a `knowledge-*` convention or a `CLAUDE.md` clause covering this
   surface? If yes, comply. Done.
2. **Idiom** — is there an established framework way to do it? If yes, follow it. Done.
3. **Principle** — only now do the ten rules decide.

This ordering is about **authority**, not about **effort**. A principle is not weakened by having
low precedence; it is simply out of scope wherever a stronger band has already spoken. Most code
has no convention and no idiom bearing on most of its decisions — there, the principles are the
whole of the standard, and they apply in full.
