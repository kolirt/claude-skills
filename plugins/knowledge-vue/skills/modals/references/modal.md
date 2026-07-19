Full-file etalon for `@kolirt/vue-modal`: the `createModal` plugin factory, the
group-infrastructure pair (`*ModalWrapper.vue` + `*ModalTarget.vue`) for the
baseline groups `main` (general-purpose) and `prompt` (confirmation dialogs),
the shared `ModalOverlay.vue`, the family barrel `{shared-ui}/modals/index.ts`,
and the default `ConfirmModal` with its `useConfirmModal` composable. Further
groups are added per project need by the same pattern. Factory registration
(`createModal()` from a composition root) is owned by the `plugin-registration`
skill's etalon, not duplicated here.

Deliberate deviation: `useConfirmModal` wraps `openModal`/`ModalClosedError` as
an app-wide singleton, not a domain-neutral component, so it lives in
`{shared-lib}/confirm-modal/` rather than `{shared-ui}`; the
`{shared-ui}/modals/confirm-modal/` folder keeps only the `.vue`, `interface.ts`,
and their barrel.

## Files
- `{plugins}/modal.ts`
- `{shared-ui}/modals/ModalOverlay.vue`
- `{shared-ui}/modals/groups/main/MainModalWrapper.vue`
- `{shared-ui}/modals/groups/main/MainModalTarget.vue`
- `{shared-ui}/modals/groups/main/index.ts`
- `{shared-ui}/modals/groups/prompt/PromptModalWrapper.vue`
- `{shared-ui}/modals/groups/prompt/PromptModalTarget.vue`
- `{shared-ui}/modals/groups/prompt/index.ts`
- `{shared-ui}/modals/index.ts`
- `{shared-ui}/modals/confirm-modal/ConfirmModal.vue`
- `{shared-ui}/modals/confirm-modal/interface.ts`
- `{shared-ui}/modals/confirm-modal/index.ts`
- `{shared-lib}/confirm-modal/useConfirmModal.ts`
- `{shared-lib}/confirm-modal/index.ts`

**File:** `{plugins}/modal.ts`
```ts
import { createModal as createModalMaster } from '@kolirt/vue-modal'

declare module '@kolirt/vue-modal' {
  interface ModalGroupRegistry extends DefineGroups<['main', 'prompt']> {}
}

export function createModal() {
  const plugin = createModalMaster({
    groups: {
      main: {
        enableInteractOutside: true,
        disableCloseOnInteractOutside: true
      },
      prompt: {
        enableInteractOutside: true
      }
    }
  })

  return plugin
}
```

**File:** `{shared-ui}/modals/ModalOverlay.vue`
```vue
<script lang="ts" setup>
import { ModalOverlay } from '@kolirt/vue-modal'
</script>

<template>
  <ModalOverlay
    class="bg-background/80 data-[state=open]:animate-in fade-in data-[state=closed]:animate-out fade-out data-[state=closed]:fill-mode-forwards"
  >
    <slot />
  </ModalOverlay>
</template>
```

**File:** `{shared-ui}/modals/groups/main/MainModalWrapper.vue`
```vue
<script lang="ts" setup>
import { ModalContent, ModalRoot, useModalContext } from '@kolirt/vue-modal'

import { CloseIcon } from '{shared-ui}/icons'

const { close } = useModalContext()
</script>

<template>
  <ModalRoot class="flex items-center justify-center overflow-hidden p-4">
    <ModalContent
      class="backdrop-blurred-10 border-border-accent data-[state=open]:animate-in data-[state=closed]:animate-out fade-in zoom-in-95 fade-out zoom-out-95 data-[state=closed]:fill-mode-forwards relative w-full max-w-150 rounded-lg border"
    >
      <button type="button" class="text-foreground-accent hover:text-foreground absolute top-4 right-4" @click="close()">
        <CloseIcon :size="20" />
      </button>

      <slot />
    </ModalContent>
  </ModalRoot>
</template>
```

**File:** `{shared-ui}/modals/groups/main/MainModalTarget.vue`
```vue
<script lang="ts" setup>
import { ModalTarget } from '@kolirt/vue-modal'

import ModalOverlay from '../../ModalOverlay.vue'
</script>

<template>
  <ModalTarget group="main" class="z-60 h-auto!">
    <ModalOverlay />
  </ModalTarget>
</template>
```

**File:** `{shared-ui}/modals/groups/main/index.ts`
```ts
export { default as MainModalTarget } from './MainModalTarget.vue'
export { default as MainModalWrapper } from './MainModalWrapper.vue'
```

