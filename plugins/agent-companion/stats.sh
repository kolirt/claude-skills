#!/usr/bin/env bash
# agent-companion: read the collected verifier-quality metrics.
#
# Answers ONE question: which paid verifier subscriptions are earning their keep? It prints
# numbers and refuses to draw the conclusion — a keep/drop verdict from this data would be a
# guess dressed as arithmetic (see the caveats printed under the table).
#
# Reads the append-only TSV families written by lib/metrics.sh and joins them on `reqid + label`.
# Grouping is by ADAPTER by default and by adapter/model under --by-model; the stored identity is
# always the label, so two entries of the same adapter never merge unless you ask them to.

set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF}"
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}"
. "$ROOT/lib/metrics.sh"

# An adapter with fewer scored runs than this is not evidence, and the footer says so by name.
MIN_SAMPLE="${AGENT_COMPANION_MIN_SAMPLE:-8}"

usage() {
  cat >&2 <<'USAGE'
usage: stats.sh [--since <days>] [--repo <key>] [--mode <mode>] [--by-model]

  --since <days>   only runs collected within the last N days
  --repo <key>     only runs from one repository (the 16-hex key in the metrics)
  --mode <mode>    only review|consult|audit|diagnose|research runs
  --by-model       one row per adapter/model instead of one per adapter
USAGE
}

# cutoff_ts <days> -> an ISO-8601 UTC timestamp N days ago, comparable as a plain string against
# the `ts` column. BSD and GNU date disagree on the flag, so try both rather than parsing dates
# in awk.
cutoff_ts() {
  date -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  date -u -d "$1 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  return 1
}

SINCE=""; REPO=""; MODE=""; BY_MODEL=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)    SINCE="${2:-}"; shift 2 || true;;
    --repo)     REPO="${2:-}"; shift 2 || true;;
    --mode)     MODE="${2:-}"; shift 2 || true;;
    --by-model) BY_MODEL=1; shift;;
    -h|--help)  usage; exit 0;;
    *) echo "stats.sh: unknown argument: $1" >&2; usage; exit 64;;
  esac
done

CUTOFF=""
if [ -n "$SINCE" ]; then
  case "$SINCE" in ''|*[!0-9]*) echo "stats.sh: --since takes a number of days" >&2; exit 64;; esac
  CUTOFF="$(cutoff_ts "$SINCE")" || { echo "stats.sh: cannot compute a cutoff date on this system" >&2; exit 64; }
fi
if [ -n "$MODE" ]; then
  case "$MODE" in review|consult|audit|diagnose|research) ;;
    *) echo "stats.sh: --mode must be review|consult|audit|diagnose|research" >&2; exit 64;; esac
fi

RUNS="$(metrics_files runs)"
SCORES="$(metrics_files scores)"
if [ -z "$RUNS" ]; then
  echo "No metrics recorded yet — run a panel and score it." >&2
  echo "(metrics live in $(metrics_dir))" >&2
  exit 0
fi

# runs files FIRST: the awk program builds its index from them and then joins scores onto it.
# shellcheck disable=SC2086
awk -F'\t' \
  -v cutoff="$CUTOFF" -v only_repo="$REPO" -v only_mode="$MODE" -v by_model="$BY_MODEL" \
  -v min_sample="$MIN_SAMPLE" '
  function grp(adapter, model) { return by_model ? adapter "/" model : adapter }

  FILENAME ~ /\/runs-[0-9]{4}-[0-9]{2}\.tsv$/ {
    ts = $1; repo = $2; reqid = $3; mode = $4; label = $5
    adapter = $6; model = $7; outcome = $9
    if (cutoff != "" && ts < cutoff) next
    if (only_repo != "" && repo != only_repo) next
    if (only_mode != "" && mode != only_mode) next
    k = reqid SUBSEP label
    seen[k] = 1
    g = grp(adapter, model)
    group[k] = g
    groups[g] = 1
    runs[g]++
    if (outcome == "report") reports[g]++; else unavail[g]++
    next
  }

  FILENAME ~ /\/scores-[0-9]{4}-[0-9]{2}\.tsv$/ {
    reqid = $3; label = $4
    k = reqid SUBSEP label
    if (!(k in seen)) { orphan++; next }
    # Last row per key wins: a --force re-score appends a superseding row rather than editing
    # the file in place.
    s_acc[k] = $5; s_rej[k] = $6; s_dup[k] = $7
    s_report[k] = $10; s_source[k] = $11
    scored[k] = 1
    next
  }

  END {
    for (k in scored) {
      g = group[k]
      if (s_source[k] == "skip") { waived[g]++; continue }
      n[g]++
      acc[g] += s_acc[k]; rej[g] += s_rej[k]; dup[g] += s_dup[k]
      if (s_report[k] == "useful") useful[g]++
    }
    fmt = "%-26s %5s %8s %8s %7s %8s %8s %10s %8s %8s %6s\n"
    printf fmt, (by_model ? "adapter/model" : "adapter"), "runs", "reports", "fail/sk", "waived", \
      "accept", "reject", "duplicate", "acc/run", "unique%", "n"
    for (g in groups) {
      a = acc[g] + 0; d = dup[g] + 0; c = n[g] + 0
      accrun = c ? sprintf("%.2f", a / c) : "-"
      uniq   = (a + d) ? sprintf("%.0f%%", 100 * a / (a + d)) : "-"
      usefulpct = c ? sprintf("%.0f%%", 100 * (useful[g] + 0) / c) : "-"
      printf fmt, g, runs[g] + 0, reports[g] + 0, unavail[g] + 0, waived[g] + 0, \
        a, rej[g] + 0, d, accrun, uniq, c
      if (c > 0 && c < min_sample) small = small "  " g " (n=" c ")\n"
      usefulline[g] = usefulpct
    }
    printf "\nuseful%% (share of scored reports the manager called useful):\n"
    for (g in groups) if (n[g] + 0 > 0) printf "  %-26s %s\n", g, usefulline[g]
    if (small != "") {
      printf "\nBelow the %d-run threshold — not enough evidence to cancel anything:\n%s", min_sample, small
    }
    if (orphan + 0 > 0) {
      printf "\n%d score row(s) had no surviving run row (their month was rotated out) and were dropped.\n", orphan
    }
  }
' $RUNS $SCORES

# Coverage is part of the answer: a table read as complete when a fifth of the runs were never
# graded is how a subscription gets cancelled on a rumour.
PENDING="$(metrics_pending_list "${REPO:-}" | wc -l | tr -d ' ')"
if [ "${PENDING:-0}" -gt 0 ]; then
  printf '\n%s run(s) collected but not yet scored — they are missing from the numbers above.\n' "$PENDING"
fi
if [ -n "$CUTOFF" ]; then
  OLDEST="$(printf '%s\n' "$RUNS" | tail -n1)"
  OLDEST_MONTH="${OLDEST##*/runs-}"; OLDEST_MONTH="${OLDEST_MONTH%.tsv}"
  printf 'Window: since %s. Retained data starts at %s — an older --since cannot reach further back.\n' \
    "$CUTOFF" "$OLDEST_MONTH"
fi
printf '\nThese rates are confounded by task difficulty, reading order and mode mix. Compare\n'
printf 'verifiers WITHIN a run, treat cross-period comparisons as weak, and read the table as\n'
printf 'evidence for a decision rather than as the decision.\n'
