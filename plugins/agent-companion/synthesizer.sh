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

current() { [ -f "$CONF" ] && head -n1 "$CONF" | tr -d '[:space:]' || true; }

valid() { # <name>
  case "$1" in
    none|off) return 0 ;;
    claude)   return 0 ;;                 # headless `claude -p` (uses Claude limits)
    *)        [ -f "$ROOT/adapters/$1.sh" ] ;;
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
    echo "config: $CONF"
    ;;
  set)
    name="${1:?usage: synthesizer.sh set <claude|adapter|none>}"
    if ! valid "$name"; then
      echo "unknown synthesizer: $name (use 'claude', an adapter name, or 'none')" >&2; exit 1
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
