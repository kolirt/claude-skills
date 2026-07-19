#!/usr/bin/env bash
# Manage the active verifier panel without touching plugin paths by hand.
#
# Usage:
#   verifiers.sh list
#   verifiers.sh add <adapter> [--model <name>] [--effort <low|medium|high|xhigh|max>]
#   verifiers.sh remove <index>
#
# FLAGS, not a packed string: the user speaks naturally ("add antigravity gemini 3.5 flash
# medium") and Claude-as-manager translates that into flags. The syntax therefore has
# to be unambiguous for code, not terse for humans — and a model name like
# "Gemini 3.5 Flash (Medium)" simply cannot survive a delimiter-packed grammar.
#
# Entries are addressed by INDEX (their position in the panel), never by their text: two
# entries may share an adapter and model and still be distinct.
#
# The active panel is read from ${CLAUDE_PLUGIN_DATA}/panel.json if present (persistent user
# override), else the bundled default. Edits always go to the DATA override
# (CLAUDE_PLUGIN_ROOT is ephemeral — wiped on update).
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF}"
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}"
. "$ROOT/lib/panel.sh"

panel_warn_legacy

# Capture BEFORE looping: `while ... done < <(panel_verifiers)` discards the exit status, so
# an unreadable panel would print "(none active)" — reporting a broken config as an empty one.
show_panel() {
  local recs idx a m e label n=0
  recs="$(panel_verifiers)" || {
    echo "  UNKNOWN — the panel config could not be read (fix or remove $(panel_file))"
    return 1; }
  while IFS=$'\037' read -r idx a m e label; do
    [ -n "$label" ] || continue
    n=$((n + 1))
    printf '  %s. %s' "$idx" "${a:-<invalid entry>}"
    [ -n "$m" ] && printf '  model: %s' "$m"
    [ -n "$e" ] && printf '  effort: %s' "$e"
    printf '\n'
  done < <(printf '%s\n' "$recs" | panel_us)
  [ "$n" -eq 0 ] && echo "  (none active)"
  return 0
}

cmd="${1:-list}"; shift || true
case "$cmd" in
  list)
    echo "config: $(panel_file)"
    echo "active verifiers:"
    show_panel || list_rc=1
    echo "available adapters:"
    # glob, not `ls | sed`: a colourising ls would leave escape codes that defeat the `\.sh$`
    # anchor. Same discipline as available_adapters() in verify.sh.
    for a in "$ROOT"/adapters/*.sh; do [ -f "$a" ] && printf '  - %s\n' "$(basename "$a" .sh)"; done
    echo "add: verifiers.sh add <adapter> [--model <name>] [--effort <low|medium|high|xhigh|max>]"
    exit "${list_rc:-0}"
    ;;
  add)
    adapter="${1:?usage: verifiers.sh add <adapter> [--model <name>] [--effort <tier>]}"; shift || true
    model=""; effort=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --model)  model="${2:?--model needs a value}"; shift 2;;
        --effort) effort="${2:?--effort needs a value}"; shift 2;;
        *) echo "unknown flag: $1 (use --model <name> / --effort <tier>)" >&2; exit 64;;
      esac
    done

    panel_valid_adapter "$adapter" || {
      echo "invalid adapter name: $adapter" >&2; exit 1; }
    [ -f "$ROOT/adapters/$adapter.sh" ] || {
      echo "no adapter found: adapters/$adapter.sh — create it first (see creating-plugins skill)" >&2; exit 1; }
    panel_valid_effort "$effort" || {
      echo "invalid effort: $effort (use low|medium|high|xhigh|max)" >&2; exit 1; }

    # Resolve the model ONCE, here, so the panel stores the adapter's own spelling and the
    # run path never has to ask again.
    if [ -n "$model" ]; then
      resolved="$(panel_resolve_model "$adapter" "$model")"; rc=$?
      case "$rc" in
        0) [ "$resolved" = "$model" ] || echo "resolved model \"$model\" -> \"$resolved\""
           model="$resolved";;
        1) : ;;   # adapter cannot enumerate its models — store verbatim, as typed
        *) { echo "unknown or ambiguous model for $adapter: \"$model\". Available:"
             panel_models "$adapter" | sed 's/^/  - /'
           } >&2
           exit 1;;
      esac
      panel_valid_model "$model" || { echo "invalid model name (contains a control character, or is longer than 200 chars)" >&2; exit 1; }
    fi

    # Read FIRST and bail on failure: an unreadable panel must abort the edit, never fall
    # through into a write that would replace the user's config with a fresh empty one.
    recs="$(panel_records)" || {
      echo "cannot read the current panel — refusing to edit it (fix or remove $(panel_file))" >&2
      exit 1; }
    # Append the new V record, keeping every existing entry and the S (synthesizer) record.
    # The S line is re-emitted last so panel_save always sees exactly one.
    { printf '%s\n' "$recs" | awk -F'\t' '$1=="V"'
      printf 'V\t%s\t%s\t%s\n' "$adapter" "$model" "$effort"
      s="$(printf '%s\n' "$recs" | awk -F'\t' '$1=="S"{print; exit}')"
      # no prior S -> UNSET (empty adapter), not "none": the first-run synthesizer question
      # in commands/on.md must still fire for someone who only ever ran `verifiers add`.
      printf '%s\n' "${s:-$(printf 'S\t\t\t')}"
    } | panel_save || exit 1
    echo "added $adapter; active set is now:"; show_panel
    ;;
  remove)
    index="${1:?usage: verifiers.sh remove <index>}"
    case "$index" in ''|*[!0-9]*) echo "index must be a number (see 'verifiers.sh list')" >&2; exit 64;; esac
    # `panel_verifiers | grep -c .` would turn a READ FAILURE into total=0 and report
    # "no verifier at index N (panel has 0)" — blaming the user's index for a broken config.
    listing="$(panel_verifiers)" || {
      echo "cannot read the current panel — refusing to edit it (fix or remove $(panel_file))" >&2
      exit 1; }
    total="$(printf '%s\n' "$listing" | grep -c . || true)"
    if [ "$index" -lt 1 ] || [ "$index" -gt "$total" ]; then
      echo "no verifier at index $index (panel has $total)" >&2; exit 1
    fi
    recs="$(panel_records)" || {
      echo "cannot read the current panel — refusing to edit it (fix or remove $(panel_file))" >&2
      exit 1; }
    printf '%s\n' "$recs" | awk -F'\t' -v drop="$index" '
        $1=="V" { n++; if (n == drop) next }
        NF { print }
      ' | panel_save || exit 1
    echo "removed entry $index; active set is now:"; show_panel
    ;;
  *)
    echo "usage: verifiers.sh list | add <adapter> [--model <name>] [--effort <tier>] | remove <index>" >&2
    exit 64;;
esac
