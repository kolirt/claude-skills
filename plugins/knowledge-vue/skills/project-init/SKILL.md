---
name: project-init
description: Use when scaffolding a new Vue project (SPA or SSR) or auditing one — baseline dependencies, mode-aware build scripts, and robots.txt baseline wired by default via vite-plugin-robots. SSR is an optional layer, not assumed.
---

# project-init (Vue) — scaffold conventions

Applied without being asked when bootstrapping a Vue project. Covers two permanent baseline
concerns: **mode-aware build scripts** and **robots.txt by default**. Both apply to ANY Vue
project.

> **SSR is OPTIONAL — the default is a SPA.** SSR is an additional layer added only when the
> project actually needs server-side rendering (see the `ssr` skill). Every other convention
> (FSD layers, stores without Pinia, http-request, TanStack Query, modals, …) works exactly
> the same with or without SSR. Do not assume a project is SSR.

- [invariant · desired] At scaffold time, **ask the developer: SSR or CSR (SPA)?** — never
  assume. The answer decides whether the SSR add-on applies (server bundle, entry split, and
  the `ssr` / `hydration` skills). For an EXISTING project, detect it instead of asking (is
  there a server entry / a `--ssr` build script?).
  - ✅ do: "Should this be SSR or a CSR/SPA? SSR adds a server bundle + hydration; CSR is the
    simpler default."
  - ❌ don't: silently scaffold SSR (server bundle, entryServer) for a plain `yarn create vite`
    request — why: SSR is a deliberate choice that adds a Node server and build complexity.

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
- [invariant · desired] (SSR) scaffold the `{initial-plugins}/` layer — the per-request
  `createApp` factory (`{initial-plugins}/createApp.ts`), any imperative initialisers
  (e.g. `initHttpRequest`), and a barrel `{initial-plugins}/index.ts` — plus **exactly two**
  entry files `{app}/entryClient.ts` and `{app}/entryServer.ts` that import from it. There is
  no third shared `entry.ts`. Details: the `ssr` skill.

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

## Related skills (by name)

robots · ssr
