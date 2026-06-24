#!/usr/bin/env bash
# Verifier adapter: grok CLI → "Grok Build" model (xAI's coding model).
# Official xAI Grok CLI (install: curl -fsSL https://x.ai/cli/install.sh | bash);
# a sibling adapter grok-composer.sh drives the same CLI with the Composer model.
# headless: `grok -p "<prompt>" -m <model> --sandbox read-only` (single-turn);
# read-only sandbox = the verifier can read the diff/repo but physically cannot write.
# auth: grok's own auth (env XAI_API_KEY OR `grok login` / ~/.grok config) — we do NOT
# require the env var, since `grok login` config works headless too. The model id is
# resolved from `grok models` (no hardcoded version); that call also doubles as the
# auth/availability probe — if grok isn't usable it returns nothing → agent SKIPPED.
set -uo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"; . "$_d/../lib/grok-model.sh"
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v grok >/dev/null 2>&1 || exit 64
    # `grok models` (inside resolve_model) succeeds only if grok is installed AND
    # authenticated by ANY method → empty result means skip (graceful), not fail.
    [ -n "$(resolve_model grok-build)" ] || exit 64
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:-}"; out="${3:?}"
    : "${effort:=}"  # no confirmed CLI flag for the /model effort arg; ignored.
    model="$(resolve_model grok-build)"
    [ -n "$model" ] || exit 64
    # stdout = verdict; stderr left to the caller (dispatcher logs it for diagnosis).
    grok --prompt-file "$prompt" -m "$model" \
      --sandbox read-only --no-auto-update --output-format plain > "$out"
    exit $?;;
  *) echo "usage: grok.sh probe|run" >&2; exit 64;;
esac
