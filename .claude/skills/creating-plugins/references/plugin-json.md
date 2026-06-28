# `.claude-plugin/plugin.json`

The plugin manifest. Lives at `plugins/<name>/.claude-plugin/plugin.json`.

## Minimal

```json
{
  "name": "example-plugin",
  "version": "0.1.0",
  "description": "One-line description of what the plugin does.",
  "author": { "name": "kolirt" }
}
```

## Fields

| Field | Required | Notes |
|-------|----------|-------|
| `name` | yes | Plugin id; matches the directory name and the marketplace entry `name`. |
| `version` | **required (this marketplace's policy)** | Single source of truth for updates; `marketplace.json` must mirror it and `validate.sh` enforces presence + match. (Claude Code itself allows omitting it — then it falls back to the git SHA — but this marketplace requires an explicit semver-style string for controlled, mirrored releases.) |
| `description` | yes | One line shown in `/plugin` listings. |
| `author` | yes | `{ "name" }`. |
| `dependencies` | no | **Array** of plugin names this plugin requires (e.g. `["knowledge"]`). Enabling the plugin auto-installs them (Claude Code ≥ v2.1.110). MUST be an array — the schema rejects an npm-style object map like `{ "knowledge": ">=0.1.0" }` (error: `expected array, received object`). A bare string tracks the latest in the same marketplace; the object form `{ "name", "version" }` requires the upstream plugin to be git-tagged `<name>--v<version>`. Under-documented upstream but live. |

## Layout a plugin may contain

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json
├── commands/<cmd>.md      # slash commands
├── skills/<skill>/SKILL.md
├── agents/                # subagents
├── hooks/                 # lifecycle hooks
├── scripts/               # bundled shell/scripts
└── .mcp.json              # MCP server config
```

Only include the directories the plugin actually uses.

## Version is the update key

`/plugin update` compares the installed version against the source. Resolution
order: `plugin.json` `version` → marketplace entry `version` → git SHA →
`unknown`. **Bump `version` on every published change**, or installed users will
not see the update.
