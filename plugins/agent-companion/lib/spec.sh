#!/usr/bin/env bash
# Parse a panel entry (verifier OR synthesizer) of the form:  cli[:model][@effort]
#
#   cli      adapter basename (required)   — resolves to adapters/<cli>.sh
#   :model   optional model id passed to the CLI (empty/omitted → adapter default:
#            codex/gemini use their own frontier default; grok uses resolve_frontier)
#   @effort  optional per-entry reasoning effort (empty/omitted → the dispatch effort)
#
# Extraction order (deterministic, first-delimiter wins):
#   1. effort  = everything after the FIRST '@'  (model ids never contain '@')
#   2. head    = everything before that '@'
#   3. adapter = head up to the FIRST ':'; model = the remainder (may be empty)
# A trailing empty field normalises to "absent": `codex:` and `codex@` == bare `codex`.
#
# Examples:
#   codex                    -> adapter=codex  model=       effort=
#   codex@high               -> adapter=codex  model=       effort=high
#   codex:gpt-5.6-sol        -> adapter=codex  model=gpt-5.6-sol  effort=
#   codex:gpt-5.6-sol@high   -> adapter=codex  model=gpt-5.6-sol  effort=high
#   codex:@high              -> adapter=codex  model=       effort=high
#   codex:gpt-5.5@           -> adapter=codex  model=gpt-5.5 effort=
#
# spec_valid rejects anything unsafe for a manifest key / run-dir name or an unknown
# effort tier: a bad hand-edited entry is surfaced (FAIL: bad-spec), never run blindly.

spec_adapter() { local s="${1%%@*}"; printf '%s' "${s%%:*}"; }
spec_model()   { local s="${1%%@*}"; case "$s" in *:*) printf '%s' "${s#*:}";; *) printf '';; esac; }
spec_effort()  { case "$1" in *@*) printf '%s' "${1#*@}";; *) printf '';; esac; }

# spec_valid <spec> -> 0 if well-formed, else 1. Does NOT check adapter-file existence.
spec_valid() {
  local a m e
  [ "${#1}" -le 128 ] || return 1                          # must stay a usable path component (<255B)
  a="$(spec_adapter "$1")"; m="$(spec_model "$1")"; e="$(spec_effort "$1")"
  case "$a" in ''|-*|*[!A-Za-z0-9_-]*) return 1;; esac     # adapter: required, safe charset, no leading '-'
  case "$m" in *[!A-Za-z0-9._-]*) return 1;; esac          # model:  empty ok, else safe charset
  case "$e" in ''|low|medium|high|xhigh|max) ;; *) return 1;; esac   # effort: empty or a known tier
  return 0
}
