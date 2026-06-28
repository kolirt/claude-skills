# `.claude-plugin/marketplace.json`

The marketplace index at the repo root: `.claude-plugin/marketplace.json`. Lists
the plugins this repo offers.

## Minimal (one plugin, same repo)

```json
{
  "name": "claude-skills",
  "owner": { "name": "kolirt" },
  "plugins": [
    {
      "name": "example-plugin",
      "source": "./plugins/example-plugin",
      "description": "One-line description of what the plugin does.",
      "version": "0.1.0"
    }
  ]
}
```

## Fields

| Field | Required | Notes |
|-------|----------|-------|
| `name` | yes | Marketplace id. Users reference it as `<plugin>@<marketplace-name>`. |
| `owner` | yes | `{ "name" }`. |
| `plugins[]` | yes | One entry per offered plugin. |
| `plugins[].name` | yes | Must equal the plugin's `plugin.json` `name`. |
| `plugins[].source` | yes | For a plugin living in THIS repo, a relative path: `./plugins/<name>`. (Other source types exist — git/url/npm — but same-repo relative paths are what this marketplace uses.) |
| `plugins[].description` | yes | Shown in listings. |
| `plugins[].version` | **required** | Mirror of the plugin's `plugin.json` version. Must be present and equal (`validate.sh` enforces presence + match). |

## Rules

- Every `source` path must exist and contain a valid `.claude-plugin/plugin.json`.
- Keep `marketplace.json` `version` and the plugin's `plugin.json` `version` in
  sync — they are two views of one source of truth (the plugin's own version).
