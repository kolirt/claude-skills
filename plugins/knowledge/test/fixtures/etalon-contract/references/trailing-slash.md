# Trailing slash fixture (negative)

The inventory entry and its matching `**File:**` marker use `{app}/foo/` — a trailing
slash after the last real segment. An etalon path names a complete FILE, and a
trailing slash makes the last segment empty, naming a directory instead. Must be
rejected exactly like any other empty-segment path.

## Files

- `{app}/foo/`

**File:** `{app}/foo/`

```ts
export const x = true
```
