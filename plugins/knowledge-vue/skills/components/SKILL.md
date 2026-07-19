---
name: components
description: Use when creating, extracting, splitting, or reusing a Vue component — when defining component props/emits/slots/variants, when deciding whether a chunk of markup deserves its own component, when adding a variant to an existing component, or when wrapping a primitive. Covers reuse discovery, component boundaries, the component package layout, and the public API surface. Form controls, dialogs, layouts, and pages have their own skills.
---
# components (Vue) — reuse, boundaries, and the component package
Read `references/component.md` and reproduce it.

## 1. Placement
Read `../../core/placement.md` first (the token vocabulary). Token → path resolution
lives in the active architecture doc `core/architectures/<a>.md`, already loaded by
`vue-work` step 0. Every location in this skill is a **token** — never a concrete path.
- [invariant · desired] This skill is **runtime-agnostic** — decomposition and reuse apply
  under Nuxt too. But under `runtime = nuxt` step 0 sets no `architecture`, so there is **no
  resolver for these tokens**: ASK the developer where the directories live. Do not invent one.
**SCOPE.** The package layout, API, cva, and `cn()` rules below apply to **reusable UI
components**: `{shared-ui}`, `{composition}`, and the `ui/` segment of a `{feature}` /
`{widget}` / `{entity}` slice. Not pages/layouts (single SFCs — `pages`/`layouts`) or modals.

## 2. Reuse-first gate
- [invariant · desired] Before creating **any** new reusable UI component — including
  extracting a chunk out of page or layout markup into its own component — run the
  discovery protocol in section 3 first. Creating the page, layout, or modal *itself*
  under its own skill does **not** trigger the gate.
- [invariant · desired] A written **reuse search summary** is required only for a shared
  candidate (`{shared-ui}` / `{composition}`): which spaces were scanned, what was found.
  A slice-local `ui/` component still gets the search, but no write-up.
- [anti-pattern · desired] Silently creating a near-duplicate of an existing component.
✅ do: scan the shared barrels, then say "scanned `{shared-ui}` + `{composition}` barrels,
no card primitive found → creating one".
❌ don't: open a blank `.vue` file the moment a component is requested — why: the
knowledge base fills with twins that drift apart and are never reconciled.

## 3. Discovery protocol
- [invariant · desired] Search **shared-first**, in this order, purely by token:
  1. Barrels and folder names of `{shared-ui}`.
  2. Barrels and folder names of `{composition}`.
  3. The **current** slice's component space — the `ui/` segment of the `{feature}` /
     `{widget}` / `{entity}` slice, as the **active architecture doc** resolves it (both
     architectures give these three the same inner shape). `{composition}` has **no** `ui/`
     segment — the slice **is** the component folder (`fsd.md` §5 / `non-fsd.md` §2) — scan it directly.
  4. Sibling slices — **signal only**: a twin exists → candidate for promotion to shared.
     Never an import source; cross-slice import rules belong to the active architecture doc.
**Stopping rules.** Start from **barrels and folder names**, not a `grep` over `**/*.vue`
— the barrel is the public API; if a component is not in one, it is not reusable anyway.
- **Stop** when either holds: a semantic match is found that the target can **legally
  import** (a match in an unreachable slice is a *promotion signal*, not a stop); or the
  ordered spaces above are exhausted.
- [anti-pattern · desired] A recursive full-text search over the whole repository to
  "make sure" — slow, noisy, and finds call sites rather than components.
- In non-FSD, `{shared-ui}`/`{composition}`/`{feature}`/`{widget}` each resolve to their
  **own** directory (`components/ui`, `components/composition`, `components/features`,
  `components/widgets`) — nothing collapses; scan each bucket once.
Note: if an in-tree `CONVENTIONS.md` sits next to `{shared-ui}`, read it. On conflict
between that file and the actual code, **the code is the truth**.
## 4. Reuse decision
**Decision order (entry point).** Run in order, **stop at the first match**. Terminates in
exactly one verdict: **reuse as-is · extend via an existing variant axis · wrap · create
new · escalate**. The rules after it are the detail behind each step.

