# Etalon: auth wiring (login/logout, 401 auto-logout)

Reproduces the `session` entity's auth-specific slice (query gating/eviction
predicate, login/logout actions, api calls). The session store
(`{entity}/session/model/store/*`) is owned by the `stores` skill's `store.md`
(CSR) / `store.ssr.md` (SSR) etalon — pick by `projectType`. `{initial-plugins}/httpRequest.ts`
and the 401 unauthorized-handler registration are owned by the `http-request`
skill's `http-request-module.md` etalon. Neither is reproduced here; both are
imported by token only (`{shared-lib}/http-request`, `{shared-lib}/query`,
`{shared-lib}/hydration`, `{shared-lib}/local-persistence` likewise belong to
other skills).

## Files

- `{entity}/session/api/types.ts`
- `{entity}/session/api/loginViaDiscord.ts`
- `{entity}/session/api/logout.ts`
- `{entity}/session/api/me.ts`
- `{entity}/session/api/index.ts`
- `{entity}/session/model/query/keys.ts`
- `{entity}/session/model/query/isAuthQuery.ts`
- `{entity}/session/model/query/useMeQuery.ts`
- `{entity}/session/model/query/index.ts`
- `{entity}/session/model/action/useLoginViaDiscordAction.ts`
- `{entity}/session/model/action/useLogoutAction.ts`
- `{entity}/session/model/action/index.ts`
- `{entity}/session/model/index.ts`
- `{entity}/session/index.ts`

**File:** `{entity}/session/api/types.ts`
```ts
type User = {
  id: string
  username: string
  email: string
  avatar: string | null
}

export type { User }
```

**File:** `{entity}/session/api/loginViaDiscord.ts`
```ts
import { useHttpRequest } from '{shared-lib}/http-request'

import type { User } from './types'

type LoginViaDiscordPayload = {
  code: string
  redirectUri: string
}

type LoginViaDiscordResponse = {
  ok: true
  result: User
}

async function loginViaDiscord(payload: LoginViaDiscordPayload) {
  const { post } = useHttpRequest()
  return post<LoginViaDiscordResponse>('/api/auth/login/discord', payload)
}

export { loginViaDiscord, type LoginViaDiscordPayload, type LoginViaDiscordResponse }
```

**File:** `{entity}/session/api/logout.ts`
```ts
import { useHttpRequest } from '{shared-lib}/http-request'

type LogoutResponse = {
  ok: true
}

async function logout() {
  const { post } = useHttpRequest()
  return post<LogoutResponse>('/api/auth/logout', {}, { asJson: true })
}

export { logout, type LogoutResponse }
```

**File:** `{entity}/session/api/me.ts`
```ts
import { useHttpRequest } from '{shared-lib}/http-request'

import type { User } from './types'

type MeResponse = {
  ok: true
  result: User
}

async function me() {
  const { get } = useHttpRequest()
  return get<MeResponse>('/api/auth/me')
}

export { me, type MeResponse }
```

**File:** `{entity}/session/api/index.ts`
```ts
export { loginViaDiscord, type LoginViaDiscordPayload, type LoginViaDiscordResponse } from './loginViaDiscord'
export { logout, type LogoutResponse } from './logout'
export { me, type MeResponse } from './me'
export type { User } from './types'
```

`{entity}/session/model/store/{keys,useSessionStore,index}.ts` are owned by the
`stores` skill's `store.md` etalon (CSR/SSR variants differ) — imported here by
token only (`markAuthenticated`/`clearAuthenticated`/`useSessionStore`).

**File:** `{entity}/session/model/query/keys.ts`
```ts
import { createQueryKeys } from '@lukemorales/query-key-factory'

const sessionKeys = createQueryKeys('session', {
  me: null
})

export { sessionKeys }
```

**File:** `{entity}/session/model/query/isAuthQuery.ts`
```ts
import type { Query } from '@tanstack/vue-query'

function isAuthQuery(query: Query): boolean {
  return query.meta?.requiresAuth === true
}

export { isAuthQuery }
```

**File:** `{entity}/session/model/query/useMeQuery.ts`
```ts
import { computed } from 'vue'

import { useQuery } from '{shared-lib}/query'

import { me as meApi } from '../../api'
import { useSessionStore } from '{entity}/session/model/store'
import { sessionKeys } from './keys'

function useMeQuery() {
  const session = useSessionStore()

  return useQuery({
    queryKey: sessionKeys.me.queryKey,
    queryFn: meApi,
    select: (response) => response.result,
    enabled: computed(() => session.isAuthenticated.value),
    retry: false,
    meta: { requiresAuth: true },
    staleTime: 30 * 1000,
    gcTime: 5 * 60 * 1000
  })
}

export { useMeQuery }
```

**File:** `{entity}/session/model/query/index.ts`
```ts
export { isAuthQuery } from './isAuthQuery'
export { sessionKeys } from './keys'
export { useMeQuery } from './useMeQuery'
```

**File:** `{entity}/session/model/action/useLoginViaDiscordAction.ts`
```ts
import { useMutation, useQueryClient } from '@tanstack/vue-query'

import { type LoginViaDiscordPayload, loginViaDiscord as loginViaDiscordApi } from '../../api'
import { sessionKeys } from '../query/keys'
import { markAuthenticated } from '{entity}/session/model/store'

function useLoginViaDiscordAction() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: LoginViaDiscordPayload) => loginViaDiscordApi(payload),
    onSuccess: async () => {
      markAuthenticated()
      await queryClient.invalidateQueries({ queryKey: sessionKeys.me.queryKey })
    }
  })
}

export { useLoginViaDiscordAction }
```

**File:** `{entity}/session/model/action/useLogoutAction.ts`
```ts
import { useMutation, useQueryClient } from '@tanstack/vue-query'

import { logout as logoutApi } from '../../api'
import { isAuthQuery } from '../query/isAuthQuery'
import { clearAuthenticated } from '{entity}/session/model/store'

function useLogoutAction() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: () => logoutApi(),
    onSettled: () => {
      clearAuthenticated()
      queryClient.removeQueries({ predicate: isAuthQuery })
    }
  })
}

export { useLogoutAction }
```

**File:** `{entity}/session/model/action/index.ts`
```ts
export { useLoginViaDiscordAction } from './useLoginViaDiscordAction'
export { useLogoutAction } from './useLogoutAction'
```

**File:** `{entity}/session/model/index.ts`
```ts
export * from './action'
export * from './query'
export { clearAuthenticated, markAuthenticated, useSessionStore } from '{entity}/session/model/store'
```

**File:** `{entity}/session/index.ts`
```ts
export type { LoginViaDiscordPayload } from './api'
export { clearAuthenticated, isAuthQuery, markAuthenticated, sessionKeys, useLoginViaDiscordAction, useLogoutAction, useMeQuery, useSessionStore } from './model'
```

`{initial-plugins}/httpRequest.ts` is owned by the `http-request` skill's
`http-request-module.md` etalon — not reproduced here. This skill's only
contribution is the `setUnauthorizedHandler` callback registered inside it:
`clearAuthenticated()` then `queryClient.removeQueries({ predicate: isAuthQuery })`.
