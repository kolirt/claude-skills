# Claude Skills Marketplace

Native Claude Code plugin marketplace.

## Install

```text
/plugin marketplace add kolirt/claude-skills
/plugin install <name>@claude-skills
```

Every plugin below installs the same way — swap in its name:
`agent-companion`, `knowledge`, `knowledge-seo`, `knowledge-vue`, `planning`,
`auditing`, `auditing-prs`, `terse`. Some plugins declare dependencies on others (see
each entry) — install the dependency too, the plugin does not do it for you.

## Plugins

- **agent-companion** — Claude runs as manager and consults several independent
  verifier agents in parallel; REVIEW is any-blocks. **No agents are active by
  default** — enable the ones you want with `/agent-companion:verifiers add <name>`.
  Available adapters (each needs its own CLI installed and authenticated by ANY
  method that CLI supports — browser/OAuth login, config file, or API key; an
  unauthenticated CLI is skipped, not required to use a specific key):
  - `codex` — OpenAI Codex CLI
  - `agy` — Google Antigravity CLI · requires a prior interactive (OAuth browser) login;
    it exposes no on-disk "logged in" marker, so an unauthenticated `agy` passes the probe
    and fails at run time. No effort knob — the reasoning tier is baked into its model
    names (`Gemini 3.5 Flash (Medium)`).
  - `grok` — Grok CLI · xAI's frontier model (whatever xAI ships today)
  - `kimi` — Kimi Code CLI · has no read-only mode of its own (its non-interactive mode
    approves writes silently), so the adapter runs it against a disposable `KIMI_CODE_HOME`
    whose config denies the write tools. Effort is honored through that same config, mapped
    to the nearest tier the chosen model accepts.

  Add a verifier with flags: `/agent-companion:verifiers add codex --model gpt-5.6-sol
  --effort high`. Both flags are optional — omit `--model` for the CLI's own frontier
  default, `--effort` for the dispatch effort (one of low|medium|high|xhigh|max, honored by
  codex, grok and kimi). Model names are stored verbatim, so names with spaces and parentheses
  work. Entries are addressed by their list index, so several entries may share an adapter.

  Add a new agent by dropping an adapter in `plugins/agent-companion/adapters/`
  and listing it. See `.claude/skills/creating-plugins`.

  When 2+ verifiers run, a **synthesizer** can consolidate their reports into one (so the
  session isn't flooded): `/agent-companion:synthesizer set <claude|adapter|none>`.

  **Upgrading to 0.3.0 — two breaking changes.** (1) The `gemini` adapter was removed and
  replaced by `agy` (Google Antigravity CLI); a verifier still pinned to `gemini` is skipped
  with a warning instead of blocking reviews. (2) The panel config moved from
  `verifiers.conf`/`synthesizer.conf` to a single `panel.json`; the old files are **not read
  and not migrated**. If they are still present the plugin warns on stderr and runs on the
  bundled default — rebuild the panel with `/agent-companion:verifiers add …`, then delete
  them. Reading the config now needs `jq` or `python3` on PATH.

  **Durable manager mode.** Plugin hooks persist the on/off state per session, so the
  protocol survives compaction and is re-injected on resume, with a throttled reminder
  in long sessions. `/clear` turns the mode off (enable it again with
  `/agent-companion:on`). Hooks are best-effort — `disableAllHooks` leaves the
  pre-0.2.0 behaviour.

  **Skill-aware panel.** The manager lists the project's convention skills under a
  `SKILL_FILES:` block in the request (`.md` paths only); `verify.sh` splices their
  content straight into each verifier's prompt, so the conventions reach the panel
  without ever entering the main session's context.

- **knowledge** — Stack-independent base for the developer's own coding-knowledge
  plugins: a human-gated capture loop that turns tacit conventions into tagged
  rules and skills, codified into the relevant domain plugin (`knowledge-vue`,
  and any future `knowledge-<stack>`). Not stack knowledge itself — install a
  domain plugin for that.
  - `capture` — do the work on a small greenfield example, ask the developer
    how they want each decision point handled, draft a tagged rule, get their
    explicit accept/reject before writing anything, then codify it (a
    genuinely new pattern becomes a new skill in the domain plugin).

- **knowledge-seo** — Stack-independent SEO policy knowledge: what "correct"
  looks like for meta tags, structured data, sitemaps, robots, and the rest —
  independent of any framework. Depends on `knowledge`. Consumed by
  `knowledge-vue`'s delivery skills (`seo`, `robots`) and required by
  `auditing:seo`.
  - `meta-tags` — title/description/canonical/robots meta, favicon, head validity
  - `structured-data` — schema.org JSON-LD type selection + required fields
  - `social-preview` — Open Graph + Twitter/X Cards, per-platform quirks
  - `canonicalization-and-redirects` — canonical URLs, duplicate content,
    redirects, status codes, trailing slashes, site/HTTPS migrations
  - `international` — hreflang, x-default, locale URL architecture, geotargeting
  - `javascript-seo` — crawlability/indexability for JS/SPA apps (SSR, routing,
    lazy-loading, render parity)
  - `media-seo` — image/video alt text, filenames, formats, image & video sitemaps
  - `page-experience` — Core Web Vitals, HTTPS, security headers, mobile-friendliness
  - `robots` — robots.txt policy: crawl access, sitemap link, AI-crawler allow/deny
  - `sitemaps` — XML sitemap structure, lastmod, sitemap index, submission
  - `url-structure` — URL/route design, pagination, faceted nav, internal linking
  - `indexnow` — instant URL-change notification for Bing/Yandex/Seznam/Naver/Yep
  - `generative-seo` — AI answer engines (AI Overviews, ChatGPT Search,
    Perplexity): llms.txt, AI-crawler access, entity authority

- **knowledge-vue** — One developer's Vue conventions as intent-triggered
  skills, with baseline SEO applied by default. Depends on `knowledge`
  (capture) and `knowledge-seo` (policy). Ships a `SessionStart` hook. All
  Vue work is expected to route through `vue-work` first: it establishes the
  project model — runtime (`vite-vue` vs Nuxt), then under `vite-vue` the
  architecture (`fsd` vs flat `src/`) and project type (`ssr` vs `csr`) —
  before dispatching to a pattern skill. Path resolution for the active
  architecture lives in `core/architectures/<a>.md`; the bootstrap process for
  the active project type lives in `core/project-types/<t>.md`;
  `core/placement.md` is the architecture-neutral token vocabulary every
  pattern skill places files with.
  - `vue-work` — the router: establishes runtime/architecture/project-type,
    then dispatches to the right pattern skill. Self-activating.
  - `project-init` — scaffold a new project's baseline deps, build scripts,
    and default robots.txt
  - `vue-router` — one-time vue-router install + registration
  - `pages` — route/page declaration conventions
  - `page-middlewares` — authoring a single nav middleware
  - `layouts` — page layouts, the `Layouts` enum, the layout resolver
  - `components` — component boundaries, props/emits/slots, reuse discovery
  - `form-elements` — form-control wrapper discipline (skeleton, capture-filled)
  - `forms` — form validation discipline (skeleton, capture-filled)
  - `modals` — install + register `@kolirt/vue-modal`, scaffold wrappers
  - `stores` — module-reactive shared state (no Pinia, no `defineStore`)
  - `persistence` — localStorage/sessionStorage wrapper discipline
  - `http-request` — shared HTTP wrapper; raw fetch/axios at call sites forbidden
  - `tanstack-query` — queries, mutations, query keys, cache invalidation
  - `auth` — login/logout, gating auth-only data, auto-logout on 401
  - `hydration` — restoring browser-only state after SSR (SSR projects only)
  - `seo` — Vue delivery layer for meta/OG/JSON-LD via `@unhead/vue`; defers
    SEO principles to `knowledge-seo`
  - `robots` — robots.txt delivery via `vite-plugin-robots`; defers policy to
    `knowledge-seo`'s `robots` skill
  - `plugin-registration` — the developer's Vue-plugin registration discipline,
    reused by name from other capability skills

- **planning** — Plan-then-build workflow, container for the two workflow skills.
  - `brainstorm` — interviews the user one question at a time about a task,
    then writes a self-contained plan file under `docs/plans/`
  - `implement` — takes an existing plan (usually from `brainstorm`, often in
    a fresh session) and executes it, either inline or via subagent orchestration

- **auditing** — On-demand audits of a **whole application** from a chosen
  perspective. Strictly read-only: every skill reports findings with evidence and
  names the skill that owns the fix, but never changes the repository itself.
  - `business-analysis` — reconstructs the product model from code and reports
    broken flows, entities without a lifecycle, monetization leaks, and
    contradictions between stated intent and implementation.
  - `seo` — static SEO baseline check across the project. **Requires the
    `knowledge-seo` plugin** (`/plugin install knowledge-seo@claude-skills`),
    which owns all SEO policy knowledge; without it the skill stops instead of
    auditing.

  For audits of a **PR diff** rather than the whole application, use `auditing-prs`.

- **auditing-prs** — End-to-end GitHub Pull Request reviews via the `gh` CLI:
  fetch the PR (plus optional issue-tracker context), draft the review in chat,
  publish inline + summary comments with consistent conventions, and resolve
  threads when fixes land. Works on any repository and any GitHub host. When
  `agent-companion` is enabled, the PR is independently verified by its panel
  before drafting.

- **terse** — Output-style plugin: a `SessionStart` hook injects terse-mode
  rules into every session — answer first, no walls of text, no preamble or
  closers, questions strictly one at a time, one concrete next step, no
  tool-call narration or log dumps. Hook-only: no skills, no state, no
  on/off commands; active from the next session after install.

## Structure

- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) — marketplace manifest; lists every plugin and its version (source of truth)
- [`plugins/agent-companion/`](plugins/agent-companion) — verifier-panel manager plugin
  ([`verify.sh`](plugins/agent-companion/verify.sh) dispatcher · [`MANAGER.md`](plugins/agent-companion/MANAGER.md) · [`adapters/`](plugins/agent-companion/adapters) · [`commands/`](plugins/agent-companion/commands) · [`hooks/`](plugins/agent-companion/hooks) durable-mode reminders)
