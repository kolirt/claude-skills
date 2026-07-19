---
name: tanstack-query
description: Use when fetching or mutating backend data in a Vue project, or when invalidating/clearing cached data — queries, mutations, query keys, and cache invalidation with TanStack Query (@tanstack/vue-query). The agent should also use this to detect that TanStack Query is in use and clear data correctly by key.
---

# tanstack-query (Vue) — `@tanstack/vue-query`

Data fetching and mutations go through TanStack Query. Requests reach the backend via
the `http-request` skill (by name) — but never directly from the call site.

Read `../../core/placement.md` first for the `{entity}` / `{shared-lib}` tokens; paths resolve in the active architecture doc.

Read `references/query-module.md` and reproduce it — it holds the complete files for the
query wrapper, the QueryClient plugin, and a representative entity slice.

## Layering (the key rule)
- [invariant · desired] Components and features **never** call `useHttpRequest`
  directly. They call a `use*Query` / `use*Action`. The query's `queryFn` / mutation's
  `mutationFn` calls a plain entity **api function**, and *that* function calls
  `useHttpRequest()` (see the `http-request` skill).
  - layering: `component/feature` → `use*Query`/`use*Action` → `entity api fn` → `useHttpRequest`.

## Setup
- [invariant · desired] Install `@tanstack/vue-query` + `@lukemorales/query-key-factory`
  (+ `@tanstack/query-broadcast-client-experimental` for cross-tab sync). Register
  through the `plugin-registration` skill: a `createVueQuery({ ssr })` factory that
  creates the `QueryClient`, wires the broadcast (client only), and returns
  `{ queryClient, install(app) }` — see `{plugins}/vueQuery.ts` in the etalon.
- [invariant · desired] Augment `queryMeta` (colocated in the plugin file):
  `declare module '@tanstack/vue-query' { interface Register { queryMeta: { requiresAuth?: boolean } } }`.
- [invariant · desired] **Cross-tab broadcast** (`@tanstack/query-broadcast-client-experimental`):
  `broadcastQueryClient({ queryClient, broadcastChannel: '<app>' })` — called **only on the
  client** (`!ssr`) inside the factory; server renders never touch it. The channel name is
  the app's own (project-specific).
- [invariant · desired] The unauthorized (401) handler needs the live `queryClient` — wire
  it at boot **after** the app factory returns it (see the `auth` / `http-request` skills).

## Shared query wrapper (`{shared-lib}/query`, SSR-safe)
- [invariant · desired] Queries import `useQuery` / `useInfiniteQuery` from
  `{shared-lib}/query`, **never** from `@tanstack/vue-query` directly — the wrapper makes
  them **SSR-safe**: it forces `enabled: false` during SSR (`import.meta.env.SSR`) via a
  reusable `withSsrBlock` HOF, so client-default queries never fetch on the server.
  `useSsrQuery` / `useSsrInfiniteQuery` are the **opt-in** server-running variants (pair
  with `await query.suspense()` + `<Suspense>`).
- [invariant · desired] **Create this wrapper module** at `{shared-lib}/query`: export
  `useQuery` / `useInfiniteQuery` wrapped in a `withSsrBlock(...)` HOF, and export
  `useSsrQuery` / `useSsrInfiniteQuery` as **owned typed const bindings** (not bare
  re-exports from the package). It is a small hand-written module, not a package.
- [invariant · desired] `withSsrBlock` must guard reactive options with an `isRef` check
  and pass through extra arguments (see `{shared-lib}/query/withSsrBlock.ts` in the etalon).
- [invariant · desired] SSR-enabled variants are **owned typed const bindings**, not bare
  re-exports from the package — `export const useSsrQuery: typeof useQueryMaster = useQueryMaster`
  (NOT `export { useQuery as useSsrQuery } from '@tanstack/vue-query'`).
