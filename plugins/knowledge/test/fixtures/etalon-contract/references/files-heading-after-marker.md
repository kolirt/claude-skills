# `## Files` heading placed after the marker fixture (negative)

The contract puts the inventory FIRST — a reader scans `## Files` to know what's
coming before hitting the first full file. This fixture ships a `**File:**` marker
and its code block BEFORE the `## Files` heading appears at all; every other check
(matching entries, single fenced block, language tag, ...) still passes, so only an
explicit ordering check catches this.

**File:** `{app}/main.ts`

```ts
export const bootstrapped = true
```

## Files

- `{app}/main.ts`
