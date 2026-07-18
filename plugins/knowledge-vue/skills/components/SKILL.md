---
name: components
description: Use when creating, extracting, splitting, or reusing a Vue component — when defining component props/emits/slots/variants, when deciding whether a chunk of markup deserves its own component, when adding a variant to an existing component, or when wrapping a primitive. Covers reuse discovery, component boundaries, the component package layout, and the public API surface. Form controls, dialogs, layouts, and pages have their own skills.
---

# components (Vue) — reuse, boundaries, and the component package

## 1. Placement

Read `../../core/placement.md` first (the token vocabulary).

Token → path resolution lives in the active architecture doc `core/architectures/<a>.md`,
already loaded by `vue-work` step 0. Every location in this skill is expressed as a
**token** — never as a concrete path.

- [invariant · desired] This skill is **runtime-agnostic** — component decomposition and
  reuse apply under Nuxt too. But under `runtime = nuxt` step 0 establishes no
  `architecture`, so there is **no resolver for these tokens**: ASK the developer where
  the corresponding directories live in their Nuxt project before placing any file. Do
  not assume an FSD or flat layout, and do not invent a resolution.

**SCOPE.** The package layout, API, cva, and `cn()` rules below apply to **reusable UI
components**: `{shared-ui}`, `{composition}`, and the `ui/` segment of a `{feature}` /
`{widget}` / `{entity}` slice. They do **not** apply to:

- **Pages** and **layouts** — single SFCs (`HomePage.vue`, `DefaultLayout.vue`), no
  package folder. See the `pages` and `layouts` skills.
- **Modals** — they keep the folder structure defined by the `modals` skill.

## 2. Reuse-first gate

- [invariant · desired] Before creating **any** new reusable UI component — including
  extracting a chunk out of page or layout markup into its own component — run the
  discovery protocol in section 3 first. Creating the page, layout, or modal *itself*
  under its own skill does **not** trigger the gate.
- [invariant · desired] A written **reuse search summary** in the reply is required only
  when the component is a candidate for shared (`{shared-ui}` or `{composition}`): state
  which spaces were scanned and what was or was not found. For a slice-local `ui/`
  component the search still happens, but needs no write-up.
- [anti-pattern · desired] Silently creating a near-duplicate of an existing component.

✅ do: scan the shared barrels, then say "scanned `{shared-ui}` + `{composition}` barrels,
no card primitive found → creating one".
❌ don't: open a blank `.vue` file the moment a component is requested — why: the
knowledge base fills with twins that drift apart and are never reconciled.

## 3. Discovery protocol

- [invariant · desired] Search **shared-first**, in this order, purely by token:
  1. Barrels and folder names of `{shared-ui}`.
  2. Barrels and folder names of `{composition}`.
  3. The **current** slice's component space — the `{feature}` / `{widget}` / `{entity}`
     location as the **active architecture doc** resolves it (a `ui/` segment where the
     architecture has one; the flat component tree where it does not). Where those tokens
     collapse to one tree, scan that tree **once** (see the stopping rules below).
  4. Sibling slices — as a **signal only**: a twin exists → the component is a candidate
     for promotion to shared. Never as an import source; cross-slice import rules belong
     to the active architecture doc (`core/architectures/<a>.md`).

**Stopping rules.**

- Start from **barrels and folder names**, not from a `grep` over `**/*.vue`. The barrel
  is the public API — if a component is not in one, it is not reusable anyway.
- **Stop** when either holds:
  - a semantic match is found that the target can **legally import** (layer direction and
    slice isolation per the active architecture doc). A match sitting in an unreachable
    slice is a *promotion signal*, not a stop; or
  - the ordered spaces above are exhausted.
- [anti-pattern · desired] A recursive full-text search over the whole repository to
  "make sure". It is slow, noisy, and finds call sites rather than components.
- In flat projects several tokens may resolve to the **same tree**. Scan such a space
  **once** — do not repeat the same directory per token.

Note: if an in-tree `CONVENTIONS.md` sits next to `{shared-ui}`, read it. On conflict
between that file and the actual code, **the code is the truth**.

## 4. Reuse decision

**Decision order (entry point).** Run these in order and **stop at the first match**. The
procedure terminates in exactly one verdict: **reuse as-is · extend via an existing variant
axis · wrap · create new · escalate**. The rules after it are the detail behind each step.

| # | Question (binary) | Yes → verdict | No → |
|---|---|---|---|
| 1 | Did discovery (section 3) find a legally importable component whose **purpose** matches — the same domain concept or UI contract? | go to 2 | **create new** |
| 2 | Does its **current API** already cover the need, with no code change? | **reuse as-is** | go to 3 |
| 3 | Is the difference **purely presentational** and expressible as a value on an **existing** variant axis, added additively? | **extend via an existing variant axis** | go to 4 |
| 4 | Is the difference a **domain preset or composition** over the unchanged contract, and does the result carry a named concept of its own? | **wrap** | go to 5 |
| 5 | Everything else — a behavioural or structural change, a new axis on a shared component, or an unclear fit. | **escalate to the developer** | — |

