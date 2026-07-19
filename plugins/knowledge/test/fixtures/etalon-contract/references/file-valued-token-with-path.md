# File-valued token with an appended path fixture

The inventory entry and the matching `**File:**` marker use `{pages-types}/extra.ts`.
`{pages-types}` is placement.md's one FILE-valued token (§1: "A token names a BUCKET,
with one file-valued exception") — it resolves to a single file and must stand alone,
with nothing appended. Treating it like a bucket and appending a further path segment
is exactly the shape placement.md forbids.

## Files

- `{pages-types}/extra.ts`

**File:** `{pages-types}/extra.ts`

```ts
export const extra = true
```
