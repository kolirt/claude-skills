---
name: negated-reference-pointer-instead-of-fixture
description: Negative fixture — a second negated phrasing ("instead of reproducing") naming its own etalon's filename. Must still be flagged as missing-reference-pointer.
---

# negated-reference-pointer-instead-of fixture

This skill ships `references/widget.md`, a structurally valid etalon. The
body only ever names it inside a sentence that tells the reader to reach for
the shared helper instead of reproducing `references/widget.md` in a new
project. That is the opposite of an instruction to copy it, so
`check_reference_pointer` must still fail this skill even though the
filename and the word "reproducing" sit right next to each other.

## Core rules

- [invariant · desired] A widget module exports a single factory function.

Filler prose so the stub detector does not fire on this fixture instead of
the one under test.
