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
  local rl; rl="$(grep -nFx "REQUEST_ID: ${reqid}" "$out" | tail -1 | cut -d: -f1)"
  [ -n "$rl" ] && [ "$rl" -gt 1 ] || { echo FAIL; return; }
  local first; first="$(sed -n "$((rl - 1))p" "$out")"
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
    *) echo FAIL;;   # unknown mode -> fail-closed
  esac
}