Step 1's "purpose match" is judged by the semantics rule below, not by looks. A one-off,
page-specific look never reaches step 3 — it is a local class override at the call site.

- [invariant · desired] **Semantics decide, not looks.** Reuse or extend only on a match
  of **purpose** — the domain concept or the UI contract. Visual similarity without shared
  semantics is a **new component**.
- [invariant · desired] When the component has a **variant system** (cva), a new visual
  case goes onto an **existing axis** (`intent: 'ghost'`, `size: 'lg'`). A twin component
  for a variant is forbidden.
- [invariant · desired] **Variant boundaries.** A variant must not:
  - smuggle in a foreign domain (a `product-card` value on a `UserCard`);
  - change behaviour or structure instead of presentation.
  A one-off, page-specific look is a **local class override** at the call site, not a new
  variant on the shared component.
- [invariant · desired] **Extension is additive only.** Adding to an existing component
  must never break existing call sites: new props are optional with a default, new variant
  values are added to an axis. No boolean variant flags (`isGhost`, `small`) — they
  multiply combinatorially and bypass the variant system.
- [invariant · desired] **Wrap branch.** When the existing component's contract matches
  but the consumer needs a domain preset or composition, create a **wrapper** that
  composes the existing component with fixed props/slots **without modifying the
  original**. The wrapper must add **semantic value** — a named concept with its own
  meaning — not merely rename the original.
- Edge cases that fit none of the branches above → **escalate to the developer**; do not
  guess.

✅ do:
```vue
<!-- a ghost button = a value on the existing intent axis -->
<BaseButton intent="ghost" size="sm">Cancel</BaseButton>
```
```ts
// interface.ts — the axis grows, the call sites do not break
export const buttonVariants = cva('inline-flex items-center', {
  variants: {
    intent: { solid: '…', outline: '…', ghost: '…' }, // ← 'ghost' added here
    size: { xs: '…', sm: '…', md: '…', lg: '…', xl: '…', '2xl': '…' },
  },
  defaultVariants: { intent: 'solid', size: 'md' },
})
```

❌ don't:
```
{shared-ui}/ghost-button/GhostButton.vue   ← a twin of BaseButton
```
```ts
// a foreign domain smuggled onto a variant axis
userCardVariants({ variant: 'product-card' })
```

## 5. Extraction signals

- [invariant · desired] Extract markup into its own component only when **at least one**
  real signal is present:
  1. it is used in **2+ places**;
  2. it is a **named domain or UI concept** with its own contract (props/emits);
  3. it owns **independent state or behaviour**;
  4. the parent template has become genuinely unreadable.
- [anti-pattern · desired] Extracting "just for cleanliness". Trivial, parent-specific
  markup stays inline in the parent.
- [anti-pattern · desired] **Over-extraction** — a forest of one-line wrapper components
  each used exactly once. This is the main failure mode of this skill: it inflates the
  file count, hides the actual markup behind indirection, and creates fake reuse surface.
- [invariant · desired] Repeated **stateful logic with no markup of its own** → a
  **composable**, not a component.

✅ do: keep a one-off `<div class="flex gap-2">…</div>` inline in the page.
❌ don't: create `CardHeaderTitleWrapper.vue` used once — why: it adds a file and an
import for zero reuse and zero named concept.

## 6. Component package

Scoped to **reusable UI components** (`{shared-ui}`, `{composition}`, slice `ui/`).

- [invariant · desired] One component = one **kebab-case folder**. Inside it:

```
{shared-ui}/base-button/
├── BaseButton.vue      # PascalCase SFC
├── interface.ts        # props/emits interfaces + cva variants
├── index.ts            # barrel: component + types + variants
├── helpers.ts          # optional — pure component-local helpers
└── context.ts          # optional — provide/inject key for compound components
```

```ts
// index.ts
export { default as BaseButton } from './BaseButton.vue'
export * from './interface'
```

- Scope carve-out, restated: **pages and layouts are single SFCs** (`HomePage.vue`,
  `DefaultLayout.vue`) and get no package folder; **modals** follow the folder structure
  owned by the `modals` skill.
- [anti-pattern · legacy] Components dropped into a staging folder (`components/new/`,
  `ui/tmp/`) without the canonical structure — no `interface.ts`, no `index.ts` barrel.
- [anti-pattern · legacy] A lone `.vue` SFC sitting among functional `.ts` icon
  components — pick one shape for the family, do not mix.

## 7. Component API

**Props.**

- [invariant · desired] Props are always declared as an `interface XxxProps` in
  `interface.ts` — never inline in the `.vue`.
