#!/usr/bin/env bash
# agent-companion: durable per-verifier quality metrics.
#
# WHY THIS EXISTS: every verifier in the panel is a paid CLI subscription. Nothing in the plugin
# recorded whether a given entry ever produced a finding worth acting on, so "which subscription
# should I cancel?" had no evidence behind it. This module is that evidence.
#
# State lives under $DATA (NEVER under the plugin root — that is ephemeral and is wiped by
# `/plugin update`), in TWO families of append-only TSV files plus a pending-marker tree:
#
#   $DATA/metrics/runs-YYYY-MM.tsv     written by `verify.sh collect` — the automatic facts
#   $DATA/metrics/scores-YYYY-MM.tsv   written by `verify.sh score`   — the manager's judgement
#   $DATA/metrics/pending/<repo>/<id>  one file per collected-but-unscored run (the gate)
#
# Two families rather than one because the two halves are known at different times and a TSV row
# cannot be amended later. They join on `reqid + label`.
#
# IDENTITY IS THE LABEL, never the adapter name. A panel may legitimately hold two entries of the
# same adapter with different models (`2-codex-gpt-5-5` and `5-codex-gpt-5-6-sol`); keying by
# adapter would merge them and destroy the one comparison the user most needs.
#
# Row schemas (TAB-delimited, "-" meaning "no value" so every column is always occupied):
#   runs    ts repo_key reqid mode label adapter model effort outcome cls
#   scores  ts repo_key reqid label accepted rejected duplicate dup_of top_severity report source note
#
# The pending file is plain `KEY=VALUE`, never sourced/eval'd, and carries a SNAPSHOT of the run's
# entries. That snapshot is what makes scoring survive the handoff GC: `cleanup_old` deletes the
# run directory about a day later, and without the snapshot a pending run could never be cleared
# and would block `prepare` forever.

# Callers set ROOT/DATA before sourcing; the default keeps this file usable standalone (tests
# source it directly), matching lib/panel.sh.
: "${DATA:=${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}}"

# Retention counts FILES, which is what the GC actually deletes: the current month plus the two
# preceding ones. Expressing it as "delete anything older than 60 days" would collapse the sample
# to a single day every time a month rolls over.
METRICS_KEEP_MONTH_FILES="${METRICS_KEEP_MONTH_FILES:-3}"
# A lock older than this is treated as abandoned by a killed process. Appends take milliseconds,
# so anything approaching a minute is wreckage, not contention.
METRICS_LOCK_STALE_SECONDS="${METRICS_LOCK_STALE_SECONDS:-60}"

metrics_dir() { printf '%s/metrics' "$DATA"; }

# UTC everywhere: a machine that changes timezone must not produce two files for one month, and
# a row written at 23:30 local must not sort into a different month than the reader expects.
metrics_month() { date -u +%Y-%m 2>/dev/null || printf '0000-00'; }
metrics_now()   { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '-'; }
_metrics_epoch() { date +%s 2>/dev/null || printf '0'; }

# metrics_clean <value> -> a value that cannot forge a record or a field.
# TAB and newline would forge records; the rest of the C0 range is display junk that has no
# business in a data file. An empty result becomes "-" so every column stays occupied.
metrics_clean() {
  local v
  v="$(printf '%s' "${1:-}" | tr '\t\n\r' '   ' | tr -d '[:cntrl:]')"
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  [ -n "$v" ] || v='-'
  printf '%s' "$v"
}

# A token that becomes a PATH COMPONENT (repo_key, reqid) is held to a much stricter rule than a
# data field: no slashes, no leading dot, nothing outside [A-Za-z0-9._-]. Path traversal through
# a hostile reqid is impossible by construction rather than by escaping.
metrics_valid_token() {
  case "${1:-}" in
    ''|.*|*[!A-Za-z0-9._-]*) return 1 ;;
  esac
  return 0
}

# ---------- append serialisation ----------
# A mkdir mutex, NOT flock: macOS ships no flock, and lib/panel.sh already documents mkdir as this
# plugin's house mechanism. Appends from parallel repos are short, so contention is rare; the
# stale sweep exists because a killed holder must not wedge every later run permanently.
_metrics_lock() {
  local lock i=0 held
  lock="$(metrics_dir)/.lock"
  while [ "$i" -lt 50 ]; do
    if mkdir "$lock" 2>/dev/null; then
      printf '%s' "$(_metrics_epoch)" > "$lock/ts" 2>/dev/null
      return 0
    fi
    held="$(cat "$lock/ts" 2>/dev/null)"
    case "$held" in ''|*[!0-9]*) held=0 ;; esac
    if [ "$held" -gt 0 ] && [ $(( $(_metrics_epoch) - held )) -ge "$METRICS_LOCK_STALE_SECONDS" ]; then
      rm -rf "$lock" 2>/dev/null
      continue
    fi
    i=$((i + 1))
    sleep 0.1 2>/dev/null || sleep 1
  done
  return 1
}
_metrics_unlock() { rm -rf "$(metrics_dir)/.lock" 2>/dev/null; return 0; }

