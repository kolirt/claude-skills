---
name: project-init
description: Use when scaffolding a new Vue project (SPA or SSR) or auditing one — baseline dependencies, mode-aware build scripts, and robots.txt baseline wired by default via vite-plugin-robots. SSR is an optional layer, not assumed.
---

# project-init (Vue) — scaffold conventions

Applied without being asked when bootstrapping a Vue project. Covers two permanent baseline
concerns: **mode-aware build scripts** and **robots.txt by default**. This skill applies under
runtime = vite-vue — the scaffold commands, build scripts, and `vite-plugin-robots` wiring below
are Vite-specific. Under Nuxt, entry-file scaffolding is gated off by step 0 (Nuxt owns the app
bootstrap) and robots.txt delivery is Nuxt/Nitro-owned instead — see core/runtimes/nuxt.md and
the `robots` skill, which already forbids installing `vite-plugin-robots` there.

> **`{runtime, architecture, projectType}` are determined by step 0 of `vue-work`, not here.**
> Step 0 detects them on an existing project and ASKS on a greenfield one. `project-init`
> **realizes** the greenfield arm of that determination — it is where the asking actually
> happens during scaffolding — but it never re-decides a constant step 0 already fixed.

> **SSR is OPTIONAL — the default is a SPA.** SSR is an additional layer added only when the
> project actually needs server-side rendering. Every other convention (stores without Pinia,
> http-request, TanStack Query, modals, …) works exactly the same with or without SSR. Do not
> assume a project is SSR. The concrete bootstrap shape for either case lives in the active
> project-type doc (`core/project-types/<t>.md`).

> **Architecture (FSD vs non-FSD) is the developer's CHOICE — do NOT silently assume FSD.**
> Every convention skill works with both: FSD (numbered layers `01-app`…`07-shared`) and
> non-FSD (a flat `src/`). `placement.md` defines the token vocabulary; the active
> architecture doc (`core/architectures/<architecture>.md`) resolves each token to a path.

- [invariant · desired] On a GREENFIELD scaffold, **ask the developer: SSR or CSR (SPA)?** —
  never assume. This ask is the greenfield arm of step 0's `projectType` determination, not an
  independent decision. The answer decides whether the SSR add-on applies (server bundle, entry
  split, `hydration`) and which project-type doc is loaded. For an EXISTING project, step 0 has
  already detected it (server entry / `--ssr` build script) — do not re-ask.
  - ✅ do: "Should this be SSR or a CSR/SPA? SSR adds a server bundle + hydration; CSR is the
    simpler default."
  - ❌ don't: silently scaffold SSR (server bundle, entryServer) for a plain `yarn create vite`
    request — why: SSR is a deliberate choice that adds a Node server and build complexity.

- [invariant · desired] On a GREENFIELD scaffold, **ask the developer: FSD or plain (non-FSD)
  structure?** — never silently default to FSD. This ask is the greenfield arm of step 0's
  `architecture` determination, not an independent decision. The answer decides the folder
  layout (numbered `01-app`…`07-shared` vs a flat `src/`); all convention skills apply either
  way via the active architecture doc. For an EXISTING project, step 0 has already detected it
  (numbered layer dirs → FSD, else non-FSD) — do not re-ask.
  - ✅ do: "Should this use FSD (numbered layers) or a plain flat `src/` structure?"
  - ❌ don't: assume FSD because the conventions mention it, or rebuild a plain structure into
    numbered FSD without being asked — why: architecture is the developer's call, not a default.

## Scaffold cleanup

- [invariant · desired] After `yarn create vite`, **remove the default scaffold cruft** before
  building: the `src/assets/<logo>.svg` (e.g. `vite.svg`) and `public/vite.svg` placeholders,
  the `HelloWorld.vue` / boilerplate `App.vue`, and the default `src/style.css`. A leftover
  `vite.svg` or stray root `style.css` is a defect.
- [invariant · desired] The real global stylesheet lives in `{assets}/styles/` (e.g.
  `{assets}/styles/main.css`), imported by the app entry — **not** at the `src/` root. Keep the
  generated `src/vite-env.d.ts` (Vite ambient types); in FSD it may move to `{app}/types/env.d.ts`.

## Mode-aware build scripts

Expose named, mode-explicit build scripts in `package.json`. A plain `build` without a
`--mode` flag is ambiguous for robots (which `.robots.[mode].txt` to copy) — so even a SPA
needs the split.

