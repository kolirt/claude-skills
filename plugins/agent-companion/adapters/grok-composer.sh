#!/usr/bin/env bash
# Verifier adapter: grok CLI → "Composer 2.5 Fast" (Cursor's coding model).
# Same official xAI Grok CLI as grok.sh (one subscription, two models); this is
# the grok-family Composer model. Differs from grok.sh only by the model family.
# auth: grok's own auth (env XAI_API_KEY OR `grok login` / ~/.grok config) — the env
# var is NOT required. The model id is resolved from `grok models` (no hardcoded
# version); that call also doubles as the auth/availability probe → empty means SKIP.
set -uo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$_d/../lib/grok-model.sh"; . "$_d/../lib/grok-run.sh"
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v grok >/dev/null 2>&1 || exit 64
    [ -n "$(resolve_model grok-composer)" ] || exit 64   # usable+authed grok or skip
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:-}"; out="${3:?}"
    : "${effort:=}"
    model="$(resolve_model grok-composer)"
    [ -n "$model" ] || exit 64
    # Runs grok, extracts .text, keeps the full JSON, and retries once on a verdict
    # with no STATUS line (grok aborts its agentic loop non-deterministically —
    # see lib/grok-run.sh). Exit code = grok's, not the parser's.
    grok_run "$model" "$prompt" "$out"
    exit "$?";;
  *) echo "usage: grok-composer.sh probe|run" >&2; exit 64;;
esac
