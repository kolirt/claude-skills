# robots (Vue) — vite-plugin-robots wiring etalon

Scope: the per-environment `.robots.<mode>.txt` files only. The `vite.config.ts` `robots()`
call is described below but not reproduced as a file — full file is owned by `project-init`'s
scaffold etalons. robots.txt *policy* is the `robots` skill from knowledge-seo.

On a flat `src/` (non-FSD), `{project-root}` resolves unchanged.

## Files

- `{project-root}/.robots.development.txt`
- `{project-root}/.robots.production.txt`

`{project-root}/vite.config.ts` in full is owned by `project-init`'s scaffold etalons
(`project-scaffold.md` / `project-scaffold.csr.md`), not reproduced here even as a slice.
This skill's only contribution is the bare `robots()` call added to the `plugins` array.

`robots()` is called with **no options** — the plugin's defaults (`robotsDir: '.'`,
`outputRobotsFileName: 'robots.txt'`) already match this layout. It resolves
`.robots.${mode}.txt` and copies it to the client `outDir`, build-time only (`apply: 'build'`).

**File:** `{project-root}/.robots.development.txt`

```txt
User-agent: *
Disallow: /

Allow: /robots.txt
```

**File:** `{project-root}/.robots.production.txt`

```txt
User-agent: *
Disallow: /

Allow: /robots.txt
```

Both files ship the same closed baseline; production stays closed until the developer
deliberately opens it before launch. Opening it (crawl policy, per-bot rules, `Sitemap:`)
is the job of the `robots` policy skill from knowledge-seo.
