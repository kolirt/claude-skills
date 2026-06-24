#!/usr/bin/env bash
set -uo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v codex >/dev/null 2>&1 || exit 64
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:?}"; out="${3:?}"
    # read-only sandbox + never block on approval + no persisted session/state.
    # ($out lives under CLAUDE_PLUGIN_DATA, outside the repo, so -o can write it.)
    codex exec --sandbox read-only --ask-for-approval never --ephemeral --skip-git-repo-check \
      -c model_reasoning_effort="$effort" -o "$out" - < "$prompt" >/dev/null 2>&1
    exit $?;;
  *) echo "usage: codex.sh probe|run" >&2; exit 64;;
esac
