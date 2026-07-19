# Etalon: TanStack Query module (SSR-safe wrapper, plugin registration, entity slice)

Reproduces the shared query wrapper (`{shared-lib}/query`), the `QueryClient` plugin
registration (`{plugins}`), and one entity slice (`{entity}`) covering a query pair
(single item + paginated list) and a mutation with invalidation. Domain renamed to a
neutral `blog/post` entity.

The `session` entity's query/action slice is owned by the `auth` skill's `auth.md`
etalon — not reproduced here.

## Files
- `{shared-lib}/query/withSsrBlock.ts`
- `{shared-lib}/query/useQuery.ts`
- `{shared-lib}/query/useSsrQuery.ts`
- `{shared-lib}/query/useInfiniteQuery.ts`
- `{shared-lib}/query/useSsrInfiniteQuery.ts`
- `{shared-lib}/query/index.ts`
- `{plugins}/vueQuery.ts`
- `{entity}/blog/post/api/types.ts`
- `{entity}/blog/post/api/findPost.ts`
- `{entity}/blog/post/api/paginatePosts.ts`
- `{entity}/blog/post/api/createPost.ts`
- `{entity}/blog/post/api/index.ts`
- `{entity}/blog/post/model/query/keys.ts`
- `{entity}/blog/post/model/query/useFindPostQuery.ts`
- `{entity}/blog/post/model/query/usePaginatePostsQuery.ts`
- `{entity}/blog/post/model/query/index.ts`
- `{entity}/blog/post/model/action/useCreatePostAction.ts`
- `{entity}/blog/post/model/action/index.ts`
- `{entity}/blog/post/model/index.ts`
- `{entity}/blog/post/index.ts`

**File:** `{shared-lib}/query/withSsrBlock.ts`
```ts
import { isRef } from 'vue'

export function withSsrBlock<T extends (...args: any[]) => any>(master: T): T {
  return ((options: any, ...rest: any[]) => {
    if (import.meta.env.SSR && options && typeof options === 'object' && !isRef(options)) {
      return master({ ...options, enabled: false }, ...rest)
    }
    return master(options, ...rest)
  }) as T
}
```

**File:** `{shared-lib}/query/useQuery.ts`
```ts
import { useQuery as useQueryMaster } from '@tanstack/vue-query'

import { withSsrBlock } from './withSsrBlock'

// Default: blocks the query on SSR. Use for data not needed in server-rendered HTML.
export const useQuery = withSsrBlock(useQueryMaster)
```

**File:** `{shared-lib}/query/useSsrQuery.ts`
```ts
import { useQuery as useQueryMaster } from '@tanstack/vue-query'

// SSR-enabled: fires on the server too. Pair with `await query.suspense()` in
// async setup wrapped by `<Suspense>` so the server awaits before serializing the cache.
export const useSsrQuery: typeof useQueryMaster = useQueryMaster
```

**File:** `{shared-lib}/query/useInfiniteQuery.ts`
```ts
import { useInfiniteQuery as useInfiniteQueryMaster } from '@tanstack/vue-query'

import { withSsrBlock } from './withSsrBlock'

export const useInfiniteQuery = withSsrBlock(useInfiniteQueryMaster)
```

**File:** `{shared-lib}/query/useSsrInfiniteQuery.ts`
```ts
import { useInfiniteQuery as useInfiniteQueryMaster } from '@tanstack/vue-query'

export const useSsrInfiniteQuery: typeof useInfiniteQueryMaster = useInfiniteQueryMaster
```

**File:** `{shared-lib}/query/index.ts`
```ts
export { dehydrate } from '@tanstack/vue-query'
export { useInfiniteQuery } from './useInfiniteQuery'
export { useQuery } from './useQuery'
export { useSsrInfiniteQuery } from './useSsrInfiniteQuery'
export { useSsrQuery } from './useSsrQuery'
```

