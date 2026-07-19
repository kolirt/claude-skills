---
name: reference-pointer-mixed-fixture
description: Positive guard — one paragraph both points at its own etalon to reproduce AND names a different etalon it must not duplicate (the real plugin-registration/SKILL.md shape). Must not be flagged by check_reference_pointer.
---

# reference-pointer-mixed fixture

Read `references/own.md` and reproduce it — it holds the complete files for
this skill's own module. The unrelated setup lives in the `other-skill`
skill's `references/other.md` etalon; it is **not** reproduced here either,
since it is owned by that other skill.

## Core rules

- [invariant · desired] A widget module exports a single factory function.

Filler prose so the stub detector does not fire on this fixture instead of
the one under test.
