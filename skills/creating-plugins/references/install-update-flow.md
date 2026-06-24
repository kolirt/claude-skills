# Install / update lifecycle

## User-facing commands

```text
/plugin marketplace add <owner>/<repo>      # register this marketplace (e.g. kolirt/claude-skills)
/plugin install <plugin>@<marketplace>      # e.g. /plugin install example-plugin@claude-skills
/plugin                                     # browse/menu installed + available
/plugin update                              # pull updates for installed plugins
/plugin uninstall <plugin>@<marketplace>
```

- `<marketplace>` is the `name` from `marketplace.json` (here: `claude-skills`).
- `<plugin>` is the plugin `name`.

## How updates are detected

`/plugin update` compares the installed version to the source version. Version
resolution order:

1. `plugin.json` `version`
2. marketplace entry `version`
3. git commit SHA (git-hosted sources, when no explicit version)
4. `unknown` (non-git sources)

Practically: with an explicit `version` string, users get an update only when you
**bump it**. Without a version, every new commit is treated as an update.

## Where installed plugins live

Copied into the plugin cache under `~/.claude/plugins/`; persistent per-plugin
state is at `~/.claude/plugins/data/{id}/` (`${CLAUDE_PLUGIN_DATA}`). Never depend
on the exact cache path — use the env vars (`env-vars.md`).

## Publishing checklist

1. Bump `plugin.json` `version` (and mirror it in `marketplace.json`).
2. `scripts/validate.sh` passes.
3. Commit & push.
4. Existing users run `/plugin update`; new users `/plugin install`.