| # | Question (binary) | Yes → verdict | No → |
|---|---|---|---|
| 1 | Did discovery (section 3) find a legally importable component whose **purpose** matches — the same domain concept or UI contract? | go to 2 | **create new** |
| 2 | Does its **current API** already cover the need, with no code change? | **reuse as-is** | go to 3 |
| 3 | Is the difference **purely presentational** and expressible as a value on an **existing** variant axis, added additively? | **extend via an existing variant axis** | go to 4 |
| 4 | Is the difference a **domain preset or composition** over the unchanged contract, carrying a named concept of its own? | **wrap** | go to 5 |
| 5 | Everything else — behavioural/structural change, a new axis on a shared component, or an unclear fit. | **escalate to the developer** | — |

- [invariant · desired] **Semantics decide, not looks.** Step 1's "purpose match" is a
  match of **purpose** — domain concept or UI contract, not appearance. Visual similarity
  without shared semantics is a **new component**; a one-off, page-specific look never
  reaches step 3.
- [invariant · desired] When the component has a **variant system** (cva), a new visual
  case goes onto an **existing axis** (`intent: 'ghost'`, `size: 'lg'`). A twin component
  for a variant is forbidden.
- [invariant · desired] **Variant boundaries.** A variant must not smuggle in a foreign
  domain (a `product-card` value on a `UserCard`) or change behaviour/structure instead of
  presentation. A one-off, page-specific look is a **local class override** at the call
  site, not a new variant.
- [invariant · desired] **Extension is additive only.** Adding to an existing component
  must never break existing call sites: new props are optional with a default, new variant
  values are added to an axis. No boolean variant flags (`isGhost`, `small`) — they
  multiply combinatorially and bypass the variant system.
- [invariant · desired] **Wrap branch.** When the existing component's contract matches
  but the consumer needs a domain preset or composition, create a **wrapper** that
  composes it with fixed props/slots **without modifying the original**. The wrapper must
  add **semantic value** — a named concept of its own — not merely rename the original.
- Edge cases that fit none of the branches above → **escalate to the developer**; do not
  guess.
✅ do: add a value to the existing variant axis (`flat-button` and `tab-button` in
`references/component.md` both wrap `base-button` this way, adding their own `cva` axis
instead of a twin).
❌ don't: `{shared-ui}/ghost-button/GhostButton.vue` — a twin of `BaseButton`; or a foreign
domain smuggled onto a variant axis, e.g. `userCardVariants({ variant: 'product-card' })`.
## 5. Extraction signals
- [invariant · desired] Extract markup into its own component only when **at least one**
  real signal is present: used in **2+ places**; a **named domain or UI concept** with its
  own contract; owns **independent state or behaviour**; or the parent template has become
  genuinely unreadable.
- [anti-pattern · desired] Extracting "just for cleanliness". Trivial, parent-specific
  markup stays inline in the parent.
- [anti-pattern · desired] **Over-extraction** — a forest of one-line wrappers each used
  once. The main failure mode of this skill: it inflates file count, hides markup behind
  indirection, and creates fake reuse surface.
- [invariant · desired] Repeated **stateful logic with no markup of its own** → a
  **composable**, not a component.
✅ do: keep a one-off `<div class="flex gap-2">…</div>` inline in the page.
❌ don't: create `CardHeaderTitleWrapper.vue` used once — why: a file and an import for
zero reuse and zero named concept.

## 6. Component package
Scoped to **reusable UI components** (`{shared-ui}`, `{composition}`, slice `ui/`).
- [invariant · desired] One component = one **kebab-case folder** inside its family:
  `{shared-ui}/buttons/base-button/BaseButton.vue` (PascalCase SFC) + `interface.ts`
  (props/emits + cva variants) + `index.ts` (barrel: component + types + variants) +
  optional `helpers.ts` and `context.ts` (provide/inject key for compound components).
  See `references/component.md` for real instances, including the barrels.
- [anti-pattern · legacy] Components dropped into a staging folder (`components/new/`,
  `ui/tmp/`) without the canonical structure — no `interface.ts`, no `index.ts` barrel.
- [anti-pattern · legacy] A lone `.vue` SFC sitting among functional `.ts` icon
  components — pick one shape for the family, do not mix.