- [`plugins/knowledge/`](plugins/knowledge) — stack-independent capture-loop base
  ([`skills/capture/`](plugins/knowledge/skills/capture) · shared [`core/`](plugins/knowledge/core))
- [`plugins/knowledge-seo/`](plugins/knowledge-seo) — stack-independent SEO policy knowledge
  ([`skills/`](plugins/knowledge-seo/skills) — 13 skills, one per SEO concern · [`hooks/`](plugins/knowledge-seo/hooks))
- [`plugins/knowledge-vue/`](plugins/knowledge-vue) — one developer's Vue conventions
  ([`skills/vue-work/`](plugins/knowledge-vue/skills/vue-work) router · [`skills/`](plugins/knowledge-vue/skills) — 19 skills total ·
  [`core/`](plugins/knowledge-vue/core) shared docs: [`runtimes/`](plugins/knowledge-vue/core/runtimes) · [`architectures/`](plugins/knowledge-vue/core/architectures) · [`project-types/`](plugins/knowledge-vue/core/project-types) · [`placement.md`](plugins/knowledge-vue/core/placement.md) · [`disciplines/`](plugins/knowledge-vue/core/disciplines) ·
  [`hooks/`](plugins/knowledge-vue/hooks) — `SessionStart` hook)
- [`plugins/planning/`](plugins/planning) — plan-then-build workflow
  ([`skills/brainstorm/`](plugins/planning/skills/brainstorm) · [`skills/implement/`](plugins/planning/skills/implement))
