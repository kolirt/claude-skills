---
name: plugin-registration
description: Use when wiring a Vue plugin into the app (installing + registering a package the developer's way). Owns the developer's plugin-registration discipline; capability skills (e.g. modals) defer to it by name instead of restating it.
---

# plugin-registration (Vue)

The developer's discipline for registering ANY Vue plugin (modal, toast, i18n, …).
Capability skills that install a package defer to THIS skill for registration —
they never restate these steps.

Read `../../core/placement.md` first (where the registration file goes — it differs
between FSD and non-FSD projects).

## Rules

- [invariant · desired] Every Vue plugin is registered through a **factory function
  in a dedicated file**, which `main.ts` calls via `app.use(<factory>())`. The plugin
  is **never** configured inline in `main.ts`. This holds in **both FSD and non-FSD**
  projects — only the file's location differs (see `placement.md`: FSD → the app-init
  plugins layer; non-FSD → `src/plugins/`).
  - ✅ do:
    ```ts
    // plugins/modal.ts
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