- [invariant · desired] Extend the base contract when wrapping a primitive (e.g.
  `PrimitiveProps` from reka-ui) instead of re-listing its props. **Never redeclare an
  inherited prop.**
- [invariant · desired] A component that accepts styling exposes
  `class?: HTMLAttributes['class']`.
- Data-typed components use a generic: `<script setup lang="ts" generic="TData">`.

```ts
// interface.ts
import type { HTMLAttributes } from 'vue'
import type { PrimitiveProps } from 'reka-ui'
import { cva, type VariantProps } from 'class-variance-authority'

export interface BaseButtonProps extends PrimitiveProps {
  class?: HTMLAttributes['class']
  intent?: ButtonVariants['intent']
  size?: ButtonVariants['size']
  loading?: boolean
}

export interface BaseButtonEmits {
  submit: []
}

export type ButtonVariants = VariantProps<typeof buttonVariants>
```

**Emits.**

- [invariant · desired] Emits are a **named `XxxEmits` interface** in `interface.ts`,
  consumed as `defineEmits<BaseButtonEmits>()`. Event names are short verbs — `load`,
  `submit`, `close` — not `onLoadData` or `buttonClicked`.
- [anti-pattern · legacy] An inline `defineEmits<{ … }>()` object literal in the `.vue`.

**v-model.**

- [invariant · desired] Two-way binding uses `defineModel<T>()` **exclusively**. Never a
  manual `modelValue` prop plus an `update:modelValue` emit.

```vue
<script setup lang="ts">
const model = defineModel<string>({ required: true })
</script>
```

**Slots.**

- Extension points are **scoped slots with fallback content** inside `<slot>`, so the
  component works with zero slots passed:

```vue
<slot name="skeleton"><BaseSkeleton /></slot>
<slot name="error" :error="error"><BaseAlert :message="error.message" /></slot>
```

- **Headless extension** across a compound component family goes through a
  **provide/inject context** (`context.ts`): a `Symbol` key, a `provide{Group}` used by the
  root, and a `use{Group}` consumed by the parts. Children never reach into the parent by
  `$parent` or by prop drilling through every level.

**Minimal surface.**

- [preference · desired] Keep the props list **minimal**. A bloated props list is a signal
  to **compose or split** the component, not to add another flag.

**Imperative API.**

- [invariant · desired] `defineExpose` is for actions that **cannot** be expressed via
  props or `v-model` — `reset()`, `scrollToTop()`. State that a parent wants to read is a
  `defineModel` or a prop, never an exposed ref.

✅ do: `defineExpose({ reset, scrollToTop })`.
❌ don't: expose internal refs so the parent can mutate them — why: it makes the
component's contract invisible and untypeable at the call site.

## 8. Variants & styling

Two independent gates here — do not collapse them:

- The **cva rules** (variant declaration, the size scale) apply **only when the component
  has a variant system**. A project that does not use cva skips them — do not retrofit cva
  onto a project that has none.
- The **`cn()` merging rules** apply to **any component that composes Tailwind classes**,
  with or without variants — a variant-free component still merges `props.class` last. A
  project that does not use Tailwind skips these instead.

- [invariant · desired] cva is declared in `interface.ts`, next to the props it types:
  `xxxVariants` + the derived `VariantProps` type. Not in the `.vue`, not in a separate
  styles file.
- [invariant · desired] The **size scale is only** `xs → sm → md → lg → xl → 2xl`, with
  `md` as the default. `small` / `normal` / `large` / `medium` are forbidden — a mixed
  scale makes sizes non-interchangeable across the UI kit.
- [invariant · desired] Tailwind classes are merged with `cn()` (twMerge + clsx) from
  `{shared-utils}`. Raw string concatenation of class lists is an anti-pattern — it leaves
  conflicting utilities in the output.
- [invariant · desired] **The consumer's class wins** — `props.class` is merged last:

```vue
<script setup lang="ts">
import { cn } from '{shared-utils}'
import { buttonVariants, type BaseButtonProps } from './interface'

const props = defineProps<BaseButtonProps>()
</script>

<template>
  <button :class="cn(buttonVariants({ intent: props.intent, size: props.size }), props.class)">
    <slot />
  </button>
</template>

<style scoped></style>
```

- [preference · legacy] Omitting the trailing `<style scoped></style>` block. Keep it even
  when empty, so adding a scoped rule later never changes the file's shape.

**LIFECYCLE — `cn()` setup.**

0. **Precondition.** `cn` — and `twMerge` in particular — assumes a **Tailwind-class
   project**: its whole job is resolving conflicting Tailwind utilities. A project that
   does not use Tailwind gets **no** `tailwind-merge`; merge classes with the project's own
   mechanism instead, and do not run the steps below.
