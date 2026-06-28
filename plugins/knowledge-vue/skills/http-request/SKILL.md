---
name: http-request
description: Use when making an HTTP request to the backend or writing data-fetching code (an entity's api file, a service call). All requests go through the shared http-request wrapper; raw fetch/axios at the call site is forbidden.
---

# http-request (Vue)

The single shared wrapper through which **every** backend request goes. Built on
native `fetch`. CSRF lives **inside** this module (no separate csrf module — that
split caused a circular import).

Read `../../core/placement.md` first (resolve `{shared-lib}`).

## Core rule
- [invariant · desired] Every HTTP request goes through the shared wrapper
  `useHttpRequest()` — **never** raw `fetch` / `axios` / `ofetch` at a call site.
  - ✅ do: `const { get } = useHttpRequest(); return get<MeResponse>('/api/web/auth/me')`
  - ❌ don't: `fetch('/api/web/auth/me')` / `axios.get(...)` in a component or api file
  - why: one place owns base URL, headers, credentials, CSRF, error normalization,
    auth/notification handling — call sites stay thin and consistent.

## Setup (create the module)
- [invariant · desired] The wrapper is a hand-written module at `{shared-lib}/http-request/`
  — no package to install (it wraps native `fetch`): `request.ts` (the core `request()` +
  the private CSRF helpers), `useHttpRequest.ts` (the verb-helper factory), and an
  `index.ts` barrel exporting `useHttpRequest`, `setUnauthorizedHandler`,
  `setNotificationHandler` (+ `ensureCsrf` / `invalidateCsrf` for other consumers).
- [invariant · desired] Register the handlers **once at app boot** (where the QueryClient
  is available): `setUnauthorizedHandler(...)` (auto-logout — see `auth`) and
  `setNotificationHandler(...)`.

## The wrapper
- [invariant · desired] `useHttpRequest()` is a plain function (the `use` prefix is a
  naming convention, not a Vue composable) returning verb helpers:
  ```ts
  const { request, get, post, put, patch, delete: del, head, options } = useHttpRequest()
  // get<T>(url, data?, options?) → Promise<T>, etc.; `request` is the raw escape hatch
  ```
- [invariant · desired] Built on native `fetch`: base URL from `import.meta.env.VITE_API_URL`
  (e.g. `const BASE_URL = import.meta.env.VITE_API_URL ?? ''`) — **never** a hardcoded
  constant in `{shared-config}`. Always `Accept: application/json` and
  `credentials: 'include'`.
- [preference · desired] Body defaults to `FormData`; `options.asJson` switches to
  JSON. `put`/`patch`/`delete` are tunneled via a `_method` field over `POST` (server
  method-override convention). *(Backend-coupled: tuned to a Laravel-style API.)*

## CSRF — inside http-request (merged; no separate module)
- [invariant · desired] CSRF state and logic live **inside** `http-request` as private
  helpers (`ensureCsrf` / `invalidateCsrf` / `csrfHeader`). There is **no** separate
  `csrf` module and **no** cross-module import — that is what removes the circular
  import. If another module (e.g. a WebSocket client) needs CSRF, `http-request`
  **exports** `ensureCsrf` / `invalidateCsrf`; consumers never re-implement it.
  ```ts
  // inside request.ts
  let _csrfToken: string | null = null
  let _csrfInflight: Promise<void> | null = null
  async function _fetchCsrfToken() { /* GET <API_BASE>/api/csrf → body.result.csrfToken */ }
  function _ensureCsrf(): Promise<void> { /* no-op if cached; dedupes in-flight */ }
  function _invalidateCsrf() { _csrfToken = null; _csrfInflight = null }
  function _csrfHeader() { return _csrfToken ? { 'X-CSRF-TOKEN': _csrfToken } : null }
  ```
- [invariant · desired] Mutating requests (`post/put/patch/delete`) `await _ensureCsrf()`
  and attach the `X-CSRF-TOKEN` header. On a **419** (CSRF expired) for a mutating
  request: `_invalidateCsrf()` → `_ensureCsrf()` → **retry once**.

## Errors & handlers
- [preference · desired] Throw a typed `HttpRequestError` (exposes `status`, `body`,
  `url`, `method`) for non-ok responses; `404` → `HttpAbortError` (lets an
  ErrorBoundary abort silently); `401` → the registered unauthorized handler.
- [preference · desired] Validation errors (`body.errors`) are forwarded to an optional
  `form` sink / `onValidationError`. Notification + unauthorized handlers are module
  singletons set once at app boot (`setNotificationHandler` / `setUnauthorizedHandler`).

## Placement (tokens — resolve via `placement.md`)
- [invariant · desired] The wrapper lives in `{shared-lib}/http-request/`. CSRF is a
  private part of it — **no** `{shared-lib}/csrf/` folder.
