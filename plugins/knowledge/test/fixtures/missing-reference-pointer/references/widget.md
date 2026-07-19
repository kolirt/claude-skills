# missing-reference-pointer fixture — a valid, unrelated etalon

This etalon is structurally valid (has `## Files`, a `**File:**` marker, one fenced
block right after it) — it exists only so `check_direction_style`/`dir_has_valid_etalon`
see references/ as non-empty and non-broken. Nothing in `SKILL.md` (in the parent
fixture directory) ever names this file in a "reproduce it" sentence, which is
exactly the gap `check_reference_pointer` must catch.

## Files

- `{shared-lib}/widget.ts`

**File:** `{shared-lib}/widget.ts`

```ts
export function widget() {
  return true
}
```