# ---------- file discovery ----------
# metrics_file <runs|scores> [month] -> the path a write of that month lands in.
metrics_file() { printf '%s/%s-%s.tsv' "$(metrics_dir)" "$1" "${2:-$(metrics_month)}"; }

# metrics_files <runs|scores> -> every retained file of that family, NEWEST FIRST.
# Sorted by name, which for `YYYY-MM` is chronological order — no date parsing needed.
metrics_files() {
  local d; d="$(metrics_dir)"
  [ -d "$d" ] || return 0
  ls -1 "$d/$1-"*.tsv 2>/dev/null | sort -r
}

# metrics_has_row <runs|scores> <reqid> <label> -> 0 when a row already exists.
# This is what makes `collect` and `score` idempotent: both are re-runnable by the manager, and a
# blind append would double-count every retry.
metrics_has_row() {
  local family="$1" reqid="$2" label="$3" f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if awk -F'\t' -v r="$reqid" -v l="$label" -v fam="$family" '
         (fam == "runs"   && $3 == r && $5 == l) ||
         (fam == "scores" && $3 == r && $4 == l) { found = 1; exit }
         END { exit found ? 0 : 1 }' "$f" 2>/dev/null
    then return 0; fi
  done < <(metrics_files "$family")
  return 1
}

# _metrics_append <family> <field>... -> append one TAB record, under the lock.
_metrics_append() {
  local family="$1"; shift
  local d line f
  d="$(metrics_dir)"
  mkdir -p "$d" 2>/dev/null || return 1
  line=""
  local v
  for v in "$@"; do line="${line}$(metrics_clean "$v")"$'\t'; done
  line="${line%$'\t'}"
  f="$(metrics_file "$family")"
  _metrics_lock || return 1
  printf '%s\n' "$line" >> "$f" 2>/dev/null || { _metrics_unlock; return 1; }
  _metrics_unlock
  return 0
}

# ---------- public write API ----------
# metrics_record_run <repo_key> <reqid> <mode> <label> <adapter> <model> <effort> <outcome> <cls>
# rc 0 written · rc 2 already recorded (not an error) · rc 1 write failure.
metrics_record_run() {
  metrics_valid_token "$1" && metrics_valid_token "$2" || return 1
  metrics_has_row runs "$2" "$4" && return 2
  _metrics_append runs "$(metrics_now)" "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
}

# metrics_record_score <repo_key> <reqid> <label> <acc> <rej> <dup> <dup_of> <severity> <report> <source> [note]
# rc 0 written · rc 2 already scored (caller may retry with force) · rc 1 write failure.
# A forced re-score appends a SUPERSEDING row rather than editing in place — the file stays
# append-only, and readers keep the last row per `reqid + label`.
metrics_record_score() {
  metrics_valid_token "$1" && metrics_valid_token "$2" || return 1
  [ "${METRICS_FORCE:-0}" = 1 ] || ! metrics_has_row scores "$2" "$3" || return 2
  _metrics_append scores "$(metrics_now)" "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11:--}"
}

# ---------- retention ----------
# Keeps the newest $METRICS_KEEP_MONTH_FILES files of EACH family. Deliberately not throttled by a
# marker file: it is two `ls` calls and a few `rm`s, and `cleanup_old` in verify.sh is likewise
# unthrottled — a throttle here would be a second mechanism to keep correct for no gain.
metrics_gc() {
  local family f n
  for family in runs scores; do
    n=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      n=$((n + 1))
      [ "$n" -gt "$METRICS_KEEP_MONTH_FILES" ] && rm -f "$f" 2>/dev/null
    done < <(metrics_files "$family")
  done
  return 0
}

# ---------- the gate: pending markers ----------
metrics_pending_dir()  { printf '%s/pending/%s' "$(metrics_dir)" "$1"; }
metrics_pending_file() { printf '%s/%s' "$(metrics_pending_dir "$1")" "$2"; }

