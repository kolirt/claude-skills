# Duplicate-file-owner fixture, owner A (negative, paired with owner-b.md)

Ships `{shared-lib}/format-date.ts` with one implementation. `owner-b.md` (same
fixture directory) ships the SAME token path with DIFFERENT content — per
authoring-knowledge-skills SKILL.md §7 "Where an etalon ends", exactly one etalon
should ship a shared file and the rest should import it by token. Two etalons
shipping divergent copies is the worse failure: a reader reproduces whichever one
they happened to read last. `duplicate-file-owner` must flag this pair.

## Files

- `{shared-lib}/format-date.ts`

**File:** `{shared-lib}/format-date.ts`

```ts
export function formatDate(d: Date) {
  return d.toISOString()
}
```
