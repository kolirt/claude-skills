---
name: fake-skeleton-fixture
description: Negative fixture — a finished skill that plants a skeleton marker to try to claim the exemption.
---

# Fake skeleton fixture — skeleton

This skill's title carries the skeleton marker text, but the body below is a
fully written, finished skill — not a stub awaiting a capture session. The
marker alone must not exempt it from reference-first: the body must also
actually be short before the skeleton exemption applies. This body is
deliberately padded well past the stub line limit so the exemption cannot be
claimed on marker text alone.

## Usage

```ts
export function useThing() {
  // ...fill in the rest yourself, this is a real code fragment
  return { thing: null }
}
```

## Why this matters

A skill that ships real code fragments and no `references/` etalon is exactly
the pattern the reference-first rule forbids, regardless of whether its
title happens to contain the word "skeleton". Padding line one.
Padding line two.
Padding line three.
Padding line four.
Padding line five.
Padding line six.
Padding line seven.
Padding line eight.
Padding line nine.
Padding line ten.
