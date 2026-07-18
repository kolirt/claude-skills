# Runtime: nuxt (stub)

**This doc is intentionally a stub.** Nuxt is a different runtime from `vite-vue` — it
is a meta-framework that owns pieces this plugin currently only knows how to hand-author.
It is not yet codified from a real Nuxt reference project. Treat everything below as
the current best understanding, not a settled discipline.

- [invariant · desired] Under `runtime = nuxt`, Nuxt itself OWNS: the app bootstrap (no
  hand-written `createApp` or entry files), routing (file-based `pages/`), layouts,
  middleware, plugins (`defineNuxtPlugin` + auto-registration by convention), and the
  ssr/csr toggle (`nuxt.config`). Therefore the Vite bootstrap discipline, the routing
  skills' own wiring steps, and `plugin-registration` do **not** apply as written —
  `vue-work` gates them off for this runtime in favor of Nuxt's own conventions.
  - ✅ do: let Nuxt's file-based `pages/`, `layouts/`, `middleware/`, and `plugins/`
    conventions drive structure; do not reintroduce a hand-rolled router or a manual
    `app.use` registration step.
  - ❌ don't: apply the `vite-vue` bootstrap doc, or the `vue-router` / `pages` /
    `layouts` / `page-middlewares` / `plugin-registration` skills' wiring steps, under
    `runtime = nuxt` — why: Nuxt already owns that surface; layering a hand-authored
    convention on top would fight the framework.

- [invariant · desired] Domain skills that only read placement tokens — `stores`,
  `persistence`, `http-request`, `forms`, `auth`, `modals`, `tanstack-query`, `seo` —
  mostly still apply under Nuxt, since they reason about *where logic lives*, not about
  bootstrap/routing mechanics. However, the architecture↔Nuxt directory mapping (how
  FSD layers or a flat `src/` map onto a Nuxt project's directory conventions) is
  **unsettled** — this doc does not resolve it.

- [invariant · desired] Because the architecture↔Nuxt mapping is unsettled, when
  `runtime = nuxt`, **ask the developer how their Nuxt project is structured** before
  placing any file — do not assume an FSD-under-Nuxt or flat-under-Nuxt layout.
  - ✅ do: ask which directories/conventions the project already uses before writing
    anything.
  - ❌ don't: silently reuse the `vite-vue` architecture mapping or invent a new one —
    why: this doc will be codified for real once a Nuxt reference project exists; until
    then, guessing risks locking in the wrong convention.
