---
name: modals
description: Use when the developer asks to add a modal/dialog in a Vue project. A capability skill — installs and registers @kolirt/vue-modal the developer's way, scaffolds the shared modal wrapper(s) and a default ConfirmModal, and shows correct usage.
---

# Modals (Vue) — capability skill (`@kolirt/vue-modal`)

Read `../../core/shared-wrapper-discipline.md` first (modals introduce UI that must
live behind a shared wrapper, never inlined at the call site).
Read `../../core/placement.md` first (where modal files go — FSD vs non-FSD).
Defer to the `plugin-registration` skill (by name) for registering the package, and
to the `page-middlewares` skill (by name) for the route-change cleanup middleware.
Do not restate those skills' steps here.

## 1. Bootstrap — detect → install → register

- Detect: is `@kolirt/vue-modal` already installed? If yes, skip install.
- Install: `yarn add @kolirt/vue-modal reka-ui`.
- [invariant · desired] Register the package **through the `plugin-registration`
  skill** (a factory file, not inline). The modal group config lives inside that
  factory.
- [preference · desired] Default groups are **`default`** and **`confirm`**; the
  project adds more groups as it needs them.
- [invariant · desired] Make group names type-safe via module augmentation:
  ```ts
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
- On first setup, scaffold wrappers for `default` and `confirm`, plus a default
  **`ConfirmModal`** (group `confirm`) and its `useConfirmModal` composable (§3) —
  confirmation dialogs are needed in every project. `ConfirmModal` takes the message
  and button labels as props, with sensible defaults:
  ```vue
  <!-- ConfirmModal.vue (group: confirm) -->
  <script lang="ts" setup>
  import { useModalContext } from '@kolirt/vue-modal'
  import ConfirmModalWrapper from './ConfirmModalWrapper.vue'

  withDefaults(defineProps<{
    title?: string
    message: string
    confirmText?: string
    cancelText?: string
  }>(), { confirmText: 'Confirm', cancelText: 'Cancel' })

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
  composable, co-located in the SAME slice as the modal** (a widget modal's composable
  lives in the widget, a feature modal's in the feature, a shared modal's in shared).
  The call site **never** calls `openModal()` directly — it must not know the open
  details, it just opens.
  - ✅ do:
    ```ts
    // useConfirmModal.ts (next to ConfirmModal.vue)
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

    // call site — knows nothing about openModal:
    const { confirm } = useConfirmModal()
    if (await confirm({ message: 'Delete this item?' })) { /* ... */ }
    ```
  - ❌ don't: `openModal(ConfirmModal, { props })` at the call site.
- [preference · desired] Value-returning modals resolve a `Promise<T>` and catch
  `ModalClosedError` (dismiss → a sensible default); fire-and-forget modals swallow
  with `.catch(() => {})`.
- [invariant · desired] On route change, all open modals are closed via a **page
  middleware** — create it through the `page-middlewares` skill and register it
  globally; do not restate middleware mechanics here. The close call is:
  ```ts
  import { closeAllModals, isOpened } from '@kolirt/vue-modal'
  if (isOpened.value) await closeAllModals({ ignoreGuard: true, instantExit: true })
  ```
