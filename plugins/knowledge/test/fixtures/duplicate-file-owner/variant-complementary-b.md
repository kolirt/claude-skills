# Duplicate-file-owner fixture, complementary variant B (positive, paired with variant-complementary-a.md)

Variant: projectType=ssr

Ships `{shared-lib}/api-client.ts` too, for SSR projects — see variant-complementary-a.md
for the full explanation. Same token path, same key (`projectType`), different value
(`ssr` vs `csr`): a complementary pair, not a conflict. This file exists only to be the
second alternative in the pair.

## Files

- `{shared-lib}/api-client.ts`

**File:** `{shared-lib}/api-client.ts`

```ts
export function createApiClient() {
  return fetch.bind(globalThis)
}
```
