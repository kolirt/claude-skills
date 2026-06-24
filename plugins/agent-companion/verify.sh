#!/usr/bin/env bash
set -uo pipefail
# Bad invocation is an environment/invocation error → exit 64 (NOT the shell's default 1),
# so the dispatcher's exit contract is exactly 0/10/64 with no leaks.
if [ "$#" -lt 3 ]; then
  echo "usage: verify.sh <mode> <effort> <request-file>" >&2; exit 64
fi
MODE="$1"; EFFORT="$2"; REQUEST_FILE="$3"
# An unknown mode (e.g. a typo'd "reveiw") must NOT fall through to the non-gating
# default exit 0 — that would silently "pass" a review. Reject it as an invocation error.
case "$MODE" in
  review|consult|audit|diagnose) ;;
  *) echo "unknown mode: $MODE (use review|consult|audit|diagnose)" >&2; exit 64;;
esac
[ -f "$REQUEST_FILE" ] || { echo "request file not found: $REQUEST_FILE" >&2; exit 64; }

# Resolve bundled root WITHOUT changing the caller's cwd (so git diff targets the user repo).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF}"
# Persistent state. Prefer the plugin data dir; if Claude Code didn't export it
# (observed: CLAUDE_PLUGIN_DATA can be unset in slash-command Bash), fall back to a
# STABLE home path — NOT $ROOT/.data, which is under the ephemeral versioned dir and
# would be lost on every plugin update.
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}"
. "$ROOT/lib/verdict.sh"

# Resolve the USER repo from the caller's cwd (no cd). Required, like the source tool.
REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo" >&2; exit 64; }

# Active verifiers: user override in DATA wins, else bundled default.
# (read-loop, not mapfile — works on macOS bash 3.2)
CONF="$DATA/verifiers.conf"; [ -f "$CONF" ] || CONF="$ROOT/verifiers.conf"
VERIFIERS=()
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue;; esac
  VERIFIERS+=("$line")
done < <(cat "$CONF" 2>/dev/null)

# Portable random nonce + repo key (xxd / shasum may be absent on minimal Linux).
REQID="$(head -c16 /dev/urandom 2>/dev/null | xxd -p 2>/dev/null | tr -d '\n')"
[ -n "$REQID" ] || REQID="$(head -c16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n')"
[ -n "$REQID" ] || REQID="$$-$(date +%s 2>/dev/null)"
if command -v shasum >/dev/null 2>&1; then
  KEY="$(printf '%s' "$REPO" | shasum -a 256 | cut -c1-16)"
elif command -v sha256sum >/dev/null 2>&1; then
  KEY="$(printf '%s' "$REPO" | sha256sum | cut -c1-16)"
else
  KEY="$(printf '%s' "$REPO" | cksum | tr -d ' ' | cut -c1-16)"
fi
RUN="$DATA/handoff/$KEY/run-$REQID"; mkdir -p "$RUN"
find "$DATA/handoff" -maxdepth 2 -name 'run-*' -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true

# Build the object under review against the resolved USER repo explicitly (git -C "$REPO"):
# tracked diff + untracked files (like the original pair tool), so reviews of newly added
# files are not empty. Scope modes skip the diff.
case "$MODE" in
  audit|diagnose) : ;;  # scope-centric; request carries SCOPE
  *)
    git -C "$REPO" --no-pager diff HEAD > "$RUN/diff.patch" 2>/dev/null || : > "$RUN/diff.patch"
    git -C "$REPO" ls-files --others --exclude-standard -z \
      | while IFS= read -r -d '' f; do
          git -C "$REPO" --no-pager diff --no-index -- /dev/null "$f" >> "$RUN/diff.patch" 2>/dev/null || true
        done ;;
esac

# Compose the per-verifier prompt = VERIFIER.md + request + nonce + repo context.
PROMPT="$RUN/prompt.txt"
{ cat "$ROOT/VERIFIER.md" 2>/dev/null || true
  cat "$REQUEST_FILE"
  printf '\nREQUEST_ID: %s\n' "$REQID"
  [ -s "$RUN/diff.patch" ] && printf 'DIFF_PATCH: %s\n' "$RUN/diff.patch"
  printf 'REPO_ROOT: %s\n' "$REPO"
} > "$PROMPT"

# Portable timeout: use timeout/gtimeout when available, else run WITHOUT a timeout.
# (macOS ships no `timeout`; a pure-bash fallback that backgrounds `sleep` leaks an fd
# into command substitution and hangs callers, so we intentionally skip it. Per-verifier
# timeout therefore requires coreutils `timeout`/`gtimeout`; without it, an adapter relies
# on its own CLI limits — documented degradation.)
_with_timeout() {
  local t="$1"; shift
  if   command -v timeout  >/dev/null 2>&1; then timeout  "$t" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$t" "$@"
  else "$@"; fi
}