- [`plugins/auditing/`](plugins/auditing) — whole-application audit plugin
  ([`skills/business-analysis/`](plugins/auditing/skills/business-analysis) · [`skills/seo/`](plugins/auditing/skills/seo) · shared [`core/`](plugins/auditing/core))
- [`plugins/auditing-prs/`](plugins/auditing-prs) — GitHub PR review plugin
  ([`skills/audit-pr/`](plugins/auditing-prs/skills/audit-pr) · [`skills/prepush-audit/`](plugins/auditing-prs/skills/prepush-audit) · shared [`core/`](plugins/auditing-prs/core))
- [`plugins/terse/`](plugins/terse) — terse output-style plugin
  ([`hooks/`](plugins/terse/hooks) — `SessionStart` hook, no skills)
- [`.claude/skills/`](.claude/skills) — repo-local maintainer skills (auto-discovered in this repo): [`creating-plugins/`](.claude/skills/creating-plugins) (scaffold/validate new plugins) · [`authoring-knowledge-skills/`](.claude/skills/authoring-knowledge-skills) (checklist for knowledge-* skills)
- [`site/`](site) — Vite + Vue web catalog, data-driven from `marketplace.json`; the catalog page also lists each plugin's skills
- [`build-site.sh`](build-site.sh) — generates `site/public/data.json` from the manifests (version-validated; the generated file is gitignored, not checked into the repo)

## Develop

Create new plugins with the `creating-plugins` skill
(`.claude/skills/creating-plugins/scripts/new-plugin.sh`, `validate.sh`).

### Web catalog (`site/`)

A Vite + Vue + TypeScript app. Its data is generated from `marketplace.json`
by `build-site.sh` into `site/public/data.json` (version-validated).

```bash
cd site
yarn install
yarn dev      # runs build-site.sh, then the dev server at /claude-skills/
yarn build    # type-checks + builds static output to site/dist/ (deploy to GitHub Pages)
```
