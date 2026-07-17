#!/usr/bin/env bash
# Resolve a Grok CLI model id purely from `grok models`. No hardcoded version to maintain.
#
# resolve_frontier  ->  prints the frontier (non-composer) grok model id, or nothing.
# The frontier reasoning model keeps getting renamed (grok-build → grok-4 → grok-4.5 …),
# so pinning a family keyword breaks on every rebrand. Instead: take every model that is
# NOT the composer family; a "(default)" among them wins, else the best (highest version).
# This is what adapters/grok.sh wants — the flagship model, whatever xAI calls it today.
resolve_frontier() {
  local list line id def="" ids=""
  list="$(grok models 2>/dev/null)" || true
  [ -n "$list" ] || return 0

  while IFS= read -r line; do
    id="$(printf '%s\n' "$line" | tr -s ' \t,|"[]{}:()' '\n' | grep -iE '^grok-[a-z0-9._-]+$' | head -1)"
    [ -n "$id" ] || continue
    case "$id" in *composer*) continue ;; esac          # exclude the composer family
    ids="$ids$id"$'\n'
    printf '%s' "$line" | grep -qi 'default' && def="$id"
  done <<< "$list"

  [ -n "$ids" ] || return 0
  if [ -n "$def" ]; then printf '%s' "$def"; return; fi
  _grok_best "$ids"
}

# _grok_best <newline-list>  ->  highest-version id (version-sort, lexicographic fallback).
_grok_best() {
  if printf 'a\n' | sort -V >/dev/null 2>&1; then
    printf '%s' "$1" | grep -v '^$' | sort -V | tail -1
  else
    printf '%s' "$1" | grep -v '^$' | sort | tail -1
  fi
}
