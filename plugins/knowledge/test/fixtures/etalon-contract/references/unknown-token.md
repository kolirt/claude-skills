# Unknown token fixture

The inventory entry and the matching `**File:**` marker use `{not-a-token}`, which
has the exact SHAPE of a placement token (`{word}`) but is not a row in
placement.md's token table. The old shape-only check let this through; the
vocabulary parsed at run time from placement.md must reject it as an unknown
token.

## Files

- `{not-a-token}/x.ts`

**File:** `{not-a-token}/x.ts`

```ts
export const x = true
```
