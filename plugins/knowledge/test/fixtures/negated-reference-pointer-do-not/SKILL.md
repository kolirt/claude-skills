---
name: negated-reference-pointer-do-not-fixture
description: Negative fixture — the paragraph mentions its own etalon's filename AND the word "reproduce", but only inside a NEGATED instruction ("do not reproduce"). Must still be flagged as missing-reference-pointer.
---

# negated-reference-pointer-do-not fixture

This fixture guards against a bypass in the old detector, which treated any
paragraph containing both a filename mention and the bare substring
"reproduce" as a satisfied pointer, regardless of polarity.

Do not reproduce `references/widget.md` here — it is a stand-in only, never
actually copy it into a real project.

## Core rules

- [invariant · desired] A widget module exports a single factory function.

Filler prose so the stub detector does not fire on this fixture instead of
the one under test.
