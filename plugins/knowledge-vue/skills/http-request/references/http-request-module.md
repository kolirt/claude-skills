Full-file etalon for the `http-request` skill: the shared HTTP wrapper module (built on
native `fetch`, with CSRF merged inside as private helpers) and its one-time app-boot
registration.

`{shared-lib}` and `{initial-plugins}` resolve unchanged in non-FSD (`src/lib`,
`src/initial-plugins`, no segment nesting) — unlike `{shared-ui}`/`{widget}`/`{feature}`/
`{composition}`, which nest under `components/` there (see `core/architectures/non-fsd.md` §1).

## Files

- `{shared-lib}/http-request/index.ts`
- `{shared-lib}/http-request/request.ts`
- `{shared-lib}/http-request/types.ts`
- `{shared-lib}/http-request/abort.ts`
- `{shared-lib}/http-request/HttpAbortError.ts`
- `{shared-lib}/http-request/useHttpRequest.ts`
- `{shared-lib}/http-request/utils/index.ts`
- `{shared-lib}/http-request/utils/prepareParams.ts`
- `{shared-lib}/http-request/utils/toFormData.ts`
- `{shared-lib}/http-request/utils/unrefs.ts`
- `{initial-plugins}/httpRequest.ts`

**File:** `{shared-lib}/http-request/index.ts`
```ts
export { abort } from './abort'
export { HttpAbortError, type AbortStatus } from './HttpAbortError'
export { HttpRequestError, type Method, type NotificationType, type Options } from './types'
export { useHttpRequest, setNotificationHandler, setUnauthorizedHandler, type NotificationHandler, type UnauthorizedHandler } from './useHttpRequest'
export { ensureCsrf, invalidateCsrf } from './request'
```

