# Indented code fixture etalon

Valid etalon so the missing-etalon path of `check_direction_style` cannot fire on
this fixture — the SELF_TEST row for this fixture asserts `has_code_fragments()`
directly on the SKILL.md text instead, so it actually proves indentation
detection rather than piggy-backing on the missing-`references/` error.

## Files

- `{shared-lib}/thing/useThing.ts`

**File:** `{shared-lib}/thing/useThing.ts`

```ts
export function useThing() {
  const value = compute()
  return { value }
}
```
