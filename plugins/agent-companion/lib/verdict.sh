#!/usr/bin/env bash
# Shared verdict classification. Sourced by the dispatcher.
# classify_verdict <out-file> <reqid> <mode> -> prints PASS|CHANGES|FAIL
# Mode-aware: in review only "STATUS: PASS" is a PASS; a verdict whose STATUS
# does not match the mode is FAIL (fail-closed). The REQUEST_ID nonce must be the
# line immediately after the last STATUS line.
classify_verdict() {
  local out="$1" reqid="$2" mode="$3"
  [ -s "$out" ] || { echo FAIL; return; }
  local start; start="$(grep -n '^STATUS: ' "$out" | tail -1 | cut -d: -f1)"
  [ -n "$start" ] || { echo FAIL; return; }
  local first second
  first="$(sed -n "${start}p" "$out")"
  second="$(sed -n "$((start+1))p" "$out")"
  [ "$second" = "REQUEST_ID: ${reqid}" ] || { echo FAIL; return; }
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
