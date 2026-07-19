# Wrong `Files` heading level fixture (negative)

The contract requires exactly `## Files`, but this etalon uses a single `#`.
The old regex (`^#+ Files$`) accepted any hash count, so this heading opened
the inventory section and the file below passed. Tightened to exactly two
hashes, this heading no longer opens the inventory at all, so the etalon is
correctly reported as missing a `## Files` inventory.

# Files

- `{app}/main.ts`

**File:** `{app}/main.ts`

```ts
export const bootstrapped = true
```
