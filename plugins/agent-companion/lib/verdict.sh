#!/usr/bin/env bash
# Shared verdict classification. Sourced by the dispatcher.
# classify_verdict <out-file> <reqid> <mode> -> prints PASS|CHANGES|FAIL
# Anchor on the UNIQUE nonce line ("REQUEST_ID: <reqid>") — unguessable, so it can't
# appear by accident in the verdict body — and require the STATUS to be the line
# immediately ABOVE it. This is robust even if the body quotes "STATUS:" lines.
# Mode-aware + fail-closed: a STATUS that doesn't match the mode is FAIL.
classify_verdict() {
  local out="$1" reqid="$2" mode="$3"
  [ -s "$out" ] || { echo FAIL; return; }
  # Some models (e.g. Grok Build) wrap the required lines in markdown emphasis —
  # `**STATUS: PASS**`, `**STATUS**: PASS`, `**REQUEST_ID**: <nonce>`, `` `...` `` —
  # which an exact whole-line match would reject as FAIL. Normalize every line:
  # delete * and ` anywhere (never part of STATUS/REQUEST_ID content), collapse
  # whitespace runs, and trim leading/trailing spaces or `_`. NOTE: `_` is stripped
  # ONLY at the line edges — never inside — because the literal key REQUEST_ID
  # contains an underscore.
  local norm; norm="$(sed -E 's/[*`]//g; s/[[:space:]]+/ /g; s/^[ _]+//; s/[ _]+$//' "$out")"
  # Anchor on the nonce line that has a STATUS line directly above it. Iterating the
  # matches (instead of blindly taking the last) means an echoed copy of the prompt —
  # which carries the nonce but no STATUS above it — cannot hijack classification.
  local first="" lineno cand
  for lineno in $(printf '%s\n' "$norm" | grep -nFx "REQUEST_ID: ${reqid}" | cut -d: -f1); do
    [ "$lineno" -gt 1 ] || continue
    cand="$(printf '%s\n' "$norm" | sed -n "$((lineno - 1))p")"
    case "$cand" in "STATUS: "*) first="$cand"; break;; esac
  done
  [ -n "$first" ] || { echo FAIL; return; }
  case "$mode" in
    review)
      case "$first" in
        "STATUS: PASS") echo PASS;;
        "STATUS: CHANGES_REQUESTED") echo CHANGES;;
        *) echo FAIL;;
      esac;;
    consult)  [ "$first" = "STATUS: ADVICE" ]           && echo PASS || echo FAIL;;
    audit)    [ "$first" = "STATUS: AUDIT_COMPLETE" ]   && echo PASS || echo FAIL;;
    diagnose) [ "$first" = "STATUS: DIAGNOSIS_COMPLETE" ] && echo PASS || echo FAIL;;
    research) [ "$first" = "STATUS: RESEARCH_COMPLETE" ]  && echo PASS || echo FAIL;;
    *) echo FAIL;;   # unknown mode -> fail-closed
  esac
}
