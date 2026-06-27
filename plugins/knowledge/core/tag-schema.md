# Tag schema (stack-independent)

Every captured rule is one bullet with a machine-greppable tag, so a later
verifier can parse rules without NLP.

## Grammar

```
- [<type> · <provenance>] <rule sentence>
  - ✅ do: <inline code block, or link to an example file>
  - ❌ don't: <inline code block, or link> — why: <one clause>
```

- `type` ∈ `invariant` (never violate) · `preference` (default, overridable) ·
  `anti-pattern` (a thing to avoid).
- `provenance` ∈ `desired` (the developer wants this) · `legacy` (merely how the
  old repo was — not to be cemented as an invariant).
- The separator between type and provenance is the middot `·` (U+00B7).

## Example

- [invariant · desired] reka-ui primitives are wrapped in the project's shared UI
  location, never inlined at the call site.
  - ✅ do: `import { Checkbox } from '@/shared/ui/form'`
  - ❌ don't: `import { CheckboxRoot } from 'reka-ui'` in a feature component — why: bypasses the shared wrapper, so styling/validation delegation is lost.

## do/don't expectation

Every `invariant` and every `anti-pattern` SHOULD carry a do/don't pair where one
sharpens the rule. Omit only when it adds nothing over the prose. `preference`
rules carry an example when helpful. Small examples inline; large ones as files.

## Grep grammar (for tooling)

A tagged rule line matches: `\[(invariant|preference|anti-pattern) · (desired|legacy)\]`
