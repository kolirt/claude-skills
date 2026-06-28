# Claude Skills Marketplace

Native Claude Code plugin marketplace.

## Install

```text
/plugin marketplace add kolirt/claude-skills
/plugin install agent-companion@claude-skills
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
  - `grok` — Grok CLI · **Grok Build** model (xAI)
  - `grok-composer` — Grok CLI · **Composer 2.5 Fast** model (Cursor); same Grok CLI/subscription

  Add a new agent by dropping an adapter in `plugins/agent-companion/adapters/`
  and listing it. See `.claude/skills/creating-plugins`.

  When 2+ verifiers run, a **synthesizer** can consolidate their reports into one
  (so the session isn't flooded): `/agent-companion:synthesizer set <claude|adapter|none>`.

- **auditing-prs** — End-to-end GitHub Pull Request reviews via the `gh` CLI:
  fetch the PR (plus optional issue-tracker context), draft the review in chat,
  publish inline + summary comments with consistent conventions, and resolve
  threads when fixes land. Works on any repository and any GitHub host. When
  `agent-companion` is enabled, the PR is independently verified by its panel
  before drafting.

## Structure

- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) — marketplace manifest; lists every plugin and its version (source of truth)
- [`plugins/agent-companion/`](plugins/agent-companion) — verifier-panel manager plugin
  ([`verify.sh`](plugins/agent-companion/verify.sh) dispatcher · [`MANAGER.md`](plugins/agent-companion/MANAGER.md) · [`adapters/`](plugins/agent-companion/adapters) · [`commands/`](plugins/agent-companion/commands))
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
