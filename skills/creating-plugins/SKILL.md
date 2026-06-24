---
name: creating-plugins
description: Use when authoring a new Claude Code plugin for this marketplace, adding a plugin to marketplace.json, or porting an existing tool/skill into a native plugin. Covers plugin.json/marketplace.json schemas, CLAUDE_PLUGIN_ROOT/DATA, the install/update flow, and battle-tested porting patterns.
---

# Creating Claude Code Plugins

How to author a native Claude Code plugin and publish it through this marketplace
(`.claude-plugin/marketplace.json`). This skill codifies the schemas and the
patterns learned porting real tools into plugins.

## When to use

- Creating a new plugin in `plugins/<name>/`.
- Registering a plugin in the marketplace `marketplace.json`.
- Porting an existing slash command / skill / shell tool into a plugin.

## Prerequisites

- `python3` (used by the helper scripts to edit/validate JSON without `jq`).

## Workflow

Create one todo per step and do them in order.

1. **Decide what the plugin contains.** A plugin may bundle any of:
   commands (`commands/<cmd>.md`), skills (`skills/<name>/SKILL.md`),
   agents (`agents/`), hooks (`hooks/`), MCP servers (`.mcp.json`),
   bundled scripts (`scripts/`). Keep one clear responsibility per plugin.
2. **Scaffold it.** Run `scripts/new-plugin.sh <name>`. This creates
   `plugins/<name>/.claude-plugin/plugin.json`, a `commands/<name>.md`
   starter, and registers the plugin in `marketplace.json`.
3. **Fill `plugin.json`.** Set `description`, `author`, and a real `version`.
   See `references/plugin-json.md`.
4. **Add components.** Write the command/skill/hook bodies. If a component
   must run a bundled script or read a bundled file, reference it via
   `${CLAUDE_PLUGIN_ROOT}` and store mutable state under `${CLAUDE_PLUGIN_DATA}`
   — see `references/env-vars.md` and `references/patterns.md`.
5. **Confirm the marketplace entry.** Ensure the `marketplace.json` entry's
   `source` points at `./plugins/<name>` and its `version` mirrors
   `plugin.json`. See `references/marketplace-json.md`.
6. **Bump the version.** Updates are detected from `plugin.json` `version`
   (or git SHA if omitted). Bump it on every published change.
7. **Validate.** Run `scripts/validate.sh`. It checks required fields,
   that each `source` path exists, and that every `marketplace.json` version
   matches the plugin's own `plugin.json` version.
8. **Test the install.** From a clean checkout:
   `/plugin marketplace add <owner>/<repo>` then
   `/plugin install <name>@<marketplace-name>`; verify the component loads.
   See `references/install-update-flow.md`.

## References

- `references/plugin-json.md` — `.claude-plugin/plugin.json` schema.
- `references/marketplace-json.md` — `marketplace.json` schema + same-repo sources.
- `references/env-vars.md` — `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA` semantics and availability caveats.
- `references/install-update-flow.md` — add / install / update lifecycle.
- `references/patterns.md` — general plugin patterns and pitfalls.

## Anti-patterns

- **Guessing the plugin cache path** (`~/.claude/plugins/.../<name>`). It is
  ephemeral and multiple versions may coexist during an update. Use
  `${CLAUDE_PLUGIN_ROOT}` instead.
- **Writing mutable state into `${CLAUDE_PLUGIN_ROOT}`.** It is wiped on update.
  Persist under `${CLAUDE_PLUGIN_DATA}`.
- **`cd`-ing into the plugin directory before git operations.** A tool that
  inspects the *user's* repo must run from the user's cwd, not the plugin dir.
- **Hard-failing on an optional external CLI.** Degrade gracefully and tell the
  user what is unavailable.
- **Emoji as structural icons** in any bundled UI; use SVG.
- **Forgetting to bump `version`** — users then never receive the update.
