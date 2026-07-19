# Nested brace token fixture (negative)

The inventory entry and its matching `**File:**` marker start with a real
token (`{app}`), but a SECOND `{...}` group follows it (`{not-a-token}`).
`{...}` is reserved for the leading placement token only (placement.md §1) —
any other placeholder must use `<...>`. The old check validated only the
LEADING token and let this nested brace group through unchallenged; it must
now be rejected as an untokenised `## Files` / **File:** path, exactly like a
literal hard-coded path would be.

## Files

- `{app}/{not-a-token}/main.ts`

**File:** `{app}/{not-a-token}/main.ts`

```ts
export const bootstrapped = true
```