## 7. Component API
- [invariant · desired] **Props** are always declared as an `interface XxxProps` in
  `interface.ts` — never inline in the `.vue`. Extend the base contract when wrapping a
  primitive (e.g. `PrimitiveProps` from reka-ui) instead of re-listing its props — **never
  redeclare an inherited prop**. A component that accepts styling exposes
  `class?: HTMLAttributes['class']`. Data-typed components use a generic:
  `<script setup lang="ts" generic="TData">`. See `references/component.md`
  (`base-button/interface.ts`, `tab-button-group/interface.ts`).
- [invariant · desired] **Emits** are a named `XxxEmits` interface in `interface.ts`,
  consumed as `defineEmits<BaseButtonEmits>()`. Event names are short verbs — `load`,
  `submit`, `close` — not `onLoadData` or `buttonClicked`.
- [anti-pattern · legacy] An inline `defineEmits<{ … }>()` object literal in the `.vue`.
- [invariant · desired] **v-model** uses `defineModel<T>()` **exclusively**. Never a manual
  `modelValue` prop plus an `update:modelValue` emit. See `tab-button-group` in
  `references/component.md` for a real `defineModel<T>()` usage.
- **Slots**: extension points are scoped slots with fallback content inside `<slot>`, so
  the component works with zero slots passed, e.g. `<slot name="error" :error="error">
  <BaseAlert :message="error.message" /></slot>`. **Headless extension** across a compound
  component family goes through a **provide/inject context** (`context.ts`): a `Symbol`
  key, a `provide<Group>` used by the root, and a `use<Group>` consumed by the parts.
  Children never reach into the parent by `$parent` or prop drilling.
- [preference · desired] **Minimal surface** — keep the props list minimal. A bloated
  props list is a signal to compose or split the component, not add another flag.
- [invariant · desired] **Imperative API** (`defineExpose`) is for actions that **cannot**
  be expressed via props or `v-model` — `reset()`, `scrollToTop()`. State a parent wants to
  read is a `defineModel` or a prop, never an exposed ref.
✅ do: `defineExpose({ reset, scrollToTop })`.
❌ don't: expose internal refs so the parent can mutate them — why: it makes the
component's contract invisible and untypeable at the call site.

## 8. Variants & styling
Two independent gates — do not collapse them: the **cva rules** (variant declaration, the
size scale) apply **only when the component has a variant system** — a project without
cva skips them, do not retrofit it. The **`cn()` merging rules** apply to **any component
that composes Tailwind classes**, with or without variants — a project without Tailwind
skips these instead.
- [invariant · desired] cva is declared in `interface.ts`, next to the props it types:
  `xxxVariants` + the derived `VariantProps` type. Not in the `.vue`, not in a separate
  styles file.
- [invariant · desired] The **size scale is only** `xs → sm → md → lg → xl → 2xl`, with
  `md` as the default. `small` / `normal` / `large` / `medium` are forbidden — a mixed
  scale makes sizes non-interchangeable across the UI kit.
- [invariant · desired] Tailwind classes are merged with `cn()` (twMerge + clsx) from
  `{shared-utils}`. Raw string concatenation of class lists is an anti-pattern — it leaves
  conflicting utilities in the output.
- [invariant · desired] **The consumer's class wins** — `props.class` is merged last, e.g.
  `:class="cn(xxxVariants({ variant: props.variant }), props.class)"`. See `flat-button` and
  `tab-button` in `references/component.md` for real instances, wrapping `base-button`.
- [preference · legacy] Omitting the trailing `<style scoped></style>` block. Keep it even
  when empty, so adding a scoped rule later never changes the file's shape.
**LIFECYCLE — `cn()` setup.** Precondition: `cn`/`twMerge` assume a Tailwind-class project
— without Tailwind, no `tailwind-merge`, merge classes with the project's own mechanism
and skip below. Otherwise: (1) detect first — if `cn` already exists in `{shared-utils}`,
use it, change nothing; (2) install if absent, `yarn add clsx tailwind-merge` — only these
two; (3) scaffold the utility in `{shared-utils}`, two files — the helper plus its
re-export from the location's barrel, see `{shared-utils}/cn.ts` in
`references/component.md`; (4) cva is a separate step — install `class-variance-authority`
**only** when the component actually needs a variant system; a component that merges
classes but declares no variants never pulls cva in.
- [invariant · desired] `cn` is a **pure utility** and lives in `{shared-utils}`, **not**
  in `{shared-lib}` — pure widely-used functions belong to the utils location, `{shared-lib}`
  is reserved for modules with an external boundary.
