#!/usr/bin/env bash
# Resolve a Grok CLI model id for a family, purely from `grok models`. No hardcoded
# version to maintain.
# resolve_model <family-keyword>  ->  prints a model id, or nothing if none found.
#
# Rule (per family, keyword e.g. "grok-build" / "grok-composer"):
#   1. if a model OF THIS FAMILY is marked "(default)" in `grok models` → use it;
#   2. else → use the best (highest version) model of this family;
#   3. if `grok models` is unavailable / has no family member → print nothing
#      (the caller decides what to do — adapters fail closed rather than guess).
#
# Example listing → resolve grok-build:
#   grok-build-2
#   grok-build-1 (default)            → grok-build-1   (family default wins)
#   grok-composer-2.5-fast
# vs (default is on composer, build has none):
#   grok-build-2
#   grok-build-1
#   grok-composer-2.5-fast (default)  → grok-build-2   (best build, ignores other family's default)
resolve_model() {
  local kw="$1" list line id def="" famids=""
  list="$(grok models 2>/dev/null)" || true
  [ -n "$list" ] || return 0

  while IFS= read -r line; do
    id="$(printf '%s\n' "$line" | tr -s ' \t,|"[]{}:()' '\n' | grep -iE '^grok-[a-z0-9._-]+$' | head -1)"
    [ -n "$id" ] || continue
    case "$id" in *"$kw"*) ;; *) continue ;; esac      # this family only
    famids="$famids$id"$'\n'
    printf '%s' "$line" | grep -qi 'default' && def="$id"   # default counts only within family
  done <<< "$list"

  [ -n "$famids" ] || return 0
  if [ -n "$def" ]; then printf '%s' "$def"; return; fi

  # best = highest version; prefer version-sort, fall back to lexicographic if unsupported
  if printf 'a\n' | sort -V >/dev/null 2>&1; then
    printf '%s' "$famids" | grep -v '^$' | sort -V | tail -1
  else
    printf '%s' "$famids" | grep -v '^$' | sort | tail -1
  fi
}
