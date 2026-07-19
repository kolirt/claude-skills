# Variant declaration buried after `## Files` fixture (positive guard)

`Variant: nonsense=1` appears below, but AFTER the `## Files` heading — it is not a
header declaration and must be ignored entirely, not parsed and then flagged as
invalid. If this were treated as a real declaration it would fail (`nonsense` is not
a recognised key), so a check that stays clean here proves the buried line is
correctly excluded rather than merely happening not to trip anything.

## Files

- `{shared-lib}/whatever.ts`

**File:** `{shared-lib}/whatever.ts`

```ts
export const whatever = true
```

Variant: nonsense=1
