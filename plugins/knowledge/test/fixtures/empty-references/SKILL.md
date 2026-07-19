---
name: empty-references-fixture
description: Negative fixture — a references/ directory exists but holds no valid etalon, so it must not count as having one.
---

# Empty references fixture

This skill has a `references/` directory sitting next to it, but the only file
inside fails the etalon contract (no `## Files` inventory, no `**File:**`
markers). An empty or invalid references/ directory must not grant reference-first
a free pass.

## Usage

```ts
export function useThing() {
  // ...fill in the rest yourself
  return { thing: null }
}
```

Filler so the stub detector does not fire on this fixture instead of the one under test.