**File:** `{plugins}/vueQuery.ts`
```ts
import { broadcastQueryClient } from '@tanstack/query-broadcast-client-experimental'
import { type DehydratedState, QueryClient, VueQueryPlugin, hydrate } from '@tanstack/vue-query'
import type { App } from 'vue'

import { HttpAbortError } from '{shared-lib}/http-request'

declare module '@tanstack/vue-query' {
  interface Register {
    queryMeta: { requiresAuth?: boolean }
  }
}

declare global {
  interface Window {
    __INITIAL_STATE__?: DehydratedState
  }
}

// Shared by both project types: CSR calls this bare, SSR passes `{ ssr: true }`.
export function createVueQuery({ ssr = false }: { ssr?: boolean } = {}) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        gcTime: 5 * 60 * 1000,
        staleTime: 30 * 1000,
        throwOnError: (error) => error instanceof HttpAbortError,
        retry: (failureCount, error) => {
          if (error instanceof HttpAbortError) return false
          return failureCount < 3
        }
      }
    }
  })

  if (!ssr) {
    broadcastQueryClient({ queryClient, broadcastChannel: '<app>' })

    // Hydration owned here (not entryClient.ts) so the bootstrap root stays cache-agnostic.
    if (window.__INITIAL_STATE__) {
      hydrate(queryClient, window.__INITIAL_STATE__)
    }
  }

  return {
    queryClient,
    install(app: App) {
      app.use(VueQueryPlugin, { queryClient })
    }
  }
}
```

**File:** `{entity}/blog/post/api/types.ts`
```ts
type PostCategory = {
  slug: string
  name: string
}

type PostAuthor = {
  name: string
  avatar: string
}

type PostListItem = {
  slug: string
  title: string
  previewImage: string
  category: PostCategory
  author: PostAuthor
  publishedAt: string
}

type Post = PostListItem & {
  content: string
  contentImage: string
}

export type { Post, PostAuthor, PostCategory, PostListItem }
```

**File:** `{entity}/blog/post/api/findPost.ts`
```ts
import { useHttpRequest } from '{shared-lib}/http-request'

import type { Post, PostCategory } from './types'

type FindPostPayload = {
  categorySlug: PostCategory['slug']
  postSlug: Post['slug']
}

type FindPostResponse = {
  ok: true
  result: {
    post: Post
  }
}

async function findPost(payload: FindPostPayload) {
  const { get } = useHttpRequest()
  return get<FindPostResponse>(`/api/blog/${payload.categorySlug}/${payload.postSlug}`)
}

export { findPost, type FindPostPayload, type FindPostResponse }
```

**File:** `{entity}/blog/post/api/paginatePosts.ts`
```ts
import { useHttpRequest } from '{shared-lib}/http-request'

import type { PostListItem } from './types'

type PaginatePostsPayload = {
  page?: number
  perPage?: number
  categorySlug?: string
}

type PaginatePostsResponse = {
  ok: true
  result: {
    posts: PostListItem[]
    total: number
    page: number
    perPage: number
    lastPage: number
  }
}

async function paginatePosts(payload: PaginatePostsPayload) {
  const { get } = useHttpRequest()
  return get<PaginatePostsResponse>('/api/blog/posts', payload)
}

export { paginatePosts, type PaginatePostsPayload, type PaginatePostsResponse }
```

**File:** `{entity}/blog/post/api/createPost.ts`
```ts
import { useHttpRequest } from '{shared-lib}/http-request'

import type { Post } from './types'

type CreatePostPayload = {
  categorySlug: string
  title: string
  body: string
}

type CreatePostResponse = {
  ok: true
  result: Post
}

async function createPost(payload: CreatePostPayload) {
  const { post } = useHttpRequest()
  return post<CreatePostResponse>('/api/blog/posts', payload)
}

export { createPost, type CreatePostPayload, type CreatePostResponse }
```

**File:** `{entity}/blog/post/api/index.ts`
```ts
export { createPost, type CreatePostPayload, type CreatePostResponse } from './createPost'
export { findPost, type FindPostPayload, type FindPostResponse } from './findPost'
export { paginatePosts, type PaginatePostsPayload, type PaginatePostsResponse } from './paginatePosts'
export type { Post, PostAuthor, PostCategory, PostListItem } from './types'
```

