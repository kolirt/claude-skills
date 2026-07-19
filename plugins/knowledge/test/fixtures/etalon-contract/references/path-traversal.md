# Path traversal fixture (negative)

The inventory entry and the matching `**File:**` marker both use
`{project-root}/../outside.ts` — a `..` segment that walks the path back out
of the `{project-root}` bucket the token names. An etalon writes files
INSIDE the bucket its token names; a path that escapes it is never
legitimate, regardless of how real `{project-root}` and `../outside.ts` look
individually. This must be rejected exactly like an unknown token.

## Files

- `{project-root}/../outside.ts`

**File:** `{project-root}/../outside.ts`

```ts
export const outside = true
```
