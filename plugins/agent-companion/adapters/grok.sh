#!/usr/bin/env bash
# Verifier adapter: grok CLI → "Grok Build" model (xAI's coding model).
# Official xAI Grok CLI (install: curl -fsSL https://x.ai/cli/install.sh | bash);
# a sibling adapter grok-composer.sh drives the same CLI with the Composer model.
# headless: `grok -p "<prompt>" -m <model> --sandbox read-only` (single-turn);
# read-only sandbox = the verifier can read the diff/repo but physically cannot write.
# auth: XAI_API_KEY for headless use. The model id is resolved from `grok models`
# (no hardcoded version); if no grok-build model is available the agent is SKIPPED.
set -uo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"; . "$_d/../lib/grok-model.sh"
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v grok >/dev/null 2>&1 || exit 64
    [ -n "${XAI_API_KEY:-}" ] || exit 64
    [ -n "$(resolve_model grok-build)" ] || exit 64   # no build model → skip (not fail)
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:-}"; out="${3:?}"
    : "${effort:=}"  # no confirmed CLI flag for the /model effort arg; ignored.
    model="$(resolve_model grok-build)"
    [ -n "$model" ] || exit 64
    grok --prompt-file "$prompt" -m "$model" \
      --sandbox read-only --no-auto-update --output-format plain > "$out" 2>/dev/null
    exit $?;;
  *) echo "usage: grok.sh probe|run" >&2; exit 64;;
esac
