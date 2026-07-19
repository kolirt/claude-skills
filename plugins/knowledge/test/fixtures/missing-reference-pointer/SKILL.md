---
name: missing-reference-pointer-fixture
description: Negative fixture — references/ holds a structurally valid etalon, but SKILL.md never points at it with a "reproduce it" instruction.
---

# missing-reference-pointer fixture

This skill would pass `check_direction_style` — `references/widget.md` is a
structurally valid etalon (it has `## Files`, a `**File:**` marker, one fenced
block right after it). But nothing below ever tells the reader to open that
file: the rules are described in prose only, and no sentence in this body
names the file alongside an instruction to copy it. That is exactly the
second-half gap `check_reference_pointer` exists to catch — an unrelated
valid etalon sitting in references/ must not satisfy the two-sided contract
on its own.

## Core rules

- [invariant · desired] A widget module exports a single factory function.
- [invariant · desired] Widgets never import from entities directly.

Filler prose so the stub detector does not fire on this fixture instead of the
one under test — the point of this file is the missing pointer, not brevity.
