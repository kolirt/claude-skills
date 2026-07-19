#!/usr/bin/env bash
# Manage the report synthesizer — the agent that consolidates N verifier verdicts into ONE
# report so the main session isn't flooded. Stored in the panel document
# ($CLAUDE_PLUGIN_DATA/panel.json) alongside the verifiers, under "synthesizer".
#
# Usage:
#   synthesizer.sh show
#   synthesizer.sh set <claude|<adapter>|none> [--model <name>] [--effort <tier>]
#   synthesizer.sh off
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF}"
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}"
. "$ROOT/lib/panel.sh"

panel_warn_legacy

# write_synth <adapter> <model> <effort> — replaces the S record, verifiers untouched.
# Reads first and aborts on failure: an unreadable panel must not be silently replaced by
# one holding only this synthesizer, losing every configured verifier.
write_synth() {
  local recs
  recs="$(panel_records)" || {
    echo "cannot read the current panel — refusing to edit it (fix or remove $(panel_file))" >&2
    return 1; }
  { printf '%s\n' "$recs" | awk -F'\t' '$1=="V"'
    printf 'S\t%s\t%s\t%s\n' "$1" "$2" "$3"
  } | panel_save
}

cmd="${1:-show}"; shift || true
case "$cmd" in
  show)
    if ! synthline="$(panel_synth)"; then
      echo "synthesizer: UNKNOWN — the panel config could not be read"
      echo "  fix or remove $(panel_file), then re-run"
      exit 1
    fi
    IFS=$'\037' read -r a m e < <(printf '%s\n' "$synthline" | panel_us)
    # "unset" (never chosen) is NOT "none" (chosen: disabled) — commands/on.md keys the
    # first-run "which agent should consolidate?" question off exactly this word.
    printf 'synthesizer: %s' "${a:-unset}"
    [ -n "${m:-}" ] && printf '  model: %s' "$m"
    [ -n "${e:-}" ] && printf '  effort: %s' "$e"
    printf '\n'
    # show must never fail on a stale value — it is the command a user runs precisely to
    # find out WHY consolidation stopped happening. Flag it instead.
    if [ -n "${a:-}" ] && [ "$a" != none ] && [ "$a" != claude ] && [ ! -f "$ROOT/adapters/$a.sh" ]; then
      echo "  ^ STALE: adapter '$a' no longer exists — reports are being listed directly."
      echo "    fix with: synthesizer.sh set <claude|adapter|none>"
    fi
    printf 'candidates: claude'
    for f in "$ROOT"/adapters/*.sh; do [ -f "$f" ] && printf ', %s' "$(basename "$f" .sh)"; done
    printf ', none\n'
    echo "set: synthesizer.sh set <claude|adapter|none> [--model <name>] [--effort <tier>]"
    echo "config: $(panel_file)"
    ;;
  set)
    name="${1:?usage: synthesizer.sh set <claude|adapter|none> [--model <name>] [--effort <tier>]}"; shift || true
    model=""; effort=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --model)  model="${2:?--model needs a value}"; shift 2;;
        --effort) effort="${2:?--effort needs a value}"; shift 2;;
        *) echo "unknown flag: $1 (use --model <name> / --effort <tier>)" >&2; exit 64;;
      esac
    done
    [ "$name" = off ] && name=none   # normalize: `set off` is an alias for `none`

    case "$name" in
      none)   write_synth none "" "" || exit 1
              echo "synthesizer disabled (none)"; exit 0;;
      claude) : ;;                   # headless `claude -p` (uses Claude limits)
      *) panel_valid_adapter "$name" && [ -f "$ROOT/adapters/$name.sh" ] || {
           echo "invalid synthesizer: $name (use 'claude', 'none', or an existing adapter)" >&2; exit 1; };;
    esac
    panel_valid_effort "$effort" || {
      echo "invalid effort: $effort (use low|medium|high|xhigh|max)" >&2; exit 1; }

    # Same add-time resolution as verifiers.sh add — one implementation, in panel.sh.
    if [ -n "$model" ] && [ "$name" != claude ]; then
      resolved="$(panel_resolve_model "$name" "$model")"; rc=$?
      case "$rc" in
        0) [ "$resolved" = "$model" ] || echo "resolved model \"$model\" -> \"$resolved\""
           model="$resolved";;
        1) : ;;
        *) { echo "unknown or ambiguous model for $name: \"$model\". Available:"
             panel_models "$name" | sed 's/^/  - /'
           } >&2
           exit 1;;
      esac
    fi
    panel_valid_model "$model" || { echo "invalid model name (contains a control character, or is longer than 200 chars)" >&2; exit 1; }

    write_synth "$name" "$model" "$effort" || exit 1
    echo "synthesizer set to: $name${model:+ (model: $model)}"
    ;;
  off)
    write_synth none "" "" || exit 1
    echo "synthesizer disabled (none) — reports will be listed compactly instead"
    ;;
  *) echo "usage: synthesizer.sh show | set <name> [--model <n>] [--effort <t>] | off" >&2; exit 64 ;;
esac
