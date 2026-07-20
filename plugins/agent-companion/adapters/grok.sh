#!/usr/bin/env bash
# Verifier adapter: grok CLI → xAI's frontier reasoning model (whatever it is today:
# grok-build → grok-4 → grok-4.5 …). resolve_frontier picks it by exclusion — the
# default non-composer model — so an xAI rebrand does NOT silently make this "unavailable".
# Official xAI Grok CLI (install: curl -fsSL https://x.ai/cli/install.sh | bash).
# headless: `grok -p "<prompt>" -m <model> --sandbox read-only` (single-turn);
# read-only sandbox = the verifier can read the diff/repo but physically cannot write.
# auth: grok's own auth (env XAI_API_KEY OR `grok login` / ~/.grok config) — we do NOT
# require the env var, since `grok login` config works headless too. When no model is
# pinned, the id is resolved from `grok models` (no hardcoded version); that call also
# doubles as the auth/availability probe — if grok isn't usable it returns nothing → SKIP.
# model+effort are optional (4th arg model, 2nd arg effort): a pinned model must exist in
# `grok models` or the agent SKIPs; effort maps to grok's `--reasoning-effort`.
set -uo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
. "$_d/../lib/grok-model.sh"; . "$_d/../lib/grok-run.sh"
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v grok >/dev/null 2>&1 || exit 64
    model="${1:-}"
    if [ -n "$model" ]; then
      # An explicitly pinned model must actually be offered by this grok — do NOT gate it
      # on resolve_frontier (a valid non-frontier pin would otherwise read as unavailable).
      # `grok models` succeeds only if grok is installed AND authenticated by ANY method →
      # empty result means skip. Tokenise the listing (same split as lib/grok-model.sh), keep
      # only real grok-* model IDs, and match EXACTLY — a substring grep would let `grok-4`
      # pass when only `grok-4.5` exists, and an untyped token match would let `grok:default`
      # pass on `(default)`.
      list="$(grok models 2>/dev/null)" || true
      [ -n "$list" ] || exit 64
      # The tokenising pipeline's own status is captured and discarded; only the final exact
      # match decides. Ending a status-significant pipeline in `grep -q` would let the early
      # exit SIGPIPE `tr`/`grep -iE`, and `pipefail` would report 141 — skipping this verifier
      # although the pinned model IS present. The match therefore runs off a herestring.
      toks="$(printf '%s\n' "$list" | tr -s ' \t,|"[]{}:()' '\n' \
        | grep -iE '^grok-[a-z0-9._-]+$')" || true
      grep -qxF -- "$model" <<<"$toks" || exit 64
      exit 0
    fi
    # Bare probe: resolve_frontier already runs `grok models` once — don't fetch it twice.
    [ -n "$(resolve_frontier)" ] || exit 64
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:-}"; out="${3:?}"; model="${4:-}"
    : "${effort:=}"
    [ -n "$model" ] || model="$(resolve_frontier)"   # unpinned → track the frontier
    [ -n "$model" ] || exit 64
    # Runs grok, extracts .text, keeps the full JSON, and retries once on a verdict
    # with no STATUS line (grok aborts its agentic loop non-deterministically —
    # see lib/grok-run.sh). Exit code = grok's, not the parser's.
    grok_run "$model" "$prompt" "$out" "$effort"
    exit "$?";;
  *) echo "usage: grok.sh probe|run" >&2; exit 64;;
esac