**File:** `{shared-lib}/http-request/request.ts`
```ts
import { HttpAbortError } from './HttpAbortError'
import { HttpRequestError, type Method, type Options } from './types'
import { getUnauthorizedHandler } from './useHttpRequest'
import { prepareParams, toFormData, unrefs } from './utils'

const BASE_URL = import.meta.env.VITE_API_URL ?? ''
const DEFAULT_TIMEOUT_MS = 5_000
const TUNNELED_METHODS: Method[] = ['delete', 'put', 'patch']

// CSRF lives here as private helpers, not a separate module — other consumers use the
// `ensureCsrf`/`invalidateCsrf` barrel re-exports, never re-implement this logic.
const CSRF_HEADER = 'X-CSRF-TOKEN'
const CSRF_ENDPOINT = '/api/csrf'

let _csrfToken: string | null = null
let _csrfInflight: Promise<void> | null = null

async function _fetchCsrfToken(): Promise<string | null> {
  const response = await fetch(`${BASE_URL}${CSRF_ENDPOINT}`, {
    method: 'GET',
    credentials: 'include',
    headers: { Accept: 'application/json' }
  })

  if (!response.ok) return null

  const body = (await response.json()) as { result?: { csrfToken?: string } } | null
  return body?.result?.csrfToken ?? null
}

function _ensureCsrf(): Promise<void> {
  // Browser-session concern only: under SSR this module is shared by every concurrent
  // request in the process, so the server must never cache or reuse a token here.
  if (import.meta.env.SSR) return Promise.resolve()
  if (_csrfToken) return Promise.resolve()
  if (_csrfInflight) return _csrfInflight
  _csrfInflight = _fetchCsrfToken()
    .then((next) => {
      _csrfToken = next
    })
    .finally(() => {
      _csrfInflight = null
    })
  return _csrfInflight
}

function _invalidateCsrf(): void {
  _csrfToken = null
  _csrfInflight = null
}

function _csrfHeader(): Record<string, string> | null {
  if (!_csrfToken) return null
  return { [CSRF_HEADER]: _csrfToken }
}

async function request<T = unknown>(
  method: Method,
  url: string,
  data: Record<string, any> = {},
  options: Options = {}
): Promise<T> {
  const baseURL = options.baseURL ?? BASE_URL
  const fullUrl = buildUrl(baseURL, url, method === 'get' ? prepareParams(unrefs(data)) : null)
  const isMutating = method !== 'get' && method !== 'head' && method !== 'options'
  const isTunneled = TUNNELED_METHODS.includes(method)
  const transportMethod = isTunneled ? 'POST' : method.toUpperCase()

  async function send(): Promise<Response> {
    const controller = new AbortController()
    if (options.signal) {
      options.signal.addEventListener('abort', () => controller.abort(options.signal!.reason), { once: true })
    }
    const timeoutMs = options.timeout ?? DEFAULT_TIMEOUT_MS
    const timeoutId = setTimeout(
      () => controller.abort(new DOMException('Request timed out', 'TimeoutError')),
      timeoutMs
    )

    const init: RequestInit = {
      method: transportMethod,
      headers: { Accept: 'application/json', ...(options.headers ?? {}) },
      credentials: options.withCredentials === false ? 'same-origin' : 'include',
      signal: controller.signal
    }

    if (isMutating) {
      await _ensureCsrf()
      const csrfHeader = _csrfHeader()
      if (csrfHeader) init.headers = { ...(init.headers as Record<string, string>), ...csrfHeader }
    }

    if (method !== 'get' && method !== 'head') {
      const payload = unrefs(data)
      if (isTunneled) payload._method = method

      if (options.asJson) {
        init.body = JSON.stringify(prepareParams(payload))
        init.headers = { ...(init.headers as Record<string, string>), 'Content-Type': 'application/json' }
      } else {
        init.body = toFormData(payload)
        // browser sets multipart/form-data boundary automatically — do NOT set Content-Type manually
      }
    }

    try {
      return await fetch(fullUrl, init)
    } finally {
      clearTimeout(timeoutId)
    }
  }

  let response: Response
  try {
    response = await send()
    if (response.status === 419 && isMutating) {
      _invalidateCsrf()
      await _ensureCsrf()
      response = await send()
    }
  } catch (e) {
    const isTimeout = e instanceof DOMException && e.name === 'TimeoutError'
    throw new HttpRequestError({
      status: 0,
      body: isTimeout ? 'Request timed out' : 'Network error',
      url: fullUrl,
      method,
      message: isTimeout ? 'Request timed out' : (e as Error).message,
      cause: e
    })
  }

  const body = await parseBody(response)

  if (!response.ok) {
    if (response.status === 401) {
      getUnauthorizedHandler()?.()
    }
    fireValidationError(body, options)
    fireNotification(body, 'error', options)

    if (response.status === 404 && options.allowAbort !== false) {
      throw new HttpAbortError(404)
    }

    throw new HttpRequestError({
      status: response.status,
      body,
      url: fullUrl,
      method,
      message:
        typeof body === 'object' && body !== null && 'message' in body && typeof body.message === 'string'
          ? body.message
          : `HTTP ${response.status}`
    })
  }

  fireNotification(body, 'success', options)

  return body as T
}

function buildUrl(baseURL: string, url: string, params: Record<string, any> | null): string {
  const isAbsolute = /^https?:\/\//i.test(url)
  const joined = isAbsolute ? url : `${baseURL.replace(/\/$/, '')}${url.startsWith('/') ? '' : '/'}${url}`

  if (!params) return joined

  const search = new URLSearchParams()
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null) return
    if (Array.isArray(value)) {
      value.forEach((v) => search.append(`${key}[]`, String(v)))
    } else {
      search.append(key, String(value))
    }
  })

  const qs = search.toString()
  if (!qs) return joined
  return `${joined}${joined.includes('?') ? '&' : '?'}${qs}`
}

async function parseBody(response: Response): Promise<unknown> {
  if (response.status === 204) return null
  const contentType = response.headers.get('Content-Type') ?? ''
  if (contentType.includes('application/json')) {
    try {
      return await response.json()
    } catch {
      return null
    }
  }
  try {
    return await response.text()
  } catch {
    return null
  }
}

function fireNotification(body: unknown, type: 'success' | 'error', options: Options): void {
  if (!options.onNotification) return
  if (typeof body !== 'object' || body === null) return
  const description = (body as { description?: unknown }).description
  if (typeof description === 'string' || Array.isArray(description)) {
    options.onNotification(type, description as string | string[])
  }
}

function fireValidationError(body: unknown, options: Options): void {
  if (typeof body !== 'object' || body === null) return
  const errors = (body as { errors?: unknown }).errors
  if (!errors || typeof errors !== 'object' || Array.isArray(errors)) return

  const typed = errors as Record<string, string[]>

  if (options.form) {
    for (const [field, messages] of Object.entries(typed)) {
      for (const message of messages) options.form.addError(field, message)
    }
  }

  options.onValidationError?.(typed)
}

export { request, _ensureCsrf as ensureCsrf, _invalidateCsrf as invalidateCsrf }
```

**File:** `{shared-lib}/http-request/types.ts`
```ts
type Method = 'get' | 'delete' | 'head' | 'options' | 'post' | 'put' | 'patch'

type NotificationType = 'success' | 'error'

interface ValidationFormSink {
  addError: (fieldPath: string, message: string) => void
}

type Options = {
  baseURL?: string
  headers?: Record<string, string>
  withCredentials?: boolean
  asJson?: boolean
  timeout?: number
  signal?: AbortSignal
  form?: ValidationFormSink
  onNotification?: (type: NotificationType, message: string | string[]) => void
  onValidationError?: (errors: Record<string, string[]>) => void
  allowAbort?: boolean
}

type HttpRequestErrorInit = {
  status: number
  body: unknown
  url: string
  method: Method
  message?: string
  cause?: unknown
}

class HttpRequestError extends Error {
  readonly status: number
  readonly body: unknown
  readonly url: string
  readonly method: Method
  readonly cause?: unknown

  constructor(init: HttpRequestErrorInit) {
    super(init.message ?? `HTTP ${init.status} ${init.method.toUpperCase()} ${init.url}`)
    this.name = 'HttpRequestError'
    this.status = init.status
    this.body = init.body
    this.url = init.url
    this.method = init.method
    this.cause = init.cause
  }
}

export { HttpRequestError, type Method, type NotificationType, type Options }
```