# metrics_pending_write <repo_key> <reqid> <mode> — entry lines arrive on STDIN as
# `label<TAB>adapter<TAB>model<TAB>effort<TAB>outcome`, one per panel entry.
#
# The snapshot is the whole point: `score` reads THIS file, never the run directory, so a run
# stays scoreable after the 1-day handoff GC has deleted its artifacts. Written atomically so a
# crash mid-write cannot leave a half-parsed gate that blocks `prepare` with no way to clear it.
metrics_pending_write() {
  local key="$1" reqid="$2" mode="$3" dir tmp line
  metrics_valid_token "$key" && metrics_valid_token "$reqid" || return 1
  dir="$(metrics_pending_dir "$key")"
  mkdir -p "$dir" 2>/dev/null || return 1
  tmp="$(mktemp "$dir/.tmp.XXXXXX" 2>/dev/null)" || return 1
  {
    printf 'reqid=%s\n' "$(metrics_clean "$reqid")"
    printf 'repo_key=%s\n' "$(metrics_clean "$key")"
    printf 'mode=%s\n' "$(metrics_clean "$mode")"
    printf 'collected=%s\n' "$(metrics_now)"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf 'entry=%s\n' "$line"
    done
  } > "$tmp" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  mv -f "$tmp" "$(metrics_pending_file "$key" "$reqid")" 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null; return 1; }
  return 0
}

# metrics_pending_list [repo_key] -> one `<repo_key><TAB><reqid>` line per pending run.
# With no argument, lists every repo — `stats.sh` and diagnostics want the global view.
metrics_pending_list() {
  local base f key
  base="$(metrics_dir)/pending"
  [ -d "$base" ] || return 0
  if [ -n "${1:-}" ]; then
    [ -d "$(metrics_pending_dir "$1")" ] || return 0
    for f in "$(metrics_pending_dir "$1")"/*; do
      [ -f "$f" ] || continue
      case "${f##*/}" in .*) continue;; esac
      printf '%s\t%s\n' "$1" "${f##*/}"
    done
    return 0
  fi
  for key in "$base"/*; do
    [ -d "$key" ] || continue
    for f in "$key"/*; do
      [ -f "$f" ] || continue
      case "${f##*/}" in .*) continue;; esac
      printf '%s\t%s\n' "${key##*/}" "${f##*/}"
    done
  done
  return 0
}

# metrics_pending_find <reqid> -> the repo_key holding that pending run, rc 1 if none.
# Lets `score` address a run by bare reqid, which is what the `collect` tail prints: a run-dir
# path stops being valid once the handoff GC runs, a reqid never does.
metrics_pending_find() {
  local reqid="$1" k r
  metrics_valid_token "$reqid" || return 1
  while IFS=$'\t' read -r k r; do
    [ "$r" = "$reqid" ] && { printf '%s' "$k"; return 0; }
  done < <(metrics_pending_list)
  return 1
}

# metrics_pending_get <repo_key> <reqid> <key> -> value of a KEY=VALUE line.
metrics_pending_get() {
  local f; f="$(metrics_pending_file "$1" "$2")"
  [ -f "$f" ] || return 1
  awk -F= -v k="$3" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$f" 2>/dev/null
}

# metrics_pending_entries <repo_key> <reqid> -> the snapshot rows,
# `label<TAB>adapter<TAB>model<TAB>effort<TAB>outcome` each.
metrics_pending_entries() {
  local f; f="$(metrics_pending_file "$1" "$2")"
  [ -f "$f" ] || return 1
  awk '/^entry=/{sub(/^entry=/,""); print}' "$f" 2>/dev/null
}

# ---------- reading history (the fallbacks a cleared gate needs) ----------
# Once a run has been scored its pending file is gone, so a deliberate re-score (`--force`) has
# to recover the same two facts from the recorded history instead.
#
# metrics_repo_for_reqid <reqid> -> the repo_key that run belongs to, rc 1 if unknown.
metrics_repo_for_reqid() {
  local reqid="$1" f out
  metrics_valid_token "$reqid" || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    out="$(awk -F'\t' -v r="$reqid" '$3==r{print $2; exit}' "$f" 2>/dev/null)"
    [ -n "$out" ] && { printf '%s' "$out"; return 0; }
  done < <(metrics_files runs)
  return 1
}

# metrics_labels_for_reqid <reqid> -> the labels of that run that produced a report.
metrics_labels_for_reqid() {
  local reqid="$1" f
  metrics_valid_token "$reqid" || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    awk -F'\t' -v r="$reqid" '$3==r && $9=="report"{print $5}' "$f" 2>/dev/null
  done < <(metrics_files runs)
}

metrics_pending_clear() {
  metrics_valid_token "$1" && metrics_valid_token "$2" || return 1
  rm -f "$(metrics_pending_file "$1" "$2")" 2>/dev/null
  rmdir "$(metrics_pending_dir "$1")" 2>/dev/null || true
  return 0
}