1. **Detect first.** If `cn` already exists in `{shared-utils}`, use it and change nothing.
2. **Install if absent:** `yarn add clsx tailwind-merge` — these two, and only these two,
   are what `cn` needs.
3. **Scaffold** the utility in `{shared-utils}`, **two files**: the helper plus its
   re-export from the location's barrel, which is what makes the token-root import in the
   example above resolve.

```ts
// {shared-utils}/cn.ts
import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs))
}
```

```ts
// {shared-utils}/index.ts — the pure barrel; add the line if the barrel already exists
export { cn } from './cn'
```

4. **cva is a separate step.** Install `class-variance-authority` **only** when the
   component actually needs a variant system — the gate at the top of this section. A
   component that merges classes but declares no variants never pulls cva in.

- [invariant · desired] `cn` is a **pure utility** and lives in `{shared-utils}`, **not**
  in `{shared-lib}` — per the active architecture doc, pure widely-used functions belong to
  the utils location and `{shared-lib}` is reserved for modules with an external boundary.
- [invariant · desired] `cn` is **not a Vue plugin** — the `plugin-registration` skill does
  not apply. It is imported where it is used; nothing is registered on the app instance.

## 9. Dumb components only

- [invariant · desired] Shared components are **purely presentational**. No `useQuery`, no
  mutations, no store access inside a `{shared-ui}` or `{composition}` component. Data
  arrives through props.
- **Query-as-prop**: when a component must render loading/error/empty states, the query
  object itself is passed in as a prop and the component renders its states. The canonical
  example in this knowledge base is the `InfiniteQueryView` component described by the
  `tanstack-query` skill — follow it rather than inventing a second pattern.

✅ do: `<InfiniteQueryView :query="postsQuery"><template #item="{ item }">…</template></InfiniteQueryView>`
❌ don't: call `useQuery` inside a shared component — why: it welds a domain endpoint into
a domain-neutral primitive and makes the component untestable and unreusable.

## 10. Imports & barrels

- [invariant · desired] **No auto-import and no global registration.** Components are
  imported explicitly at every call site; nothing is registered via `app.component`.
- [invariant · desired] **Each space is consumed through its own public barrel.** Import:
  - a shared UI primitive → from the **root `{shared-ui}` barrel**;
  - a `{composition}` component → from the **`{composition}` barrel**;
  - a slice-local `ui/` component → from the **owning slice's barrel**.

  Deep-importing past a barrel — a component file directly, or a sub-folder barrel behind
  the space's public one — is the anti-pattern, in every space. **Whether** a given import
  is legal at all (cross-slice reach, layer direction) is decided by the active
  architecture doc (`core/architectures/<a>.md`), not here; this rule only fixes the
  **entry point** once the import is allowed.
- **Prop delegation.** When forwarding props to a wrapped primitive, use the delegation
  helpers (`delegatePrimitiveProps`, `mergeDelegatedProps`) rather than hand-writing a
  spread of every prop. Disposition, in order:
  1. **Detect** whether these helpers already exist in `{shared-utils}` — if so, use them
     as they are.
  2. If absent and a wrapper genuinely needs one, **scaffold a minimal
     `delegatePrimitiveProps`** in `{shared-utils}` on first need.
  3. Otherwise just follow the pattern manually and document it at the call site.
- [anti-pattern · desired] Inventing helper APIs that the project does not have. Detect,
  then scaffold, then use — never assume a helper exists because it "should".

## 11. Headless primitives

- [preference · desired] **reka-ui** is the headless base for polymorphic primitives — its
  `Primitive` component with the `as` / `asChild` props gives the component a swappable
  root element without duplicating markup. Install-or-detect: run `yarn add reka-ui` only
  when a primitive genuinely needs it and the package is absent.
- [invariant · desired] **One shared base root per component family.** A family (buttons,
  cards, badges) has a single base component that owns the root element, the variants, and
  the delegation — the `BaseButton` pattern. Siblings compose that base; they do not
  re-implement the root.

✅ do: `BaseButton` owns the root; `IconButton` wraps `BaseButton` with fixed props.
❌ don't: give each button-ish component its own `<button>` root and its own cva table —
why: variants drift and the family stops looking like one family.

## 12. Defer by name

Do not restate what another skill owns — defer to it:

| Topic | Skill |
|---|---|
| Form inputs and controls (checkbox, select, switch, …) | `form-elements` |
| Modals, dialogs, and modal primitives | `modals` |
| Page layouts | `layouts` |
| Pages and route-level components | `pages` |
| Shared reactive state | `stores` |
| Data fetching, mutations, cache | `tanstack-query` |
| Placement, layers, promotion, cross-slice import rules | the active architecture doc (`core/architectures/<a>.md`) |
| SSR safety and hydration | `hydration` + the active project-type doc (`core/project-types/<t>.md`) |

## Related skills (by name)

form-elements · modals · layouts · pages · stores · tanstack-query · hydration
