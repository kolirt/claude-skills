# Shared-wrapper discipline (Vue) — cross-cutting invariant

The single most-violated rule. Referenced by the Vue umbrella and by pattern
skills that introduce UI primitives.

- [invariant · desired] UI primitives (native form elements, reka-ui components)
  are NEVER inlined at the call site. They are wrapped once in the project's shared
  UI location, registered there, and reused.
  - ✅ do: create/keep a wrapper in the shared UI location and import it:
    `import { Checkbox } from '@/shared/ui/form'`
  - ❌ don't: inline the primitive in a feature/widget component:
    `import { CheckboxRoot } from 'reka-ui'` then markup at the call site — why:
    bypasses the shared wrapper, duplicating styling and losing form-field
    delegation; the next usage diverges and the codebase fragments.

- [invariant · desired] When a needed wrapper does not exist yet, CREATE it in the
  shared UI location (and reuse it), rather than inlining a one-off at the call site.
  - ✅ do: add `Switch.vue` to shared UI, then use `<Switch v-model=… />`.
  - ❌ don't: paste `<SwitchRoot>` markup directly into the page — why: the wrapper
    never gets created, so the discipline silently erodes.