**File:** `{shared-ui}/modals/groups/prompt/PromptModalWrapper.vue`
```vue
<script lang="ts" setup>
import { ModalContent, ModalRoot, useModalContext } from '@kolirt/vue-modal'

import { CloseIcon } from '{shared-ui}/icons'

const { close } = useModalContext()
</script>

<template>
  <ModalRoot class="flex items-center justify-center overflow-hidden p-4">
    <ModalContent
      class="backdrop-blurred-10 border-border-accent data-[state=open]:animate-in data-[state=closed]:animate-out fade-in zoom-in-95 fade-out zoom-out-95 data-[state=closed]:fill-mode-forwards relative w-full max-w-100 rounded-lg border"
    >
      <button type="button" class="text-foreground-accent hover:text-foreground absolute top-4 right-4" @click="close()">
        <CloseIcon :size="20" />
      </button>

      <slot />
    </ModalContent>
  </ModalRoot>
</template>
```

**File:** `{shared-ui}/modals/groups/prompt/PromptModalTarget.vue`
```vue
<script lang="ts" setup>
import { ModalTarget } from '@kolirt/vue-modal'

import ModalOverlay from '../../ModalOverlay.vue'
</script>

<template>
  <ModalTarget group="prompt" class="z-70 h-auto!">
    <ModalOverlay />
  </ModalTarget>
</template>
```

**File:** `{shared-ui}/modals/groups/prompt/index.ts`
```ts
export { default as PromptModalTarget } from './PromptModalTarget.vue'
export { default as PromptModalWrapper } from './PromptModalWrapper.vue'
```

**File:** `{shared-ui}/modals/index.ts`
```ts
export { default as ModalOverlay } from './ModalOverlay.vue'
export * from './groups/main'
export * from './groups/prompt'
```

**File:** `{shared-ui}/modals/confirm-modal/ConfirmModal.vue`
```vue
<script lang="ts" setup>
import { useModalContext } from '@kolirt/vue-modal'

import { PrimaryButton } from '{shared-ui}/buttons'

import PromptModalWrapper from '../groups/prompt/PromptModalWrapper.vue'
import type { ConfirmModalProps } from './interface'

defineOptions({ modalGroup: 'prompt' })

const props = withDefaults(defineProps<ConfirmModalProps>(), {
  confirmText: 'Confirm',
  cancelText: 'Cancel',
  variant: 'primary'
})

const { confirm, close } = useModalContext<boolean>()
</script>

<template>
  <PromptModalWrapper>
    <div class="flex flex-col gap-4 p-6">
      <h2 class="text-lg font-semibold">{{ props.title }}</h2>

      <p class="text-sm">{{ props.message }}</p>

      <div class="flex justify-end gap-3 pt-2">
        <PrimaryButton @click="close()" variant="dark">{{ props.cancelText }}</PrimaryButton>
        <PrimaryButton @click="confirm(true)" :variant="props.variant === 'danger' ? 'warning' : 'primary'">
          {{ props.confirmText }}
        </PrimaryButton>
      </div>
    </div>
  </PromptModalWrapper>
</template>
```

**File:** `{shared-ui}/modals/confirm-modal/interface.ts`
```ts
type ConfirmVariant = 'primary' | 'danger'

type ConfirmRequest = {
  title: string
  message: string
  confirmText?: string
  cancelText?: string
  variant?: ConfirmVariant
}

type ConfirmModalProps = ConfirmRequest

export type { ConfirmModalProps, ConfirmRequest, ConfirmVariant }
```

**File:** `{shared-ui}/modals/confirm-modal/index.ts`
```ts
export { default as ConfirmModal } from './ConfirmModal.vue'
export type { ConfirmModalProps, ConfirmRequest, ConfirmVariant } from './interface'
```

**File:** `{shared-lib}/confirm-modal/useConfirmModal.ts`
```ts
import { ModalClosedError, openModal } from '@kolirt/vue-modal'

import { ConfirmModal, type ConfirmRequest } from '{shared-ui}/modals/confirm-modal'

function useConfirmModal() {
  function confirm(request: ConfirmRequest): Promise<boolean> {
    return openModal<boolean>(ConfirmModal, { props: request }).catch((error) => {
      if (error instanceof ModalClosedError) return false
      throw error
    })
  }

  return { confirm }
}

export { useConfirmModal }
```

**File:** `{shared-lib}/confirm-modal/index.ts`
```ts
export { useConfirmModal } from './useConfirmModal'
```