T="${AGENT_COMPANION_TIMEOUT:-180}"
if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
  echo "agent-companion: no 'timeout'/'gtimeout' on PATH — per-verifier timeout is DISABLED" \
       "(relying on each CLI's own limits; a hung CLI can stall the panel)." \
       "Install coreutils for a hard cap." >&2
fi

# --- synthesizer helpers (consolidate N verdicts into one, off-context) ---
synth_available() { # <name>
  case "$1" in
    claude) command -v claude >/dev/null 2>&1 ;;
    *) [ -f "$ROOT/adapters/$1.sh" ] && bash "$ROOT/adapters/$1.sh" probe >/dev/null 2>&1 ;;
  esac
}
run_synth() { # <name> <prompt-file> <out-file>
  local n="$1" p="$2" o="$3"
  if [ "$n" = claude ]; then
    _with_timeout "$T" claude -p "$(cat "$p")" --allowedTools "Read Grep Glob" > "$o" 2>"$RUN/synth.stderr.log"
  else
    _with_timeout "$T" bash "$ROOT/adapters/$n.sh" run "$p" "$EFFORT" "$o" 2>"$RUN/synth.stderr.log"
  fi
}

# Probe synchronously and partition (fail-closed): runlist = probe 0; skiplist = probe 64
# (unavailable → graceful degrade); faillist = missing adapter OR any other probe code.
runlist=(); skiplist=(); faillist=()
if [ "${#VERIFIERS[@]}" -gt 0 ]; then
  for v in "${VERIFIERS[@]}"; do
    ad="$ROOT/adapters/$v.sh"
    if [ ! -f "$ad" ]; then faillist+=("$v:no-adapter"); continue; fi
    bash "$ad" probe >/dev/null 2>&1; prc=$?
    if   [ "$prc" -eq 0 ];  then runlist+=("$v")
    elif [ "$prc" -eq 64 ]; then skiplist+=("$v")
    else faillist+=("$v:probe-rc-$prc"); fi
  done
fi

# Run probe-OK verifiers in parallel, each in its own dir with a (portable) timeout.
if [ "${#runlist[@]}" -gt 0 ]; then
  for v in "${runlist[@]}"; do
    vdir="$RUN/$v"; mkdir -p "$vdir"
    # capture adapter/CLI stderr to a per-verifier log (on disk) so a silent failure
    # like a rejected CLI flag is diagnosable instead of an empty FAIL.
    ( _with_timeout "$T" bash "$ROOT/adapters/$v.sh" run "$PROMPT" "$EFFORT" "$vdir/verdict" 2>"$vdir/stderr.log"; echo $? > "$vdir/rc" ) &
  done
  wait
fi

# Classify each ran verifier (rc!=0/timeout => FAIL, fail-closed); record class to a
# file; build the COMPACT status lines (one per verifier) that always go to context.
overall_changes=0; overall_fail=0
status="$RUN/status.txt"; : > "$status"
if [ "${#runlist[@]}" -gt 0 ]; then
  for v in "${runlist[@]}"; do
    rc="$(cat "$RUN/$v/rc" 2>/dev/null || echo 1)"
    if [ "$rc" != 0 ]; then cls=FAIL; else cls="$(classify_verdict "$RUN/$v/verdict" "$REQID" "$MODE")"; fi
    printf '%s' "$cls" > "$RUN/$v/cls"
    printf '[%s] %s\n' "$v" "$cls" >> "$status"
    [ "$cls" = CHANGES ] && overall_changes=1
    [ "$cls" = FAIL ] && overall_fail=1
  done
fi
if [ "${#faillist[@]}" -gt 0 ]; then
  overall_fail=1
  for f in "${faillist[@]}"; do printf '[%s] FAIL (%s)\n' "${f%%:*}" "${f#*:}" >> "$status"; done
fi
if [ "${#skiplist[@]}" -gt 0 ]; then
  for s in "${skiplist[@]}"; do printf '[%s] SKIP (unavailable)\n' "$s" >> "$status"; done
