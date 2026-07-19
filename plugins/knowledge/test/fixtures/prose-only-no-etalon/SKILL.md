---
name: prose-only-no-etalon-fixture
description: Negative fixture — a code skill whose rules are pure prose (no fenced block, no indented code) and which ships no references/ directory at all.
---

# Prose-only fixture

This skill is a code-producing skill in a CODE_PLUGINS plugin, but every rule below is
stated as prose — there is no fenced code block and no indented code sample anywhere in
the body. Reference-first is unconditional for a code-producing skill: it must ship a
valid etalon regardless of whether its own body happens to contain a code fragment. A
prose-only skill is still a *direction* ("do X, never Y") that the agent re-interprets
slightly differently on every run unless a full-file etalon backs it.

## Rules

- [invariant · desired] Always create the wrapper in the shared location and never inline
  it at the call site.
- [invariant · desired] The wrapper exposes exactly three named functions and nothing
  else; callers never reach past it to the underlying primitive.
- [invariant · desired] Errors are caught inside the wrapper and normalised to one shape
  before they reach a caller.
- [anti-pattern · desired] Do not scatter ad-hoc variants of this wrapper across
  features — there is exactly one, shared by every consumer.

Filler so the stub detector does not fire on this fixture instead of the one under test.
There is deliberately no `references/` directory sitting next to this file, and nothing
above is a fenced or indented code sample — the direction-style detector must still fire
because reference-first does not depend on the presence of code fragments in the body.
