#!/usr/bin/env bash
# Manage the active verifier panel without touching plugin paths by hand.
# Usage: verifiers.sh list | add <name> | remove <name>
# The active set is read from ${CLAUDE_PLUGIN_DATA}/verifiers.conf if present
# (persistent user override), else the bundled default. Edits always go to the
# DATA override (CLAUDE_PLUGIN_ROOT is ephemeral — wiped on update).
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF}"
DATA="${CLAUDE_PLUGIN_DATA:-$ROOT/.data}"
CONF="$DATA/verifiers.conf"
DEFAULT="$ROOT/verifiers.conf"

active_file() { if [ -f "$CONF" ]; then printf '%s\n' "$CONF"; else printf '%s\n' "$DEFAULT"; fi; }
read_active()  { grep -v '^#' "$(active_file)" 2>/dev/null | grep -v '^[[:space:]]*$' || true; }

# First edit seeds the DATA override from the bundled default. Read DEFAULT
# explicitly (NOT read_active): `> "$CONF"` truncates CONF before the command
# runs, so reading the "effective" set here would see the now-empty override.
ensure_override() {
  if [ ! -f "$CONF" ]; then
    mkdir -p "$DATA"
    { grep -v '^#' "$DEFAULT" 2>/dev/null | grep -v '^[[:space:]]*$'; } > "$CONF" || true
  fi
}

cmd="${1:-list}"; shift || true
case "$cmd" in
  list)
    echo "config: $(active_file)"
    echo "active verifiers:"
    read_active | sed 's/^/  - /'
    echo "available adapters:"
    ls "$ROOT/adapters" 2>/dev/null | sed -e 's/\.sh$//' -e 's/^/  - /'
    ;;
  add)
    name="${1:?usage: verifiers.sh add <name>}"
    if [ ! -f "$ROOT/adapters/$name.sh" ]; then
      echo "no adapter found: adapters/$name.sh — create it first (see creating-plugins skill)" >&2
      exit 1
    fi
    ensure_override
    if grep -qxF "$name" "$CONF"; then echo "$name is already active"; exit 0; fi
    printf '%s\n' "$name" >> "$CONF"
    echo "added $name; active set is now:"; read_active | sed 's/^/  - /'
    ;;
  remove)
    name="${1:?usage: verifiers.sh remove <name>}"
    ensure_override
    tmp="$(mktemp)"; grep -vxF "$name" "$CONF" > "$tmp" || true; mv "$tmp" "$CONF"
    echo "removed $name; active set is now:"; read_active | sed 's/^/  - /'
    ;;
  *)
    echo "usage: verifiers.sh list | add <name> | remove <name>" >&2; exit 64;;
esac