**File:** `{entity}/blog/post/model/query/keys.ts`
```ts
import { createQueryKeys } from '@lukemorales/query-key-factory'

import type { FindPostPayload, PaginatePostsPayload } from '../../api'

const postKeys = createQueryKeys('posts', {
  findPost: (params: FindPostPayload) => [params],
  paginatePosts: (params: PaginatePostsPayload) => [params]
})

export { postKeys }
```

**File:** `{entity}/blog/post/model/query/useFindPostQuery.ts`
```ts
import { type MaybeRefOrGetter, computed, toValue } from 'vue'

import { useSsrQuery } from '{shared-lib}/query'

import { type FindPostPayload, findPost as findPostApi } from '../../api'
import { postKeys } from './keys'

function useFindPostQuery(payload: MaybeRefOrGetter<FindPostPayload>) {
  return useSsrQuery({
    queryKey: computed(() => {
      return postKeys.findPost(toValue(payload)).queryKey
    }),
    queryFn: () => findPostApi(toValue(payload)),
    select: (response) => response.result.post,
    staleTime: 5 * 60 * 1000,
    gcTime: 10 * 60 * 1000
  })
}

export { useFindPostQuery }
```

**File:** `{entity}/blog/post/model/query/usePaginatePostsQuery.ts`
```ts
import { keepPreviousData } from '@tanstack/vue-query'
import { type MaybeRefOrGetter, computed, toValue } from 'vue'

import { useSsrQuery } from '{shared-lib}/query'

import { type PaginatePostsPayload, paginatePosts as paginatePostsApi } from '../../api'
import { postKeys } from './keys'

type Payload = Omit<PaginatePostsPayload, 'page' | 'perPage'>

function usePaginatePostsQuery(
  params: MaybeRefOrGetter<Payload> = () => ({}),
  options: {
    page: MaybeRefOrGetter<NonNullable<PaginatePostsPayload['page']>>
    perPage: MaybeRefOrGetter<PaginatePostsPayload['perPage']>
  } = {
    page: 1,
    perPage: 20
  }
) {
  return useSsrQuery({
    queryKey: computed(() => {
      return postKeys.paginatePosts({
        ...toValue(params),
        page: toValue(options.page),
        perPage: toValue(options.perPage)
      }).queryKey
    }),
    queryFn: () =>
      paginatePostsApi({
        ...toValue(params),
        page: toValue(options.page),
        perPage: toValue(options.perPage)
      }),
    select: (response) => response.result,
    placeholderData: keepPreviousData,
    staleTime: 60 * 1000,
    gcTime: 5 * 60 * 1000
  })
}

export { usePaginatePostsQuery }
```

**File:** `{entity}/blog/post/model/query/index.ts`
```ts
export { useFindPostQuery } from './useFindPostQuery'
export { usePaginatePostsQuery } from './usePaginatePostsQuery'
```

Two invalidation shapes, both real: `useCreatePostAction` invalidates a key **subtree**
via `._def` (list/paginated dataset); the `auth` skill's `useLoginViaDiscordAction`
(`auth.md`) invalidates a **single** key via `.queryKey` (`session.me`).

**File:** `{entity}/blog/post/model/action/useCreatePostAction.ts`
```ts
import { useMutation, useQueryClient } from '@tanstack/vue-query'

import { type CreatePostPayload, createPost as createPostApi } from '../../api'
import { postKeys } from '../query/keys'

function useCreatePostAction() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (payload: CreatePostPayload) => createPostApi(payload),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: postKeys.paginatePosts._def })
    }
  })
}

export { useCreatePostAction }
```

**File:** `{entity}/blog/post/model/action/index.ts`
```ts
export { useCreatePostAction } from './useCreatePostAction'
```

**File:** `{entity}/blog/post/model/index.ts`
```ts
export * from './query'
export * from './action'
```

**File:** `{entity}/blog/post/index.ts`
```ts
export * from './api'
export * from './model'
```