- [invariant · desired] Follow the `{shared-lib}` barrel discipline — **one unit per file**,
  `index.ts` re-exports only:
  ```
  {shared-lib}/query/
    withSsrBlock.ts          # the HOF (isRef-guarded, passes ...rest)
    useQuery.ts              # export const useQuery = withSsrBlock(useQueryMaster)
    useInfiniteQuery.ts
    useSsrQuery.ts           # owned typed const binding (typeof useQueryMaster)
    useSsrInfiniteQuery.ts   # owned typed const binding (typeof useInfiniteQueryMaster)
    index.ts                 # export { useQuery } from './useQuery'  (named re-exports only)
  ```
- [preference · desired] (SSR projects) Hydrate the cache: server `dehydrate(queryClient)`
  → `window.__INITIAL_STATE__`; client `hydrate(queryClient, __INITIAL_STATE__)` before mount.

## Queries
- [invariant · desired] A query is named **`use*Query`** and lives in
  the `{entity}` module as an **entity query** — the active architecture doc resolves where
  inside the module it goes. Import `useQuery` (and SSR variants `useSsrQuery` /
  `useSsrInfiniteQuery`) from the **shared query wrapper** `{shared-lib}/query` —
  **never** directly from `@tanstack/vue-query`. `queryFn` calls the entity's own api
  function (which calls `useHttpRequest()` internally), the query always has a `select`,
  and auth-gated queries add `enabled` + `meta: { requiresAuth: true }` — see
  `useFindPostQuery` in the etalon for the full shape.
- [preference · desired] Parameterized queries keep reactivity by wrapping the key in a
  `computed(() => keys.method(toValue(params)).queryKey)`.
- [invariant · desired] Every API response uses the envelope **`{ ok: true, result: T }`**.
  A query **always** has a `select`. The default unwraps one level (`select: (r) => r.result`);
  when the consumer needs only a nested field, select deeper (`r.result.article`,
  `r.result.categories`) — situational, by what's actually needed.
- [preference · desired] **Dependent queries** gate on the dependency's data via `enabled`
  (the same mechanism as auth gating): `enabled: computed(() => !!dep.value)` — the query
  stays paused until the precondition holds. Use `enabled` only when there is a real
  precondition (auth, a non-empty id list, a min search length).
- [preference · desired] Regular (non-infinite) paginated queries may add
  `placeholderData: keepPreviousData` (import `keepPreviousData` from `@tanstack/vue-query`)
  to avoid flicker between pages — see `usePaginatePostsQuery` in the etalon.

## Infinite queries (pagination)
- [invariant · desired] Pagination is **page-number** based via `useInfiniteQuery` (from the
  shared wrapper). `queryFn` receives `pageParam`; `initialPageParam: 1`; `getNextPageParam`
  reads the raw response (`result.page < result.lastPage → result.page + 1`, else `undefined`).
- [invariant · desired] `select` **always flattens** `data.pages` into a plain
  `{ items, total }` — consumers **never** touch `data.pages` or the raw `InfiniteData`.
- [preference · desired] Infinite-scroll UI mechanics (`fetchNextPage` / `hasNextPage` /
  `isFetchingNextPage`, skeleton, error) live in a **shared `InfiniteQueryView` component**
  (`{shared-ui}/...`), not in each consumer.
- The paginate api returns `{ ok: true, result: { items[], total, page, perPage, lastPage } }`.

## Cache timing — choosing `staleTime` / `gcTime`
Pick these by how volatile the data is, so the agent sets them itself instead of guessing.
- [invariant · desired] Global defaults live in the `QueryClient`: `staleTime: 30_000`
  (30s), `gcTime: 5 * 60_000` (5min). Most queries inherit them; override only when the
  data's volatility differs.
