---
name: modals
description: Use when the developer asks to add a modal/dialog in a Vue project. A capability skill — installs and registers @kolirt/vue-modal the developer's way, scaffolds the shared modal wrapper(s) and a default ConfirmModal, and shows correct usage.
---

# Modals (Vue) — capability skill (`@kolirt/vue-modal`)

Read `../../core/placement.md` first (resolve the `{...}` location tokens used below
for the current project's architecture).
Defer to the `plugin-registration` skill (by name) for registering the package, and
to the `page-middlewares` skill (by name) for the route-change cleanup middleware.
Do not restate those skills' steps here.

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
- [preference · desired] Default groups are **`default`** and **`confirm`**; the
  project adds more groups as it needs them.
- [invariant · desired] Make group names type-safe via module augmentation:
  ```ts
  import type { DefineGroups } from '@kolirt/vue-modal'
  declare module '@kolirt/vue-modal' {
    interface ModalGroupRegistry extends DefineGroups<['default', 'confirm']> {}
  }
  ```
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
- On first setup, scaffold wrappers for `default` and `confirm`, plus a default
  **`ConfirmModal`** (group `confirm`) and its `useConfirmModal` composable (§3) —
  confirmation dialogs are needed in every project. `ConfirmModal` takes the message
  and button labels as props, with sensible defaults:
  ```ts
  // interface.ts (confirm-modal folder) — props/types live here, not inline in the .vue
  export interface ConfirmModalProps {
    title?: string
    message: string
    confirmText?: string
    cancelText?: string
  }
  ```
  ```vue
  <!-- ConfirmModal.vue (group: confirm) -->
  <script lang="ts" setup>
  import { useModalContext } from '@kolirt/vue-modal'
  import ConfirmModalWrapper from '../groups/confirm/ConfirmModalWrapper.vue'
  import type { ConfirmModalProps } from './interface'

  withDefaults(defineProps<ConfirmModalProps>(), { confirmText: 'Confirm', cancelText: 'Cancel' })

  defineOptions({ modalGroup: 'confirm' })
  const { confirm, close } = useModalContext<boolean>()
  </script>

  <template>
    <ConfirmModalWrapper>
      <h2 v-if="title">{{ title }}</h2>
      <p>{{ message }}</p>
      <button @click="close()">{{ cancelText }}</button>
      <button @click="confirm(true)">{{ confirmText }}</button>
    </ConfirmModalWrapper>
  </template>
  ```

## 3. Usage — define + open

- [invariant · desired] A concrete modal sets `defineOptions({ modalGroup: '<group>' })`,
  renders through its group wrapper, and uses `useModalContext<T>()` for `close` /
  `confirm`.
- [invariant · desired] Opening a modal goes through a **dedicated `use*Modal`
  composable, co-located in the SAME slice as the modal**. The call site **never**
  calls `openModal()` directly — it must not know the open details, it just opens.
  - ✅ do:
    ```ts
    import { ModalClosedError, openModal } from '@kolirt/vue-modal'
    import ConfirmModal from './ConfirmModal.vue'

    export function useConfirmModal() {
      function confirm(opts: {
        title?: string; message: string; confirmText?: string; cancelText?: string
      }): Promise<boolean> {
        return openModal<boolean>(ConfirmModal, { props: opts }).catch((e) => {
          if (e instanceof ModalClosedError) return false // dismissed = false
          throw e
        })
      }
      return { confirm }
    }
    ```
  - ❌ don't: `openModal(ConfirmModal, { props })` at the call site.
- [preference · desired] Value-returning modals resolve a `Promise<T>` and catch
  `ModalClosedError` (dismiss → a sensible default); fire-and-forget modals swallow
  with `.catch(() => {})`.
- [invariant · desired] On route change, all open modals are closed via a **page
  middleware** (`closeAllModals` from `@kolirt/vue-modal`). Create the middleware through
  the `page-middlewares` skill (it carries the `closeModalsMiddleware` example) and
  register it globally — do not restate the middleware or its snippet here.

## 4. Placement (tokens — resolve via `placement.md`)

- [invariant · desired] **Group infrastructure** (`*ModalWrapper.vue` +
  `*ModalTarget.vue`) → `{shared-ui}/modals/groups/<group>/` — one folder per group.
  Each group folder has a barrel `index.ts` re-exporting the wrapper and target.
- [invariant · desired] A **generic/shared concrete modal** (e.g. `ConfirmModal`) and
  its composable → `{shared-ui}/modals/<name>-modal/` — its own folder, never inside
  the group-infrastructure folder.
  Each concrete-modal folder has a barrel `index.ts`.
- [invariant · desired] A concrete modal folder contains: the `.vue` component, an
  **`interface.ts`** declaring its props/types (`<Name>Props`, request/variant types),
  its `use*Modal.ts` composable, and an `index.ts` barrel re-exporting all three.
  Component props/types belong in `interface.ts`, not inline-only in the `.vue`.
  ```ts
  // <name>-modal/index.ts
  export { default as <Name>Modal } from './<Name>Modal.vue'
  export type { <Name>ModalProps } from './interface'
  export { use<Name>Modal } from './use<Name>Modal'
  ```
- [invariant · desired] A **domain modal** lives in its owning slice with its
  composable co-located: feature → `{feature}` (`ui/` + `model/`); widget → `{widget}`
  (`ui/` + `model/`). The `use*Modal` always lives in the same slice as its modal.
