#!/usr/bin/env bash
# Verifier adapter: grok CLI → "Composer 2.5 Fast" (Cursor's coding model).
# Same official xAI Grok CLI as grok.sh (one subscription, two models); this is
# the grok-family Composer model. Differs from grok.sh only by the model family.
# auth: grok's own auth (env XAI_API_KEY OR `grok login` / ~/.grok config) — the env
# var is NOT required. The model id is resolved from `grok models` (no hardcoded
# version); that call also doubles as the auth/availability probe → empty means SKIP.
set -uo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"; . "$_d/../lib/grok-model.sh"
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
    # --output-format json: `plain` silently emits nothing on large/complex prompts
    # (grok exits rc=0 but writes 0 bytes -> empty verdict -> false FAIL). json reliably
    # carries the final answer in .text. Extract it; keep grok's stderr flowing to the
    # caller (the dispatcher logs it for diagnosis). Exit code = grok's, not the parser's.
    grok --prompt-file "$prompt" -m "$model" \
      --sandbox read-only --no-auto-update --output-format json \
      | { command -v jq >/dev/null 2>&1 \
            && jq -r '.text // empty' \
            || python3 -c 'import sys,json; print(json.load(sys.stdin).get("text",""))'; } > "$out"
    exit "${PIPESTATUS[0]}";;
  *) echo "usage: grok-composer.sh probe|run" >&2; exit 64;;
esac
