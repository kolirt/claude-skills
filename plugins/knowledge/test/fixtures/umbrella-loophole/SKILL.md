---
name: umbrella-loophole-fixture
description: Negative fixture — plants the old `(umbrella)` heading marker to try to dodge reference-first, but is not in the UMBRELLA_SKILLS allow-list.
---

# Umbrella loophole fixture (umbrella)

This skill's heading carries the literal `(umbrella)` suffix that used to be the
entire exemption mechanism — any code skill could rename its heading and escape
the reference-first requirement. The exemption is now a hard-coded allow-list
(`UMBRELLA_SKILLS`) matched on the frontmatter `name:`, and `umbrella-loophole-fixture`
is deliberately not on it. The heading marker must count for nothing: this skill
ships a real code fragment and no `references/` directory, so the direction-style
detector must still fire.

## Usage

```ts
export function useThing() {
  // a real code fragment — this is not an umbrella/index skill
  return { thing: null }
}
```

Filler so the stub detector does not fire on this fixture instead of the one under test.
Padding to stay clear of the skeleton short-body threshold as well.
