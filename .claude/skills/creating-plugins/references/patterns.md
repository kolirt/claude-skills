# Plugin patterns & pitfalls

General rules for building robust plugins (and for porting an existing slash
command / shell tool into one). Phrased independently of any specific plugin.

## 1. Bundle scripts; reference them via `${CLAUDE_PLUGIN_ROOT}`

Ship helper scripts and read-only docs inside the plugin. A command body runs and
reads them via the env var — never via an absolute home path:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/<script>.sh" "$arg1" "$arg2"
```

Gate this on the availability check in `env-vars.md`.

## 2. Persist runtime state in `${CLAUDE_PLUGIN_DATA}`, not the plugin dir

Anything the plugin writes at runtime (caches, generated files, scratch state)
goes to persistent storage:

```bash
STATE="${CLAUDE_PLUGIN_DATA}/<subdir>"
mkdir -p "$STATE"
```

`${CLAUDE_PLUGIN_ROOT}` is wiped on update — writing state there loses it (or
leaves stale executables behind on the next version).

## 3. Do NOT `cd` into the plugin directory before git (or cwd-sensitive) ops

A tool that inspects the **user's** project (e.g. `git rev-parse --show-toplevel`,
relative paths) must run from the caller's working directory. If a command wrapper
`cd`s into `${CLAUDE_PLUGIN_ROOT}` first, it will operate on the plugin cache
instead of the user's project. Invoke bundled scripts **without changing cwd**.

## 4. Degrade gracefully on an optional external dependency

If a plugin shells out to an external CLI that install cannot guarantee is present
or authenticated:

- detect it first (`command -v <cli>` + a quick auth probe);
- if missing/unauthenticated, keep the primary behaviour working and print a clear
  "X unavailable, skipping" notice;
- never hard-fail the whole command on a missing optional dependency.

## 5. Don't ship a bespoke self-updater

The plugin lifecycle owns updates (`/plugin update`, driven by `version`). Do not
build a custom version-check/updater into a plugin — just keep `plugin.json`
`version` accurate and bump it per release.

## 6. Pluggable backends + parallel fan-out (for multi-target tools)

When a tool can talk to several interchangeable external backends, make each
backend an **adapter**, not a separate plugin/skill:

- `adapters/<name>.sh` exposes one uniform call, e.g. `run <input> <opts> <out>`.
- a config file lists the active adapters (ship a default; allow a user override
  under `${CLAUDE_PLUGIN_DATA}`).
- the dispatcher fans out adapters **in parallel**, each writing to its own output
  file, then `wait`s and aggregates:
  ```bash
  for a in $(active); do ( "adapters/$a.sh" run "$input" "$opts" "$RUN/$a.out" ) & done
  wait
  aggregate "$RUN"/*.out      # define the policy, e.g. for gating: any failure blocks
  ```
- each adapter has its own timeout and degrades gracefully (a missing backend is
  skipped with a notice; the others still run).
- keep the REQUIRED surface minimal (e.g. `probe` + `run`) and make anything else
  **optional**: the dispatcher tries the subcommand, and an adapter that does not
  implement it just exits non-zero and gets the fallback path. agent-companion's
  `models` (list the backend's selectable models) works this way — adapters that can
  enumerate get input validated against the real list, adapters that cannot are
  unchanged and store what the user typed.
- resolve anything that needs the backend itself (model names, capabilities) **once,
  at configure time**, not on every dispatch — otherwise every run inherits that
  call's latency and its output-format stability.

Adding a backend = a new adapter file + one config entry. No dispatcher change.

## 7. Writable-state hygiene

State under `${CLAUDE_PLUGIN_DATA}` accumulates and may contain fragments of the
user's data (possibly secrets). Garbage-collect old entries (e.g. delete dirs
older than 1 day) and keep them out of any logs.
