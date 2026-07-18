# Claude Skills Marketplace

Native Claude Code plugin marketplace.

## Install

```text
/plugin marketplace add kolirt/claude-skills
/plugin install agent-companion@claude-skills
/plugin install auditing@claude-skills
/plugin install auditing-prs@claude-skills
```

## Plugins

- **agent-companion** — Claude runs as manager and consults several independent
  verifier agents in parallel; REVIEW is any-blocks. **No agents are active by
  default** — enable the ones you want with `/agent-companion:verifiers add <name>`.
  Available adapters (each needs its own CLI installed and authenticated by ANY
  method that CLI supports — browser/OAuth login, config file, or API key; an
  unauthenticated CLI is skipped, not required to use a specific key):
  - `codex` — OpenAI Codex CLI
  - `gemini` — Google Gemini CLI
  - `grok` — Grok CLI · xAI's frontier model (whatever xAI ships today)

  An entry is `cli[:model][@effort]`: pin a specific model and/or reasoning effort
  per verifier — e.g. `codex:gpt-5.6-sol@high` or `grok@high`. Omit `:model` for the
  CLI's own frontier default; omit `@effort` for the dispatch effort. Effort is one of
  low|medium|high|xhigh|max and is honored by codex and grok (gemini has no effort knob).
  Entries match **exactly**, so `codex` and `codex:gpt-5.5@high` can coexist.

  Add a new agent by dropping an adapter in `plugins/agent-companion/adapters/`
  and listing it. See `.claude/skills/creating-plugins`.

  When 2+ verifiers run, a **synthesizer** can consolidate their reports into one (so the
  session isn't flooded): `/agent-companion:synthesizer set <claude|cli[:model][@effort]|none>`.

  **Durable manager mode.** Plugin hooks persist the on/off state per session, so the
  protocol survives compaction and is re-injected on resume, with a throttled reminder
  in long sessions. `/clear` turns the mode off (enable it again with
  `/agent-companion:on`). Hooks are best-effort — `disableAllHooks` leaves the
  pre-0.2.0 behaviour.

  **Skill-aware panel.** The manager lists the project's convention skills under a
  `SKILL_FILES:` block in the request (`.md` paths only); `verify.sh` splices their
  content straight into each verifier's prompt, so the conventions reach the panel
  without ever entering the main session's context.

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

## Structure

- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) — marketplace manifest; lists every plugin and its version (source of truth)
- [`plugins/agent-companion/`](plugins/agent-companion) — verifier-panel manager plugin
  ([`verify.sh`](plugins/agent-companion/verify.sh) dispatcher · [`MANAGER.md`](plugins/agent-companion/MANAGER.md) · [`adapters/`](plugins/agent-companion/adapters) · [`commands/`](plugins/agent-companion/commands) · [`hooks/`](plugins/agent-companion/hooks) durable-mode reminders)
- [`plugins/auditing/`](plugins/auditing) — whole-application audit plugin
  ([`skills/business-analysis/`](plugins/auditing/skills/business-analysis) · [`skills/seo/`](plugins/auditing/skills/seo) · shared [`core/`](plugins/auditing/core))
- [`plugins/auditing-prs/`](plugins/auditing-prs) — GitHub PR review plugin
  ([`skills/audit-pr/`](plugins/auditing-prs/skills/audit-pr) · [`skills/prepush-audit/`](plugins/auditing-prs/skills/prepush-audit) · shared [`core/`](plugins/auditing-prs/core))
- [`.claude/skills/`](.claude/skills) — repo-local maintainer skills (auto-discovered in this repo): [`creating-plugins/`](.claude/skills/creating-plugins) (scaffold/validate new plugins) · [`authoring-knowledge-skills/`](.claude/skills/authoring-knowledge-skills) (checklist for knowledge-* skills)
- [`site/`](site) — Vite + Vue web catalog, data-driven from `marketplace.json`
- [`build-site.sh`](build-site.sh) — generates `site/public/data.json` from the manifests (version-validated; the generated file is gitignored)

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
