# Plugin environment variables

Two variables expose where a plugin's files live.

| Variable | Points to | Lifetime |
|----------|-----------|----------|
| `CLAUDE_PLUGIN_ROOT` | Absolute path to the installed plugin directory (the copy in the plugin cache). | **Ephemeral** — changes on every update; the previous version's directory is garbage-collected ~7 days later. Treat as read-only bundled assets. |
| `CLAUDE_PLUGIN_DATA` | `~/.claude/plugins/data/{id}/` (id = plugin identifier, non-alphanumerics → `-`). | **Persistent** across updates and reinstalls; removed when the plugin is fully uninstalled. Put mutable state here. |

## Usage

- **Read bundled files** (scripts, docs, templates) from `${CLAUDE_PLUGIN_ROOT}`:
  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/verify.sh" ...
  cat  "${CLAUDE_PLUGIN_ROOT}/MANAGER.md"
  ```
- **Write state** (caches, handoff files, generated artifacts) under
  `${CLAUDE_PLUGIN_DATA}`:
  ```bash
  mkdir -p "${CLAUDE_PLUGIN_DATA}/handoff"
  ```

## Availability caveat (verify before relying on it)

The docs explicitly export these variables to **hook processes** and to
**MCP / LSP server subprocesses**. They are **not clearly documented as present**
in the shell environment when a plugin's **slash command** triggers a `Bash`
call.

Before building a command that depends on `${CLAUDE_PLUGIN_ROOT}` in Bash,
**confirm it empirically** (a one-line `echo "${CLAUDE_PLUGIN_ROOT:-UNSET}"`
from the command). Decision:

1. **Available in command Bash** → simplest design: the command runs
   `bash "${CLAUDE_PLUGIN_ROOT}/<script>"` directly.
2. **Not available** → provide the behaviour through a path where the vars ARE
   documented: a bundled **MCP tool** or a **hook**, invoked from behind the
   slash command. Do NOT fall back to guessing the cache path.

See `patterns.md` for the bundled-script and graceful-degrade patterns.
