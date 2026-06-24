#!/usr/bin/env bash
set -uo pipefail
MODE="${1:?usage: verify.sh <mode> <effort> <request-file>}"
EFFORT="${2:?missing effort}"
REQUEST_FILE="${3:?missing request-file}"

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

REQID="$(head -c16 /dev/urandom | xxd -p)"
KEY="$(printf '%s' "$REPO" | shasum -a 256 | cut -c1-16)"
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
    ( _with_timeout "$T" bash "$ROOT/adapters/$v.sh" run "$PROMPT" "$EFFORT" "$vdir/verdict"; echo $? > "$vdir/rc" ) &
  done
  wait
fi

# Aggregate. run rc!=0 (incl. timeout) => FAIL regardless of verdict content (fail-closed).
overall_changes=0; overall_fail=0
summary="$RUN/summary.txt"; : > "$summary"
if [ "${#runlist[@]}" -gt 0 ]; then
  for v in "${runlist[@]}"; do
    rc="$(cat "$RUN/$v/rc" 2>/dev/null || echo 1)"
    if [ "$rc" != 0 ]; then cls=FAIL; else cls="$(classify_verdict "$RUN/$v/verdict" "$REQID" "$MODE")"; fi
    printf '[%s] %s\n' "$v" "$cls" >> "$summary"
    [ "$cls" = CHANGES ] && overall_changes=1
    [ "$cls" = FAIL ] && overall_fail=1
    # Always include each verifier's verdict body so Claude can synthesize a consult
    # advice panel / union audit findings (not only on non-PASS).
    { echo "--- $v ($cls) ---"; cat "$RUN/$v/verdict" 2>/dev/null; echo; } >> "$summary"
  done
fi
if [ "${#faillist[@]}" -gt 0 ]; then
  overall_fail=1
  for f in "${faillist[@]}"; do printf '[%s] FAIL (%s)\n' "${f%%:*}" "${f#*:}" >> "$summary"; done
fi
if [ "${#skiplist[@]}" -gt 0 ]; then
  for s in "${skiplist[@]}"; do printf '[%s] SKIP (unavailable)\n' "$s" >> "$summary"; done
fi
# "Considered" = anything not skipped (run or failed-probe). Only an all-skipped panel is exit 64.
considered_count=$(( ${#runlist[@]} + ${#faillist[@]} ))

cat "$summary"

if [ "$considered_count" -eq 0 ]; then
  echo "no verifier available — review skipped" >&2; exit 64
fi
case "$MODE" in
  review)
    if [ "$overall_fail" = 1 ] || [ "$overall_changes" = 1 ]; then exit 10; fi
    exit 0;;
  *) # consult/audit are non-gating; FAIL of an agent is reported, not fatal
    exit 0;;
esac
