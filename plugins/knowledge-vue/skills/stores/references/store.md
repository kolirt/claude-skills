# Module-reactive stores — full-file etalon (CSR)

Variant: projectType=csr

Three representative shapes: an **entity store** with persistence (session auth — CSR arm reads storage directly at module-init; see `store.ssr.md` for the SSR arm/hydration callback), a **widget view-state** singleton (sidebar open/closed + active view, same `reactive()`/setter/`useX()` skeleton as the entity store), and a **feature state** composable (login action, per-mount, derived entirely via `computed` — nothing module-level).

Mutually exclusive with `store.ssr.md`, chosen by `projectType` (the `vue-work` skill's step 0) — reproduce only one.

## Files

- `{entity}/session/model/store/index.ts`
- `{entity}/session/model/store/keys.ts`
- `{entity}/session/model/store/useSessionStore.ts`
- `{widget}/sidebar/index.ts`
- `{widget}/sidebar/config/index.ts`
- `{widget}/sidebar/config/views.ts`
- `{widget}/sidebar/model/index.ts`
- `{widget}/sidebar/model/useSidebar.ts`
- `{widget}/sidebar/ui/index.ts`
- `{widget}/sidebar/ui/SidebarModal.vue`
- `{widget}/sidebar/ui/SidebarTriggers.vue`
- `{feature}/login-via-discord/index.ts`
- `{feature}/login-via-discord/model/index.ts`
- `{feature}/login-via-discord/model/useLoginViaDiscord.ts`
- `{feature}/login-via-discord/ui/index.ts`
- `{feature}/login-via-discord/ui/LoginViaDiscord.vue`

**File:** `{entity}/session/model/store/index.ts`
```ts
export { clearAuthenticated, markAuthenticated, useSessionStore } from './useSessionStore'
```

**File:** `{entity}/session/model/store/keys.ts`
```ts
const STORAGE_KEYS = {
  authenticated: 'session.authenticated'
} as const

type StorageKey = (typeof STORAGE_KEYS)[keyof typeof STORAGE_KEYS]

export { STORAGE_KEYS, type StorageKey }
```

CSR arm — no SSR, so the persisted value is read directly at module-init time:

**File:** `{entity}/session/model/store/useSessionStore.ts`
```ts
import { computed, reactive } from 'vue'

import { useLocalPersistence } from '{shared-lib}/local-persistence'

import { STORAGE_KEYS } from './keys'

const persistence = useLocalPersistence()

const state = reactive<{ authenticated: boolean }>({
  authenticated: false
})

state.authenticated = Boolean(persistence.get<boolean>(STORAGE_KEYS.authenticated, false))

function markAuthenticated(): void {
  state.authenticated = true
  persistence.set(STORAGE_KEYS.authenticated, true)
}

function clearAuthenticated(): void {
  state.authenticated = false
  persistence.remove(STORAGE_KEYS.authenticated)
}

function useSessionStore() {
  return {
    isAuthenticated: computed(() => state.authenticated)
  }
}

export { clearAuthenticated, markAuthenticated, useSessionStore }
```

**File:** `{widget}/sidebar/index.ts`
```ts
export { Views } from './config'
export { close, open, useSidebar } from './model'
export { SidebarTriggers } from './ui'
```

**File:** `{widget}/sidebar/config/index.ts`
```ts
export { Views } from './views'
```

**File:** `{widget}/sidebar/config/views.ts`
```ts
export enum Views {
  Login = 'login',
  Notifications = 'notifications',
  Settings = 'settings',
  Profile = 'profile',
  Alerts = 'alerts'
}
```

**File:** `{widget}/sidebar/model/index.ts`
```ts
export { close, open, useSidebar } from './useSidebar'
```

**File:** `{widget}/sidebar/model/useSidebar.ts`
```ts
import { closeModalById, openModal } from '@kolirt/vue-modal'
import { computed, reactive } from 'vue'

import { Views } from '../config'
import { SidebarModal } from '../ui'

const state = reactive<{
  modalId: number | null
  view: Views | null
}>({
  modalId: null,
  view: null
})

function open(view: Views) {
  state.view = view

  if (state.modalId === null) {
    const modal = openModal(SidebarModal)
    state.modalId = modal.id
    modal
      .catch(() => {})
      .finally(() => {
        state.modalId = null
      })
  }
}

function close() {
  if (state.modalId !== null) closeModalById(state.modalId)
}

function useSidebar() {
  return {
    isOpen: computed(() => state.modalId !== null),
    view: computed(() => state.view)
  }
}

export { close, open, useSidebar }
```

**File:** `{widget}/sidebar/ui/index.ts`
```ts
export { default as SidebarModal } from './SidebarModal.vue'
export { default as SidebarTriggers } from './SidebarTriggers.vue'
```

**File:** `{widget}/sidebar/ui/SidebarModal.vue`
```vue
<script lang="ts" setup>
import { useModalContext } from '@kolirt/vue-modal'

import { MainModalWrapper } from '{shared-ui}/modals'

import { Views } from '../config'
import { useSidebar } from '../model'

defineOptions({ modalGroup: 'main' })

const { view } = useSidebar()
const { close } = useModalContext<void>()
</script>

<template>
  <MainModalWrapper>
    <div class="flex flex-col gap-4 p-6">
      <h2 class="text-lg font-semibold capitalize">{{ view }}</h2>

      <p v-if="view === Views.Login" class="text-sm">Sign-in panel</p>
      <p v-else-if="view === Views.Notifications" class="text-sm">Notifications panel</p>
      <p v-else-if="view === Views.Settings" class="text-sm">Settings panel</p>
      <p v-else-if="view === Views.Profile" class="text-sm">Profile panel</p>
      <p v-else-if="view === Views.Alerts" class="text-sm">Alerts panel</p>

      <button class="self-end text-sm" @click="close()">Close</button>
    </div>
  </MainModalWrapper>
</template>
```

`SidebarTriggers` is the Header-slotted button row that opens the sidebar modal on a
given view — the piece `layouts` imports from this barrel:

**File:** `{widget}/sidebar/ui/SidebarTriggers.vue`
```vue
<script lang="ts" setup>
import { Views } from '../config'
import { open } from '../model'
</script>

<template>
  <button v-for="view in Views" :key="view" class="text-sm capitalize" @click="open(view)">
    {{ view }}
  </button>
</template>
```

**File:** `{feature}/login-via-discord/index.ts`
```ts
export { LoginViaDiscord } from './ui'
```

**File:** `{feature}/login-via-discord/model/index.ts`
```ts
export * from './useLoginViaDiscord'
```

**File:** `{feature}/login-via-discord/model/useLoginViaDiscord.ts`
```ts
import { computed } from 'vue'
import { useRouter } from 'vue-router'

import { useLoginViaDiscordAction } from '{entity}/session'

import { RouteNames } from '{shared-config}'
import { useOauthWindow } from '{shared-lib}/oauth-window'

function useLoginViaDiscord() {
  const router = useRouter()
  const loginAction = useLoginViaDiscordAction()
  const oauthWindow = useOauthWindow()

  async function submit(): Promise<void> {
    const redirectUri = window.location.origin + router.resolve({ name: RouteNames.AuthCallback }).href
    try {
      const { code } = await oauthWindow.auth({
        provider: 'discord',
        authorizationEndpoint: '<OAUTH_AUTHORIZE_URL>',
        clientId: import.meta.env.VITE_OAUTH_CLIENT_ID ?? '',
        redirectUri,
        scope: ['identify', 'email']
      })
      await loginAction.mutateAsync({ code, redirectUri })
    } catch {}
  }

  return {
    submit,
    isLoading: computed(() => oauthWindow.isPending.value || loginAction.isPending.value)
  }
}

export { useLoginViaDiscord }
```

**File:** `{feature}/login-via-discord/ui/index.ts`
```ts
export { default as LoginViaDiscord } from './LoginViaDiscord.vue'
```

**File:** `{feature}/login-via-discord/ui/LoginViaDiscord.vue`
```vue
<script lang="ts" setup>
import { SocialButton } from '{shared-ui}/buttons'

import { useLoginViaDiscord } from '../model'

const { submit, isLoading } = useLoginViaDiscord()
</script>

<template>
  <SocialButton @click="submit" :loading="isLoading" variant="discord">Sign in with Discord</SocialButton>
</template>
```