fi
# "Considered" = anything not skipped (run or failed-probe). Only an all-skipped panel is exit 64.
considered_count=$(( ${#runlist[@]} + ${#faillist[@]} ))

emit_bodies() { # <only-nonpass:0|1>
  local v cls only="$1"
  for v in "${runlist[@]}"; do
    cls="$(cat "$RUN/$v/cls" 2>/dev/null)"
    [ "$only" = 1 ] && [ "$cls" = PASS ] && continue
    printf '\n--- %s (%s) ---\n' "$v" "$cls"; cat "$RUN/$v/verdict" 2>/dev/null
  done
  printf '\n(full verdicts on disk: %s/<verifier>/verdict)\n' "$RUN"
}

# Compact status always first.
cat "$status"

# Detail / synthesis. Synthesizer only kicks in with >=2 reports (1 is already "consolidated").
SYNTH=""; SCONF="$DATA/synthesizer.conf"; [ -f "$SCONF" ] && SYNTH="$(head -n1 "$SCONF" | tr -d '[:space:]')"
nreports=${#runlist[@]}

# Only valid (non-FAIL) verdicts are eligible for consolidation. A FAIL verdict
# (rc!=0, empty, or wrong format) carries no trustworthy findings and must not
# pollute the synthesized report; it is surfaced separately below.
synthlist=()
for v in "${runlist[@]}"; do
  [ "$(cat "$RUN/$v/cls" 2>/dev/null)" = FAIL ] || synthlist+=("$v")
done
nsynth=${#synthlist[@]}

if [ "$nsynth" -ge 2 ] && [ -n "$SYNTH" ] && [ "$SYNTH" != none ] && synth_available "$SYNTH"; then
  sp="$RUN/synth-prompt.txt"
  { printf 'You are consolidating independent %s reports from several agents into ONE report.\n' "$MODE"
    # %s\n form, NOT a bare format string: several rule lines begin with "-", which
    # printf would otherwise parse as an option flag.
    printf '%s\n' \
      'Rules:' \
      '- Keep EVERY distinct finding. Merge only TRUE duplicates; never drop a unique issue.' \
      '- Tag each finding with its source agent(s) and a locator (file:line, or a short quote/id)' \
      '  so a reader can find it in the raw report without re-reading everything.' \
      '- Group by file/severity; note where agents agree vs disagree; end with one overall takeaway.' \
      '- Do not invent anything beyond the reports.' \
      ''
    for v in "${synthlist[@]}"; do
      printf -- '--- %s (%s) ---\n' "$v" "$(cat "$RUN/$v/cls" 2>/dev/null)"
      cat "$RUN/$v/verdict" 2>/dev/null; printf '\n'
    done
  } > "$sp"
  if run_synth "$SYNTH" "$sp" "$RUN/consolidated.txt" && [ -s "$RUN/consolidated.txt" ]; then
    printf '\n=== consolidated report (by %s · %s agents) ===\n' "$SYNTH" "$nsynth"
    cat "$RUN/consolidated.txt"
    printf '\n(raw per-verifier verdicts for drill-down: %s/<verifier>/verdict)\n' "$RUN"
    # FAIL verdicts were excluded from the consolidation; surface them directly so a
    # review block (or a misbehaving adapter) isn't hidden behind the summary.
    for v in "${runlist[@]}"; do
      [ "$(cat "$RUN/$v/cls" 2>/dev/null)" = FAIL ] || continue
      printf '\n--- %s (FAIL — excluded from consolidation) ---\n' "$v"; cat "$RUN/$v/verdict" 2>/dev/null
    done
  else
    printf '\n(synthesizer "%s" unavailable/failed — showing reports directly)\n' "$SYNTH"
    case "$MODE" in review) emit_bodies 1 ;; *) emit_bodies 0 ;; esac
  fi
elif [ "$nreports" -eq 1 ]; then
  v="${runlist[0]}"; printf '\n--- %s (%s) ---\n' "$v" "$(cat "$RUN/$v/cls" 2>/dev/null)"; cat "$RUN/$v/verdict" 2>/dev/null
elif [ "$nreports" -ge 2 ]; then
  # No synthesizer: review needs only the actionable (non-PASS); consult/audit/diagnose
  # need every report (the advice/findings/diagnosis ARE the deliverable).
  case "$MODE" in review) emit_bodies 1 ;; *) emit_bodies 0 ;; esac
fi

# Exit code stays deterministic from raw classifications (NOT the synthesizer text).
if [ "$considered_count" -eq 0 ]; then
  echo "no verifier available — review skipped" >&2; exit 64
fi
case "$MODE" in
  review)
    if [ "$overall_fail" = 1 ] || [ "$overall_changes" = 1 ]; then exit 10; fi
    exit 0;;
  *) # consult/audit/diagnose are non-gating; an agent FAIL is reported, not fatal
    exit 0;;
esac