- [invariant · desired] `gcTime ≥ staleTime` always (cache must outlive its staleness).
- [preference · desired] Override per query by data kind:
  | data kind | `staleTime` | `gcTime` |
  |---|---|---|
  | personal / live (me, notifications, anything that changes often) | 0–30s (inherit) | 5min |
  | semi-stable lists / paginated / search results | ~5min | ~10min |
  | static reference (categories, enums, config — rarely changes) | 30–60min (or `Infinity`) | ≥ `staleTime` |
- Rule of thumb: `staleTime` = "how long may this be shown before a refetch is needed?";
  `gcTime` = "how long to keep it after nothing observes it (will it likely be revisited?)".

## Mutations
- [invariant · desired] A mutation is named **`use*Action`** and lives in
  the `{entity}` module as an **entity action** — the active architecture doc resolves where
  inside the module it goes. Import `useMutation` + `useQueryClient` directly from
  `@tanstack/vue-query` (mutations have no shared wrapper). `onSuccess` invalidates the
  affected keys.
- [invariant · desired] Invalidate with the shape that matches what the write affected:
  invalidate the **key subtree** via `keys.method._def` when the write affects a
  list/paginated dataset with many possible key variants (e.g. creating a post touches
  every `paginatePosts` filter combination); invalidate the **single known key** via
  `keys.method.queryKey` when exactly one record is affected (e.g. `sessionKeys.me.queryKey`
  after login). See `useCreatePostAction` (subtree) and `useLoginViaDiscordAction` (single
  key) in the etalon.
- [preference · desired] Feature composables (`{feature}`) wrap an entity action and
  expose a clean `submit()` / `isPending`; they add no extra cache logic.
- [preference · desired] **Optimistic updates** — for mutations where the UI must react
  instantly (the default elsewhere is `onSuccess` → invalidate/refetch). Pattern:
  `onMutate` cancels in-flight queries for the key, snapshots current data, and
  `setQueryData` to the expected value; `onError` rolls back to the snapshot; `onSettled`
  invalidates to reconcile with the server.
  ```ts
  useMutation({
    mutationFn,
    onMutate: async (next) => {
      await queryClient.cancelQueries({ queryKey: key })
      const prev = queryClient.getQueryData(key)
      queryClient.setQueryData(key, (old) => applyOptimistic(old, next))
      return { prev }                                   // context for rollback
    },
    onError: (_e, _next, ctx) => queryClient.setQueryData(key, ctx?.prev),
    onSettled: () => queryClient.invalidateQueries({ queryKey: key }),
  })
  ```

## Query keys — `@lukemorales/query-key-factory`
- [invariant · desired] Keys come from a `createQueryKeys` factory, one per entity in
  the `{entity}` module as the **entity query keys** — the single source of truth for that entity's cache
  namespace. **No string-literal keys at call sites.** Static entries take `null`
  (`sessionKeys.me`), parameterized entries take a function (`postKeys.paginatePosts`).
  See `keys.ts` in this skill's etalon for the `blog/post` entity; the `session` entity's
  `keys.ts` is owned by the `auth` skill's own etalon.
- [invariant · desired] The **same** key expression is used in the query and in any
  invalidation/removal — never re-typed.

## Invalidation / clearing by key (how to clean data correctly)
- [invariant · desired] Get the client via `useQueryClient()` inside the composable
  (never an imported singleton). Two strategies:
  - **`invalidateQueries({ queryKey })`** → marks matching queries stale and refetches
    (use after a mutation that changed that data).
  - **`removeQueries({ queryKey | predicate })`** → hard-evicts matching queries from
    cache (use when data must disappear, e.g. on logout — see the `auth` skill).
  - Prefer **surgical** keys over a blanket `queryClient.clear()`.

## `meta.requiresAuth`
- [invariant · desired] `requiresAuth` is a **TanStack query `meta`** flag (augment
  `Register['queryMeta']`), NOT Vue Router meta. It does **not** gate the query —
  gating is the `enabled` option. It **tags** auth-dependent cache so it can be evicted
  on logout/401 (consumed by the `auth` skill's `isAuthQuery` predicate).
