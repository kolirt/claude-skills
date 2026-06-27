# Placement (Vue) — where files go

The single stable reference for "where does this file belong". **Dual-mode and
project-aware**: it holds the developer's placement rules for BOTH FSD and non-FSD
projects, as a matrix of *artifact type* × *architecture*. Placement is **decoupled
from FSD** — a skill references THIS module, never a hard-coded path.

## How a skill uses it
1. Determine the current project's architecture: the project declares it (a marker
   or convention), else detect the FSD layout. If it cannot be determined, ASK the
   developer.
2. Look up the artifact type in the branch for that architecture and place the file
   there.

## FSD branch

Layers use **numbered prefixes**, in dependency order:
`01-app` → `02-pages` → `03-widgets` → `04-features` → `05-composition` →
`06-entities` → `07-shared`.

- [invariant · desired] Plugin **registration files** (the `plugin-registration`
  factories) live in the app-init plugins layer: `01-app/plugins/<name>.ts`.
- [invariant · desired] **Shared** modal building blocks — group wrappers, group
  targets, and shared modals — live under `07-shared/ui/modals/<group>-modals/`.
- [invariant · desired] A modal that belongs to a **feature** lives in that feature
  slice: the component in `04-features/<feature>/ui/`, its open-composable in
  `04-features/<feature>/model/`.
- [invariant · desired] A modal that belongs to a **widget** lives in that widget
  slice: the component in `03-widgets/<widget>/ui/`, its open-composable in
  `03-widgets/<widget>/model/`.
- [invariant · desired] An open-composable (`use*Modal`) **always lives in the same
  slice as its modal** — never hoisted to a different layer. (So a widget modal DOES
  have a composable; it just lives in the widget, not in features.)

## Non-FSD branch

- [invariant · desired] Plugin **registration files** live in `src/plugins/<name>.ts`
  (still a factory file, never inline in `main.ts` — see `plugin-registration`).
- [invariant · desired] Modals and their open-composables live together under
  `src/components/modals/` (the `use*Modal` composable beside its modal component).

> The matrix grows as more artifact types are captured; the entries above are the
> ones captured so far.
