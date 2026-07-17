#!/usr/bin/env bash
set -uo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v codex >/dev/null 2>&1 || exit 64
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:?}"; out="${3:?}"; model="${4:-}"
    # read-only sandbox (no approvals possible) + no persisted session/state.
    # NOTE: `codex exec` does NOT accept --ask-for-approval (interactive-only flag);
    # passing it makes exec fail with rc=2. read-only sandbox already blocks writes.
    # stdout is discarded; stderr is left to the caller (the dispatcher logs it).
    # model is optional (4th arg): absent → codex's own default (its current frontier);
    # a bad model id surfaces as a codex error → non-zero rc → verdict FAIL (visible).
    if [ -n "$model" ]; then
      codex exec --sandbox read-only --ephemeral --skip-git-repo-check \
        -m "$model" -c model_reasoning_effort="$effort" -o "$out" - < "$prompt" >/dev/null
    else
      codex exec --sandbox read-only --ephemeral --skip-git-repo-check \
        -c model_reasoning_effort="$effort" -o "$out" - < "$prompt" >/dev/null
    fi
    exit $?;;
  *) echo "usage: codex.sh probe|run" >&2; exit 64;;
esac
