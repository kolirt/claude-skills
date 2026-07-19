---
name: modals
description: Use when the developer asks to add a modal/dialog in a Vue project. A capability skill — installs and registers @kolirt/vue-modal the developer's way, scaffolds the shared modal wrapper(s) and a default ConfirmModal, and shows correct usage.
---

# Modals (Vue) — capability skill (`@kolirt/vue-modal`)

Read `../../core/placement.md` first for the `{...}` location tokens used below; paths
resolve in the active architecture doc.
Defer to the `plugin-registration` skill (by name) for registering the package, and
to the `page-middlewares` skill (by name) for the route-change cleanup middleware.
Do not restate those skills' steps here.

Read `references/modal.md` and reproduce it — it holds the complete files for the
modal plugin, the shared wrappers and the default confirm modal. The etalon follows
this skill's placement convention (group infrastructure under `groups/<group>/`,
each concrete modal in its own sibling folder); the etalon registers both baseline
groups, `main` and `prompt`.

> **[invariant · desired] Read the package's own AI guide BEFORE writing any modal
> code.** `@kolirt/vue-modal` ships an agent-facing reference at
> `node_modules/@kolirt/vue-modal/AGENTS.md` — it is the authoritative source for the
> headless primitives, the `ModalRoot`/`ModalContent` contract, animation via
> `data-state`, and the **z-index / stacking rules** (which element owns the
> z-index, and how groups layer). Open and follow it; do NOT reconstruct modal
> positioning/stacking from memory or from this skill. If `AGENTS.md` is absent (older
> package version), read `node_modules/@kolirt/vue-modal/README.md` and follow its
> "🤖 For AI agents" section. This skill governs only *where files live and the
> project's wrapper/composable conventions* — the package guide governs *how the
> primitives are used and styled*.

## 1. Bootstrap — detect → install → register

- Detect: is `@kolirt/vue-modal` already installed? If yes, skip install.
- Install: `yarn add @kolirt/vue-modal reka-ui`.
- [invariant · desired] Register the package **through the `plugin-registration`
  skill** (a factory file, not inline). The modal group config lives inside that factory.
- [preference · desired] Default groups are **`main`** and **`prompt`**; the
  project adds more groups as it needs them.
- [invariant · desired] Make group names type-safe via module augmentation: extend
  `ModalGroupRegistry` with `DefineGroups<[...]>` listing every registered group name
  (see the etalon's `declare module` block).
- [preference · desired] Each group gets its own `*ModalTarget.vue` mounted in the
  root layout, rather than inline `<ModalTarget>` tags scattered in `App.vue`.

## 2. Scaffold — shared wrappers + a default ConfirmModal

- [invariant · desired] A concrete modal **never** uses `ModalRoot` / `ModalContent`
  directly. Each group has a `*ModalWrapper.vue` that owns `ModalRoot + ModalContent`,
  positioning/animation, and the close button (`useModalContext().close`). Concrete
  modals render into the wrapper's slot.
  - ✅ do: `<ConfirmModalWrapper><!-- modal body --></ConfirmModalWrapper>`
  - ❌ don't: `<ModalRoot><ModalContent>…</ModalContent></ModalRoot>` inside a concrete modal
  - why: the wrapper is the single place that knows Root/Content/styling; modals stay
    thin and consistent, and a styling change happens in one place.
- [invariant · desired] **Group infrastructure** (a group's `*ModalWrapper.vue` +
  `*ModalTarget.vue`) is kept **separate from concrete modals** — see Placement below.
- On first setup, scaffold wrappers for `main` and `prompt`, plus a default
  **`ConfirmModal`** (group `prompt`) and its `useConfirmModal` composable (§3) —
  confirmation dialogs are needed in every project. `ConfirmModal` takes the message
  and button labels as props, with sensible defaults, renders through its group
  wrapper, and uses `useModalContext<boolean>()` for `close`/`confirm` — props/types
  live in a sibling `interface.ts`, never inline-only in the `.vue` (see the etalon).

## 3. Usage — define + open

- [invariant · desired] A concrete modal sets `defineOptions({ modalGroup: '<group>' })`,
  renders through its group wrapper, and uses `useModalContext<T>()` for `close` /
  `confirm`.
- [invariant · desired] Opening a **domain** modal (feature/widget) goes through a
  dedicated `use*Modal` composable, co-located in the SAME slice as the modal. The
  call site **never** calls `openModal()` directly — it must not know the open
  details, it just opens.
  - ✅ do: a `use*Modal` composable that calls `openModal()` and catches
    `ModalClosedError` to resolve a sensible default on dismiss.
  - ❌ don't: `openModal(ConfirmModal, { props })` at the call site.
  - A **generic/shared** modal's `use*Modal` (e.g. `useConfirmModal`) is the same
    pattern, but placed in `{shared-lib}` instead — see §4.
- [preference · desired] Value-returning modals resolve a `Promise<T>` and catch
  `ModalClosedError` (dismiss → a sensible default); fire-and-forget modals swallow
  with `.catch(() => {})`.
- [invariant · desired] On route change, all open modals are closed via a **page
  middleware** (`closeAllModals` from `@kolirt/vue-modal`). Create the middleware through
  the `page-middlewares` skill (it carries the `closeModalsMiddleware` example) and
  register it globally — do not restate the middleware or its snippet here.

## 4. Placement (tokens)

- [invariant · desired] **Group infrastructure** (`*ModalWrapper.vue` +
  `*ModalTarget.vue`) → `{shared-ui}/modals/groups/<group>/` — one folder per group.
  Each group folder has a barrel `index.ts` re-exporting the wrapper and target.
- [invariant · desired] A **generic/shared concrete modal** (e.g. `ConfirmModal`) →
  `{shared-ui}/modals/<name>-modal/` — its own folder, never inside the
  group-infrastructure folder. Each concrete-modal folder has a barrel `index.ts`.
- [invariant · desired] A concrete modal folder contains: the `.vue` component, an
  **`interface.ts`** declaring its props/types (`<Name>Props`, request/variant types),
  and an `index.ts` barrel re-exporting both (component, types — see the etalon's
  `confirm-modal/index.ts`). Component props/types belong in `interface.ts`, not
  inline-only in the `.vue`.
- [invariant · desired] Its `use*Modal.ts` composable does **not** live in that same
  folder — it wraps `openModal`/`ModalClosedError` from `@kolirt/vue-modal` (an
  external system) as an app-wide singleton, which is `{shared-lib}`'s role, not
  `{shared-ui}`'s (see `core/placement.md`). It goes in its own
  `{shared-lib}/<name>-modal/` folder with its own barrel, and is imported by
  consumers from there (see the etalon's `{shared-lib}/confirm-modal/`).
- [invariant · desired] A **domain modal** lives in its owning slice with its
  composable co-located: feature → `{feature}` (`ui/` + `model/`); widget → `{widget}`
  (`ui/` + `model/`). The `use*Modal` always lives in the same slice as its modal —
  this co-location rule is for domain modals only; a generic/shared modal follows the
  `{shared-lib}` split above instead.