- [invariant · desired] Provide `build:dev` and `build:prod` that pass an explicit `--mode`;
  never rely on a bare `build`.

  **SPA (default):**
  ```jsonc
  // package.json
  "scripts": {
    "build:dev":  "vite build --mode development",
    "build:prod": "vite build --mode production"
  }
  ```

- [preference · desired] **SSR (optional add-on)** — ONLY when the project does server-side
  rendering. Adds a server bundle + a Node bootstrap on top of the client build:
  ```jsonc
  "scripts": {
    "build:dev":  "run-s build:dev:client  build:dev:server  build:dev:bootstrap",
    "build:prod": "run-s build:prod:client build:prod:server build:prod:bootstrap",

    "build:dev:client":     "vite build --ssrManifest --mode development",
    "build:dev:server":     "vite build --ssr {app}/entryServer.ts --mode development",
    "build:dev:bootstrap":  "tsc -p tsconfig.server.json",

    "build:prod:client":    "vite build --ssrManifest --mode production",
    "build:prod:server":    "vite build --ssr {app}/entryServer.ts --mode production",
    "build:prod:bootstrap": "tsc -p tsconfig.server.json"
  }
  ```
  The SSR build runs three steps: client bundle (`--ssrManifest`), server bundle
  (`--ssr <entryServer>`), and a `tsc` server bootstrap.
- [invariant · desired] The bootstrap scaffold — the `createApp` factory, the
  `{initial-plugins}/` layer and its barrel, and which entry files exist — is **owned by the
  active project-type doc** (`core/project-types/<t>.md`). Scaffold what that doc prescribes;
  do not restate or invent a bootstrap shape here.

## Robots baseline (installed by default)

Every project gets a closed-by-default robots policy. This is not opt-in — it is
scaffolded on init so that development and staging builds are never inadvertently indexed.

- [invariant · desired] Install `vite-plugin-robots` and configure it in `vite.config.ts`.
  Reference the package by its npm name (`vite-plugin-robots`) — never use a GitHub URL.

- [invariant · desired] Provide two policy files at the project root:

  `.robots.development.txt` — **closed**: no crawler access on dev/staging builds.

  ```
  User-agent: *
  Disallow: /
  ```

  `.robots.production.txt` — **open with policy + sitemap**:

  ```
  User-agent: *
  Disallow: /admin/
  # add additional Disallow lines per project requirements

  Sitemap: https://<your-domain>/sitemap.xml
  ```

- [invariant · desired] Wire the plugin so that a `--mode development` build picks up
  `.robots.development.txt` and a `--mode production` build picks up
  `.robots.production.txt`. Dev and staging environments are always closed; production is
  open under the explicit policy.

  ```ts
  // vite.config.ts (illustrative wiring)
  import robots from 'vite-plugin-robots'

  export default defineConfig(({ mode }) => ({
    plugins: [
      robots({
        policy: mode === 'production'
          ? { userAgent: '*', allow: '/', sitemap: 'https://<your-domain>/sitemap.xml' }
          : { userAgent: '*', disallow: '/' },
      }),
    ],
  }))
  ```

  ✅ Dev build → `Disallow: /` (crawlers blocked).
  ✅ Prod build → explicit allow policy with Sitemap line.
  ❌ A single unconditional `robots.txt` with no mode distinction — staging leaks to
  indexers if ever deployed to a public URL.

## Environment configuration

- [invariant · desired] At scaffold time, create `.env.development` and `.env.production`
  holding **environment-varying** values as `VITE_*` variables:
  ```
  # .env.development / .env.production
  VITE_API_URL=https://api.example.com
  VITE_APP_ORIGIN=https://example.com
  ```
  Add `.env*.local` to `.gitignore` so local overrides are never committed.

- [invariant · desired] **Environment-varying values** (API base URL, site origin, OAuth
  keys) belong in `.env.*` as `VITE_*` and are read via `import.meta.env` at runtime.
  **Never hardcode them** in `{shared-config}` or any other source file. STATIC values
  (site display name, tagline) may live in `{shared-config}`.

## Deferred detail

- **Robots principles** (crawl semantics, `noindex`, policy design): see the `robots` skill.
- **Robots delivery** in Vue (SSR-served `robots.txt`, per-environment switching in detail):
  see the knowledge-vue `robots` skill.
- **Bootstrap / entry scaffolding** (createApp, entries, `{initial-plugins}`): see the active
  project-type doc `core/project-types/<t>.md`.

## Related skills (by name)

robots · hydration
