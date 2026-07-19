# Empty path segment mid-path fixture (negative)

The inventory entry and its matching `**File:**` marker use `{app}/foo//bar.ts` — a
doubled slash between two real-looking segments, producing an EMPTY segment in the
middle of the path rather than at the start or end. Must be rejected exactly like a
leading or trailing empty segment.

## Files

- `{app}/foo//bar.ts`

**File:** `{app}/foo//bar.ts`

```ts
export const bar = true
```
