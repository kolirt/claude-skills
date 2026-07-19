---
name: direction-style-fixture
description: Negative fixture — a code skill that shows fragments instead of shipping a full-file etalon in references/.
---

# Direction-style fixture

This skill tells the agent roughly what to write and leaves the rest to interpretation,
which is exactly the pattern the reference-first rule forbids. It has no `references/`
directory, so the direction-style detector must fire.

## Usage

```ts
export function useThing() {
  // ...fill in the rest yourself
  return { thing: null }
}
```

Filler so the stub detector does not fire on this fixture instead of the one under test.
The body is long enough to be a real skill, short enough to stay under the line limit,
and it deliberately carries a fenced code block with no etalon behind it.
