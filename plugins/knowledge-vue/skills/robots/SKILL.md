---
name: robots
description: Use when adding or managing robots.txt delivery in a Vue/Vite project via vite-plugin-robots. Covers plugin wiring and per-environment file conventions only — for robots.txt policy principles defer to the `robots` skill from knowledge-seo; for install and build script setup defer to `project-init`.
---

# robots (Vue) — robots.txt delivery via vite-plugin-robots

Read `../../core/placement.md`

## Overview

`vite-plugin-robots` (npm package name: `vite-plugin-robots`) copies a pre-authored `.robots.<mode>.txt` file from the project root into the client output directory at build time only (`apply: 'build'`). The plugin does not emit anything during `vite dev`. It exposes three options: `robotsDir` (source directory, defaults to project root), `outputRobotsFileName` (output filename, defaults to `robots.txt`), and `enableDebug`. There is no JavaScript-level policy configuration — the policy lives entirely in the text files.

## Source files

Keep two environment-specific files at the project root:

```
.robots.development.txt    ← closed: blocks all crawlers on dev/staging builds
.robots.production.txt     ← open: live crawl policy + Sitemap line
```

### .robots.development.txt

```
User-agent: *
Disallow: /
```

### .robots.production.txt

```
User-agent: *
Disallow: /admin/
Disallow: /api/

Sitemap: https://<your-domain>/sitemap.xml
```

Define the production policy (which paths to allow or block, per-bot rules, crawl-delay) according to the `robots` principle skill from knowledge-seo.

## Vite config

```ts
// vite.config.ts
import { defineConfig } from 'vite'
import Robots from 'vite-plugin-robots'

export default defineConfig(({ mode }) => ({
  plugins: [
    Robots({
      robotsDir: '.',
      outputRobotsFileName: 'robots.txt',
      enableDebug: mode !== 'production',
    }),
  ],
}))
```

The plugin resolves `.robots.${mode}.txt` from `robotsDir` at build time and writes the result to the client `outDir`. The `mode` matches the value passed to `vite build --mode <mode>`.

## Rules

- [invariant · desired] `vite-plugin-robots` runs only at build time (`apply: 'build'`) — no robots file is emitted during `vite dev`.
- [invariant · desired] A development or staging build uses `.robots.development.txt` (`Disallow: /`) to keep non-production environments closed to crawlers.
- [invariant · desired] `.robots.production.txt` contains the live crawl policy and a `Sitemap:` line pointing to the production sitemap URL.
- [invariant · desired] Policy decisions — which paths to allow or block, per-bot directives, crawl-delay — are governed by the `robots` principle skill (knowledge-seo), not defined in the Vite config.

## ✅ / ❌

| ✅ Do | ❌ Do not |
|---|---|
| Maintain separate `.robots.<mode>.txt` files per build mode | Use a single `robots.txt` applied to all builds |
| Set `Disallow: /` in `.robots.development.txt` | Leave development or staging builds open to crawlers |
| Add a `Sitemap:` line in `.robots.production.txt` | Hardcode the sitemap URL in the Vite plugin config |
| Let `vite-plugin-robots` copy the file at build time | Manually copy or template `robots.txt` as a post-build step |
| Consult the `robots` skill for policy decisions | Define blocking rules inside `vite.config.ts` |

## Related skills (by name)

- `robots` — robots.txt policy principles (knowledge-seo)
- `project-init` — install and build script configuration (knowledge-vue)
- `sitemaps` — sitemap generation principles (knowledge-seo)
