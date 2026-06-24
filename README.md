# Claude Skills Marketplace

Native Claude Code plugin marketplace.

## Install

```text
/plugin marketplace add kolirt/claude-skills
/plugin install agent-companion@claude-skills
```

## Plugins

- **agent-companion** — Claude acts as manager and consults several independent
  verifier agents in parallel; REVIEW is any-blocks. **No agents are active by
  default** — enable the ones you want with `/agent-companion:verifiers add <name>`.
  Available adapters (each needs its own CLI installed + auth):
  - `codex` — OpenAI Codex CLI
  - `gemini` — Google Gemini CLI (`GEMINI_API_KEY`)
  - `grok` — Grok CLI · **Grok Build** model, xAI (`XAI_API_KEY`)
  - `grok-composer` — Grok CLI · **Composer 2.5 Fast** model, Cursor (same CLI/subscription, `XAI_API_KEY`)

  Add a new agent by dropping an adapter in `plugins/agent-companion/adapters/`
  and listing it. See `skills/creating-plugins`.

  When 2+ verifiers run, a **synthesizer** can consolidate their reports into one
  (so the session isn't flooded): `/agent-companion:synthesizer set <claude|adapter|none>`.

## Develop

Create new plugins with the `creating-plugins` skill
(`skills/creating-plugins/scripts/new-plugin.sh`, `validate.sh`).

### Web catalog (`site/`)

A Vite + Vue + TypeScript app. Its data is generated from `marketplace.json`
by `build-site.sh` into `site/public/data.json` (version-validated).

```bash
cd site
yarn install
yarn dev      # runs build-site.sh, then the dev server at /claude-skills/
yarn build    # type-checks + builds static output to site/dist/ (deploy to GitHub Pages)
```
