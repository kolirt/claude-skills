#!/usr/bin/env bash
# Shared run logic for the grok CLI adapter (grok.sh).
#
# The grok CLI is an agentic loop: it narrates ("Reviewing the diff…") between tool
# calls, and `--output-format json` concatenates that narration AND the final answer
# into one `.text`. When the loop ends early (a failed tool call, or the model simply
# stopping), `.text` carries narration only — no STATUS line — while grok still exits
# rc=0 with stopReason EndTurn and an empty stderr. classify_verdict is fail-closed,
# so such an abort is indistinguishable from a substantive verdict. Hence:
#   1. the full JSON is kept beside the verdict (raw.json / raw.retry.json) —
#      stopReason/num_turns/thought are the only evidence that a run aborted early;
#   2. a verdict with no STATUS line is retried ONCE — grok is non-deterministic, and
#      the identical prompt usually yields a complete verdict on the second attempt.
# (`--output-format plain` is not an option: it silently emits 0 bytes on large prompts.)

# grok_extract_text <raw-json>  -> prints .text (empty if absent/unparseable)
grok_extract_text() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.text // empty' "$1" 2>/dev/null
  else
    python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("text") or "",end="")' "$1" 2>/dev/null
  fi
}

# grok_has_status <verdict-file>  -> 0 if any line is a STATUS line. Tolerates the
# markdown emphasis grok-build wraps it in (`**STATUS: PASS**`), exactly as the
# dispatcher's classifier does — this must not reject a verdict the dispatcher accepts.
grok_has_status() {
  # Normalised first, matched second: with `sed | grep -q`, a STATUS line early in a long
  # verdict lets grep exit while sed is still writing, sed dies of SIGPIPE, and under the
  # caller's `pipefail` this function would report "no STATUS" for a verdict that has one —
  # costing a pointless retry of a completed run.
  local norm
  norm="$(sed -E 's/[*`]//g; s/^[[:space:]_]+//' "$1" 2>/dev/null)" || true
  grep -q '^STATUS:' <<<"$norm"
}

# grok_run <model> <prompt-file> <out-file> [effort]  -> exit code of grok itself
grok_run() {
  local model="$1" prompt="$2" out="$3" effort="${4:-}"
  local dir attempt raw rc
  dir="$(dirname "$out")"

  for attempt in 1 2; do
    raw="$dir/raw.json"; [ "$attempt" = 1 ] || raw="$dir/raw.retry.json"

    # effort (optional) → grok's --reasoning-effort; a validated tier has no spaces, so the
    # unquoted ${effort:+…} splits into exactly two argv words. Omitted when empty.
    # --always-approve: headless has nobody to answer a permission prompt, and grok resolves
    # an unanswered one by CANCELLING the whole turn (stopReason=Cancelled, rc=0, narration-only
    # .text → fail-closed FAIL). Any shell command its analyzer won't auto-whitelist (e.g. a
    # chained `cd … && python3 script.py; …`) triggers this. Targeted --allow rules do NOT
    # unblock it (tested: Bash(*), tool-level — still Cancelled); only --always-approve does.
    # Safe here: --sandbox read-only is OS-enforced (seatbelt) — writes and network stay blocked.
    # --no-plan: plan mode ends in a wait-for-approval that headless can never answer — the same
    # abort class as unapproved commands. Inactive today (config has permission_mode="ask"), but
    # the adapter must not depend on the user's ~/.grok/config.toml staying that way.
    grok --prompt-file "$prompt" -m "$model" \
      ${effort:+--reasoning-effort "$effort"} \
      --sandbox read-only --always-approve --no-plan --no-auto-update --output-format json > "$raw"
    rc=$?

    grok_extract_text "$raw" > "$out"
    [ "$rc" = 0 ] || return "$rc"          # a real CLI failure — do not paper over it
    grok_has_status "$out" && return 0

    # No STATUS: the loop ended before the verdict block. Report what the JSON knows.
    echo "grok($model) attempt $attempt: no STATUS line in .text ($(wc -c <"$out" | tr -d ' ') bytes$(
      command -v jq >/dev/null 2>&1 && jq -r '", stopReason=\(.stopReason // "?"), turns=\(.num_turns // "?")"' "$raw" 2>/dev/null
    )); raw JSON kept at $raw" >&2
  done

  return 0   # retry exhausted — the empty/narration-only verdict fails closed downstream
}
