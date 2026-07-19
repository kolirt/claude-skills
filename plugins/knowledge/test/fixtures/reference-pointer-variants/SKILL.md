---
name: reference-pointer-variants-fixture
description: Positive guard — a skill correctly pointing at both of its own variant etalons in one "X or Y ... reproduce" sentence must not be flagged by check_reference_pointer or check_orphan_etalon.
---

# reference-pointer-variants fixture

Read `references/thing.md` (CSR) or `references/thing.ssr.md` (SSR) and
reproduce the one matching the project's `projectType` — never both.

## Core rules

- [invariant · desired] The shared thing helper is a single exported function.

Filler prose so the stub detector does not fire on this fixture instead of the
one under test.
