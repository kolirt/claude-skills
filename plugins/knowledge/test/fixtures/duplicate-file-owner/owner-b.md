# Duplicate-file-owner fixture, owner B (negative, paired with owner-a.md)

Ships `{shared-lib}/format-date.ts` too, but with different content than
`owner-a.md` — a divergent copy of the same token path. See owner-a.md for the
full explanation; this file exists only to be the second owner in the pair.

## Files

- `{shared-lib}/format-date.ts`

**File:** `{shared-lib}/format-date.ts`

```ts
export function formatDate(d: Date) {
  return d.toLocaleDateString()
}
```
