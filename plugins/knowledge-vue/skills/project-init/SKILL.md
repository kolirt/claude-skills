---
name: project-init
description: Use when scaffolding a new Vue SSR project or auditing an existing one — baseline dependencies, mode-aware build scripts for both SSR bundles, and robots.txt baseline wired by default via vite-plugin-robots.
---

# project-init (Vue) — scaffold conventions

Applied without being asked when bootstrapping a Vue SSR project. Covers two permanent
baseline concerns: **mode-aware build scripts** and **robots.txt by default**.

## Mode-aware build scripts

Every SSR project exposes named, mode-explicit build scripts in `package.json`. A plain
`build` command without a `--mode` flag is ambiguous for automated pipelines and robots.

- [invariant · desired] Provide `build:dev` and `build:prod`; never rely on a bare `build`
  as the canonical SSR build target.

  ```jsonc
  // package.json
  "scripts": {
    "build:dev":  "run-s build:dev:client  build:dev:server  build:dev:bootstrap",
    "build:prod": "run-s build:prod:client build:prod:server build:prod:bootstrap",

    "build:dev:client":     "vite build --ssrManifest --mode development",
    "build:dev:server":     "vite build --ssr src/entry-server.ts --mode development",
    "build:dev:bootstrap":  "tsc -p tsconfig.server.json",

    "build:prod:client":    "vite build --ssrManifest --mode production",
    "build:prod:server":    "vite build --ssr src/entry-server.ts --mode production",
    "build:prod:bootstrap": "tsc -p tsconfig.server.json"
  }
  ```

  Each named build runs three steps in sequence:
  1. **Client bundle** — `vite build --ssrManifest --mode <mode>` (generates the asset
     manifest consumed by the server renderer).
  2. **Server bundle** — `vite build --ssr <entryServer> --mode <mode>`.
  3. **Server bootstrap** — `tsc` compiles the Node server entry point.

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

## Deferred detail

- **Robots principles** (crawl semantics, `noindex`, policy design): see the `robots` skill.
- **Robots delivery** in Vue (SSR-served `robots.txt`, per-environment switching in detail):
  see the knowledge-vue `robots` skill.

## Related skills (by name)

robots · ssr
