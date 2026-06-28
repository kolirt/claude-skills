---
name: plugin-registration
description: Use when wiring a Vue plugin into the app (installing + registering a package the developer's way). Owns the developer's plugin-registration discipline; capability skills (e.g. modals, vue-router) defer to it by name instead of restating it.
---

# plugin-registration (Vue)

The developer's discipline for registering ANY Vue plugin (modal, router, toast, …).
Capability skills that install a package defer to THIS skill for registration — they
never restate these steps.

Read `../../core/placement.md` first (resolve the `{plugins}` token for the current
project's architecture).

## Rules

- [invariant · desired] Every Vue plugin is registered through a **factory function
  in a dedicated file** under `{plugins}/<name>.ts`, which the app entry/factory calls
  via `app.use(<factory>())`. The plugin is **never** configured inline in `main.ts`.
  This holds in both FSD and non-FSD — only the location (`{plugins}`) differs.
  - ✅ do:
    ```ts
    // {plugins}/modal.ts
    import { createModal as createModalMaster } from '@kolirt/vue-modal'
    export function createModal() {
      return createModalMaster({ /* package config lives here, not in main.ts */ })
    }

    // main.ts
    app.use(createModal())
    ```
  - ❌ don't:
    ```ts
    // main.ts
    app.use(createModalMaster({ groups: { /* ... */ } })) // inline config — never
    ```
  - why: the factory file keeps each plugin's wiring/config out of `main.ts`, gives
    one place to extend a plugin's setup, and keeps `main.ts` a thin list of
    `app.use(...)` calls.
- [preference · desired] When several plugins exist, re-export each factory from a
  `{plugins}/index.ts` barrel, and have the app factory call them in order.

- [invariant · desired] The **head/unhead** integration is a plugin factory
  `createHead({ ssr })` in `{plugins}/head.ts` that dynamically imports the server or
  client `unhead` build and returns the instance. The app factory registers it via
  `app.use(head)` — exactly like other `create*` plugins. Do NOT export a bare config
  blob and create the instance ad-hoc inside the entry files.
  ```ts
  // {plugins}/head.ts
  import type { VueHeadClient } from '@unhead/vue'
  export async function createHead(options: { ssr?: boolean }): Promise<VueHeadClient> {
    const { createHead: createUnhead } = options.ssr
      ? await import('@unhead/vue/server')
      : await import('@unhead/vue/client')
    return createUnhead() as VueHeadClient
  }
  ```
