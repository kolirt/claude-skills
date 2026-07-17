#!/usr/bin/env bash
# Manage the report synthesizer — the agent that consolidates N verifier verdicts
# into ONE report so the main session isn't flooded. Stored in $DATA/synthesizer.conf
# (single line: an adapter name, the special value "claude", or "none").
# Usage: synthesizer.sh show | set <claude|adapter|none> | off
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF}"
# Same stable persistent location as verify.sh / verifiers.sh.
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}"
CONF="$DATA/synthesizer.conf"
. "$ROOT/lib/spec.sh"

# trim only surrounding whitespace (NOT inner) so a malformed value isn't silently repaired.
current() { [ -f "$CONF" ] && head -n1 "$CONF" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true; }

valid() { # <name>  — may be a full spec cli[:model][@effort]
  case "$1" in
    none|off) return 0 ;;
    claude)   return 0 ;;                 # headless `claude -p` (uses Claude limits)
    *)        spec_valid "$1" && [ -f "$ROOT/adapters/$(spec_adapter "$1").sh" ] ;;
  esac
}

cmd="${1:-show}"; shift || true
case "$cmd" in
  show)
    c="$(current)"
    echo "synthesizer: ${c:-unset}"
    printf 'candidates: claude'
    for a in "$ROOT"/adapters/*.sh; do [ -f "$a" ] && printf ', %s' "$(basename "$a" .sh)"; done
    printf ', none\n'
    echo "format: claude | none | cli[:model][@effort]  e.g. codex:gpt-5.6-sol@high"
    echo "config: $CONF"
    ;;
  set)
    name="${1:?usage: synthesizer.sh set <claude|cli[:model][@effort]|none>}"
    [ "$name" = off ] && name=none   # normalize: `set off` is an alias for `none`
    if ! valid "$name"; then
      echo "invalid synthesizer: $name (use 'claude', 'none', or cli[:model][@effort] with an existing adapter)" >&2; exit 1
    fi
    mkdir -p "$DATA"; printf '%s\n' "$name" > "$CONF"
    echo "synthesizer set to: $name"
    ;;
  off)
    mkdir -p "$DATA"; printf 'none\n' > "$CONF"
    echo "synthesizer disabled (none) — reports will be listed compactly instead"
    ;;
  *) echo "usage: synthesizer.sh show | set <name> | off" >&2; exit 64 ;;
esac