**File:** `{shared-lib}/http-request/abort.ts`
```ts
import { type AbortStatus, HttpAbortError } from './HttpAbortError'

function abort(status: AbortStatus): never {
  throw new HttpAbortError(status)
}

export { abort }
```

**File:** `{shared-lib}/http-request/HttpAbortError.ts`
```ts
type AbortStatus = 404

class HttpAbortError extends Error {
  readonly status: AbortStatus

  constructor(status: AbortStatus) {
    super(`HTTP ${status}`)
    this.name = 'HttpAbortError'
    this.status = status
  }
}

export { HttpAbortError, type AbortStatus }
```

**File:** `{shared-lib}/http-request/useHttpRequest.ts`
```ts
import { request } from './request'
import type { Method, NotificationType, Options } from './types'

type NotificationHandler = (type: NotificationType, message: string | string[]) => void
type UnauthorizedHandler = () => void

let notificationHandler: NotificationHandler | undefined
let unauthorizedHandler: UnauthorizedHandler | undefined

function setNotificationHandler(handler: NotificationHandler): void {
  notificationHandler = handler
}

function setUnauthorizedHandler(handler: UnauthorizedHandler): void {
  unauthorizedHandler = handler
}

function getUnauthorizedHandler(): UnauthorizedHandler | undefined {
  return unauthorizedHandler
}

function withDefaults(options?: Options): Options {
  return {
    onNotification: notificationHandler,
    ...options
  }
}

function call<T>(method: Method, url: string, data?: Record<string, any>, options?: Options): Promise<T> {
  return request<T>(method, url, data, withDefaults(options))
}

function useHttpRequest() {
  return {
    request,
    get: <T = unknown>(url: string, data?: Record<string, any>, options?: Options) =>
      call<T>('get', url, data, options),
    post: <T = unknown>(url: string, data?: Record<string, any>, options?: Options) =>
      call<T>('post', url, data, options),
    put: <T = unknown>(url: string, data?: Record<string, any>, options?: Options) =>
      call<T>('put', url, data, options),
    patch: <T = unknown>(url: string, data?: Record<string, any>, options?: Options) =>
      call<T>('patch', url, data, options),
    delete: <T = unknown>(url: string, data?: Record<string, any>, options?: Options) =>
      call<T>('delete', url, data, options),
    head: <T = unknown>(url: string, data?: Record<string, any>, options?: Options) =>
      call<T>('head', url, data, options),
    options: <T = unknown>(url: string, data?: Record<string, any>, options?: Options) =>
      call<T>('options', url, data, options)
  }
}

export {
  useHttpRequest,
  setNotificationHandler,
  setUnauthorizedHandler,
  getUnauthorizedHandler,
  type NotificationHandler,
  type UnauthorizedHandler
}
```

**File:** `{shared-lib}/http-request/utils/index.ts`
```ts
export { prepareParams } from './prepareParams'
export { toFormData } from './toFormData'
export { unrefs } from './unrefs'
```

**File:** `{shared-lib}/http-request/utils/prepareParams.ts`
```ts
function prepareParams(data: Record<string, any>): Record<string, any> {
  Object.keys(data).forEach((key) => {
    data[key] = typeof data[key] === 'boolean' ? Number(data[key]) : data[key]
  })

  return data
}

export { prepareParams }
```

**File:** `{shared-lib}/http-request/utils/toFormData.ts`
```ts
import { serialize } from 'object-to-formdata'

function toFormData(data: Record<string, any>): FormData {
  return serialize(data, {
    indices: true,
    booleansAsIntegers: true
  })
}

export { toFormData }
```

**File:** `{shared-lib}/http-request/utils/unrefs.ts`
```ts
import { isRef, unref } from 'vue'

function unrefs(data: Record<string, any>): Record<string, any> {
  if (isRef(data)) {
    return unref<Record<string, any>>(data)
  }

  const result: Record<string, any> = {}

  Object.keys(data).forEach((key) => {
    result[key] = isRef(data[key]) ? unref(data[key]) : data[key]
  })

  return result
}

export { unrefs }
```

**File:** `{initial-plugins}/httpRequest.ts`
```ts
import type { QueryClient } from '@tanstack/vue-query'

import { clearAuthenticated, isAuthQuery } from '{entity}/session'

import { setNotificationHandler, setUnauthorizedHandler } from '{shared-lib}/http-request'
import { useToast } from '{shared-lib}/toast'

export function initHttpRequest(queryClient: QueryClient): void {
  const toast = useToast()

  setNotificationHandler((type, message) => {
    const text = Array.isArray(message) ? message.join(' ') : message
    if (type === 'success') {
      toast.success(text)
    } else {
      toast.error(text)
    }
  })

  setUnauthorizedHandler(() => {
    clearAuthenticated()
    queryClient.removeQueries({ predicate: isAuthQuery })
  })
}
```