- [invariant · desired] `cn` is **not a Vue plugin** — the `plugin-registration` skill does
  not apply. It is imported where it is used; nothing is registered on the app instance.

## 9. Dumb components only
- [invariant · desired] Shared components are **purely presentational**. No `useQuery`, no
  mutations, no store access inside a `{shared-ui}` or `{composition}` component. Data
  arrives through props.
- **Query-as-prop**: when a component must render loading/error/empty states, the query
  object is passed in as a prop and the component renders its states. Follow the
  `InfiniteQueryView` component from the `tanstack-query` skill; invent no second pattern.
✅ do: `<InfiniteQueryView :query="postsQuery"><template #item="{ item }">…</template></InfiniteQueryView>`
❌ don't: call `useQuery` inside a shared component — why: it welds a domain endpoint into
a domain-neutral primitive and makes the component untestable and unreusable.

## 10. Imports & barrels
- [invariant · desired] **No auto-import and no global registration.** Components are
  imported explicitly at every call site; nothing is registered via `app.component`.
- [invariant · desired] **Each space is consumed through its own public barrel**: a shared
  UI primitive from its **family barrel** in `{shared-ui}` (`{shared-ui}/buttons`,
  `{shared-ui}/icons`, `{shared-ui}/form`, … — there is no root `{shared-ui}` mega-barrel);
  a `{composition}` component from **its own slice barrel** (`{composition}/<name>`, e.g.
  `{composition}/user-summary` — `{composition}` itself is a bucket, not an importable
  barrel); a slice-local `ui/` component from the **owning slice's barrel**. Deep-importing past a barrel — a component
  file directly, or a sub-folder barrel behind the space's public one — is the
  anti-pattern, in every space. **Whether** an import is legal at all (cross-slice reach,
  layer direction) is decided by the active architecture doc, not here; this rule only
  fixes the **entry point** once allowed.
- **Prop delegation.** When forwarding props to a wrapped primitive, use the delegation
  helpers (`delegatePrimitiveProps`, `mergeDelegatedProps`) rather than hand-writing a
  spread of every prop. They use Vue reactivity, so they live in `{shared-ui}/internal/`,
  not `{shared-utils}` (pure functions only). Detect first and use as-is; if absent and
  genuinely needed, scaffold there; otherwise follow the pattern manually. See
  `references/component.md` (`{shared-ui}/internal/delegatePrimitiveProps.ts`,
  `mergeDelegatedProps.ts`).
- [anti-pattern · desired] Inventing helper APIs that the project does not have. Detect,
  then scaffold, then use — never assume a helper exists because it "should".

## 11. Headless primitives
- [preference · desired] **reka-ui** is the headless base for polymorphic primitives — its
  `Primitive` component with the `as` / `asChild` props gives the component a swappable
  root element without duplicating markup. Install-or-detect: `yarn add reka-ui` only when
  a primitive genuinely needs it and the package is absent.
- [invariant · desired] **One shared base root per component family.** A family (buttons,
  cards, badges) has a single base component owning the root element, variants, and
  delegation — the `BaseButton` pattern. Siblings compose that base; they do not
  re-implement the root.
✅ do: `BaseButton` owns the root; `IconButton` wraps `BaseButton` with fixed props.
❌ don't: give each button-ish component its own `<button>` root and its own cva table —
why: variants drift and the family stops looking like one family.

## 12. Defer by name
Do not restate what another skill owns — defer to it:

| Topic | Skill |
|---|---|
| Form inputs and controls (checkbox, select, switch, …) | `form-elements` |
| Button-specific conventions (variant catalog, sizing, states) | a future dedicated skill — not yet authored |
| Modals, dialogs, and modal primitives | `modals` |
| Page layouts | `layouts` |
| Pages and route-level components | `pages` |
| Shared reactive state | `stores` |
| Data fetching, mutations, cache | `tanstack-query` |
| Placement, layers, promotion, cross-slice import rules | the active architecture doc (`core/architectures/<a>.md`) |
| SSR safety and hydration | `hydration` + the active project-type doc (`core/project-types/<t>.md`) |

## Related skills (by name)
form-elements · modals · layouts · pages · stores · tanstack-query · hydration
