---
name: robots
description: Use when adding or managing robots.txt delivery in a Vue/Vite project via vite-plugin-robots. Covers plugin wiring and per-environment file conventions only — for robots.txt policy principles defer to the `robots` skill from knowledge-seo; for install and build script setup defer to `project-init`.
---

# robots (Vue) — robots.txt delivery via vite-plugin-robots

Read `../../core/placement.md` for the token vocabulary; paths resolve in the active architecture doc.

- [invariant · desired] [runtime: vite-vue] robots.txt DELIVERY is runtime-specific. Under
  runtime = vite-vue the delivery mechanism is `vite-plugin-robots`, as described below. Under
  Nuxt the file is served by Nuxt/Nitro instead (public asset or a Nitro route) — see
  core/runtimes/nuxt.md; do not install `vite-plugin-robots` there. The robots.txt POLICY is
  runtime-independent — defer to the `robots` skill from knowledge-seo either way.

Read `references/robots.md` and reproduce it — it holds the two per-environment robots
files. The Vite plugin wiring (the full `vite.config.ts`, including the `robots()` call)
is owned by `project-init`'s scaffold etalons (`references/project-scaffold.md` /
`project-scaffold.csr.md`) — not reproduced here.

## Overview

`vite-plugin-robots` (npm package name: `vite-plugin-robots`) copies a pre-authored
`.robots.<mode>.txt` file from the project root into the client output directory at build
time only (`apply: 'build'`). The plugin does not emit anything during `vite dev`. There is
no JavaScript-level policy configuration — the policy lives entirely in the text files.

- [invariant · desired] Call `robots()` with **no options** when the project's
  `.robots.<mode>.txt` files live at the project root and the output filename stays the
  default `robots.txt` — the plugin's own defaults (`robotsDir: '.'`,
  `outputRobotsFileName: 'robots.txt'`) already match that layout, so there is nothing to
  configure. This is the baseline shape.
- [preference · desired] Pass `robotsDir`, `outputRobotsFileName`, or `enableDebug` only to
  override a NON-default layout (files kept elsewhere, a different output filename, or
  explicit debug logging) — do not pass them as a matter of course alongside a default
  layout.

## Source files

Keep two environment-specific files at the project root: `.robots.development.txt` and
`.robots.production.txt`. Both ship the **same closed baseline** (`Disallow: /`).
Development stays closed permanently; production is closed until the developer
deliberately opens it before launch. See `references/robots.md` for the exact files to
reproduce; opening production — which paths to allow/block, per-bot rules, crawl-delay,
the `Sitemap:` line — is the job of the `robots` policy skill from knowledge-seo, not this
skill.

## Vite config

The full `vite.config.ts` — including the `robots()` call in the `plugins` array — is
owned by `project-init`'s scaffold etalons; read it there for the complete file. In
short: import `robots` from `vite-plugin-robots` and add `robots()` (zero-config, per
above) to the `plugins` array. It resolves `.robots.${mode}.txt` from the project root at
build time and writes the result to the client `outDir`. The `mode` matches the value
passed to `vite build --mode <mode>`.

## Rules

- [invariant · desired] `vite-plugin-robots` runs only at build time (`apply: 'build'`) — no robots file is emitted during `vite dev`.
- [invariant · desired] A development or staging build uses `.robots.development.txt` (`Disallow: /`) to keep non-production environments closed to crawlers.
- [invariant · desired] `.robots.production.txt` ships the same closed baseline (`Disallow: /`) by default — closed until the developer deliberately opens it before launch with the live crawl policy and a `Sitemap:` line pointing to the production sitemap URL.
- [invariant · desired] Policy decisions — which paths to allow or block, per-bot directives, crawl-delay — are governed by the `robots` principle skill (knowledge-seo), not defined in the Vite config.

## ✅ / ❌

| ✅ Do | ❌ Do not |
|---|---|
| Maintain separate `.robots.<mode>.txt` files per build mode | Use a single `robots.txt` applied to all builds |
| Set `Disallow: /` in `.robots.development.txt` | Leave development or staging builds open to crawlers |
| Ship `.robots.production.txt` closed (`Disallow: /`) until launch, then add a `Sitemap:` line when opening it | Hardcode the sitemap URL in the Vite plugin config |
| Let `vite-plugin-robots` copy the file at build time | Manually copy or template `robots.txt` as a post-build step |
| Consult the `robots` skill for policy decisions | Define blocking rules inside `vite.config.ts` |

## Related skills (by name)

- `robots` — robots.txt policy principles (knowledge-seo)
- `project-init` — install and build script configuration (knowledge-vue)
- `sitemaps` — sitemap generation principles (knowledge-seo)
