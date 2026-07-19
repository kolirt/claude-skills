#!/usr/bin/env bash
set -uo pipefail

# Resolve bundled root WITHOUT changing the caller's cwd (so git diff targets the user repo).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF}"
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}"
. "$ROOT/lib/verdict.sh"
. "$ROOT/lib/spec.sh"
# Per-verifier hard cap, seconds. A generous SAFETY NET, not a pacing tool: it wraps BOTH
# retry attempts of an adapter, and honest reviews run 4-12 min (codex 169-688s observed,
# grok ~290s) — anything still alive past 30 min is hung, not slow.
T="${AGENT_COMPANION_TIMEOUT:-1800}"

# run_adapter <timeout> <adapter-sh> <prompt> <effort> <out> <model> <stderr-log>
# Invoke an adapter's `run`, passing the model as a 4th arg ONLY when non-empty (a bare
# spec keeps the exact 3-arg call contract). stdout silenced; diagnostics to the stderr log.
run_adapter() {
  local to="$1" sh="$2" p="$3" e="$4" o="$5" m="$6" errlog="$7"
  if [ -n "$m" ]; then
    _with_timeout "$to" bash "$sh" run "$p" "$e" "$o" "$m" >/dev/null 2>"$errlog"
  else
    _with_timeout "$to" bash "$sh" run "$p" "$e" "$o" >/dev/null 2>"$errlog"
  fi
}

# probe_adapter <adapter-sh> <model>  -> adapter's probe rc.
# Symmetric with run_adapter: pass the model ONLY when non-empty, so a bare entry keeps the
# original zero-arg `probe` contract (a strict custom adapter must not see a spurious "").
probe_adapter() {
  if [ -n "$2" ]; then bash "$1" probe "$2" >/dev/null 2>&1
  else                 bash "$1" probe        >/dev/null 2>&1; fi
}

# ---------- pure helpers ----------
gen_reqid() {
  local id
  id="$(head -c16 /dev/urandom 2>/dev/null | xxd -p 2>/dev/null | tr -d '\n')"
  [ -n "$id" ] || id="$(head -c16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  [ -n "$id" ] || id="$$-$(date +%s 2>/dev/null)"
  printf '%s' "$id"
}
repo_key() {
  if   command -v shasum    >/dev/null 2>&1; then printf '%s' "$1" | shasum -a 256 | cut -c1-16
  elif command -v sha256sum >/dev/null 2>&1; then printf '%s' "$1" | sha256sum    | cut -c1-16
  else printf '%s' "$1" | cksum | tr -d ' ' | cut -c1-16; fi
}
# argv-safe single-quote escaping for one literal (handles spaces, ", $, `, ')
sq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

manifest_get()  { awk -F'\t' -v k="$2" '$1==k{print $2; exit}' "$1/manifest" 2>/dev/null; }
manifest_list() { awk -F'\t' -v k="$2" '$1==k{print $2}'       "$1/manifest" 2>/dev/null; }
manifest_valid() {
  local m="$1/manifest" k
  [ -f "$m" ] || return 1
  for k in mode effort reqid repo root; do
    awk -F'\t' -v k="$k" '$1==k{f=1} END{exit f?0:1}' "$m" || return 1
  done
  return 0
}

validate_invocation() { # <mode> <request-file>
  case "$1" in review|consult|audit|diagnose|research) ;;
    *) echo "unknown mode: $1 (use review|consult|audit|diagnose|research)" >&2; exit 64;; esac
  [ -f "$2" ] || { echo "request file not found: $2" >&2; exit 64; }
}

read_verifiers() { # -> active verifier names, one per line
  local conf="$DATA/verifiers.conf"; [ -f "$conf" ] || conf="$ROOT/verifiers.conf"
  local line
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue;; esac
    printf '%s\n' "$line"
  done < <(cat "$conf" 2>/dev/null)
}

build_diff() { # <repo> <out>
  git -C "$1" --no-pager diff HEAD > "$2" 2>/dev/null || : > "$2"
  git -C "$1" ls-files --others --exclude-standard -z \
    | while IFS= read -r -d '' f; do
        git -C "$1" --no-pager diff --no-index -- /dev/null "$f" >> "$2" 2>/dev/null || true
      done
}

# resolve_path <path> -> prints the symlink-resolved absolute path on stdout, rc 0.
# rc 1 if no resolver is available or resolution fails (caller treats as reject).
resolve_path() {
  local p="$1" r
  if command -v readlink >/dev/null 2>&1 && r="$(readlink -f -- "$p" 2>/dev/null)" && [ -n "$r" ]; then
    printf '%s' "$r"; return 0
  fi
  if command -v realpath >/dev/null 2>&1 && r="$(realpath -- "$p" 2>/dev/null)" && [ -n "$r" ]; then
    printf '%s' "$r"; return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    r="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null)" \
      && [ -n "$r" ] && { printf '%s' "$r"; return 0; }
  fi
  return 1
}

# freeze_skills <request-file> <run-dir>
# Parses a `SKILL_FILES:` block (grammar: starts at a literal `SKILL_FILES:` line, consumes
# subsequent `^[[:space:]]*-[[:space:]]+<path>` lines, stops at the first non-matching line)
# and freezes each accepted file into <run>/skills/NN-<basename>. No block -> no-op (and no
# skills/ dir), which keeps build_prompt's output byte-identical for old-style requests.
freeze_skills() {
  local req="$1" run="$2" skilldir="$run/skills"
  local in_block=0 idx=0 total=0 line path resolved base dest size
  local -a seen=()
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_block" -eq 0 ]; then
      [ "$line" = "SKILL_FILES:" ] && in_block=1
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*)$ ]]; then
      path="${BASH_REMATCH[1]}"
      path="${path%"${path##*[![:space:]]}"}"   # strip trailing whitespace only
    else
      in_block=0
      continue
    fi
    [ -n "$path" ] || continue
    case "$path" in "~/"*) path="${HOME}/${path#\~/}";; esac   # ~/ expansion, no eval
    case "$path" in
      /*) : ;;
      *) echo "agent-companion: SKILL_FILES: skip (not absolute): $path" >&2; continue;;
    esac
    if ! resolved="$(resolve_path "$path")"; then
      echo "agent-companion: SKILL_FILES: skip (unresolvable): $path" >&2; continue
    fi
    if [ ! -f "$resolved" ]; then
      echo "agent-companion: SKILL_FILES: skip (missing or not a regular file): $path" >&2; continue
    fi
    case "$resolved" in
      *.md) : ;;
      *) echo "agent-companion: SKILL_FILES: skip (resolved target is not .md): $path" >&2; continue;;
    esac
    local dup=0 s
    for s in "${seen[@]:-}"; do [ "$s" = "$resolved" ] && { dup=1; break; }; done
    if [ "$dup" -eq 1 ]; then
      echo "agent-companion: SKILL_FILES: skip (duplicate): $path" >&2; continue
    fi
    seen+=("$resolved")
    [ -d "$skilldir" ] || mkdir -p "$skilldir"
    idx=$((idx + 1))
    base="$(basename "$resolved")"
    dest="$skilldir/$(printf '%02d' "$idx")-$base"
    size="$(wc -c < "$resolved" 2>/dev/null | tr -d ' ')"; [ -n "$size" ] || size=0
    if [ "$size" -gt 65536 ]; then
      head -c 65536 "$resolved" > "$dest"
      printf '\n[truncated]\n' >> "$dest"
    else
      cp "$resolved" "$dest"
    fi
    total=$((total + size))
    echo "agent-companion: SKILL_FILES: accepted $resolved -> $(basename "$dest") (${size} bytes)" >&2
  done < "$req"
  [ "$idx" -gt 0 ] && \
    echo "agent-companion: SKILL_FILES: $idx file(s) frozen, ${total} bytes total" >&2
}

build_prompt() { # <mode> <req> <reqid> <repo> <run>
  { cat "$ROOT/VERIFIER.md" 2>/dev/null || true
    cat "$2"
    if [ -d "$5/skills" ]; then
      local f slug
      for f in "$5"/skills/*.md; do
        [ -e "$f" ] || continue
        slug="$(basename "$f" .md)"
        printf '\n=== SKILL: %s ===\n' "$slug"
        cat "$f"
        printf '\n=== END SKILL: %s ===\n' "$slug"
      done
    fi
    printf '\nREQUEST_ID: %s\n' "$3"
    [ -s "$5/diff.patch" ] && printf 'DIFF_PATCH: %s\n' "$5/diff.patch"
    printf 'REPO_ROOT: %s\n' "$4"
  } > "$5/prompt.txt"
}

_with_timeout() {
  local t="$1"; shift
  if   command -v timeout  >/dev/null 2>&1; then timeout  "$t" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$t" "$@"
  else "$@"; fi
}
warn_no_timeout() {
  if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
    echo "agent-companion: no 'timeout'/'gtimeout' on PATH — per-verifier timeout is DISABLED" \
         "(a hung CLI can stall the panel forever)." \
         "ASK THE USER to install it: brew install coreutils (macOS; provides gtimeout)." >&2
  fi
}

synth_available() {
  local a m
  case "$1" in
    claude) command -v claude >/dev/null 2>&1 ;;
    *) a="$(spec_adapter "$1")"; m="$(spec_model "$1")"
       spec_valid "$1" && [ -f "$ROOT/adapters/$a.sh" ] \
         && probe_adapter "$ROOT/adapters/$a.sh" "$m" ;;
  esac
}
run_synth() { # <name> <prompt-file> <out-file> <run>
  local n="$1" p="$2" o="$3" run="$4" eff a m seff
  eff="$(manifest_get "$run" effort)"; [ -n "$eff" ] || eff=medium  # frozen effort; medium fallback
  if [ "$n" = claude ]; then
    _with_timeout "$T" claude -p "$(cat "$p")" --allowedTools "Read Grep Glob" > "$o" 2>"$run/synth.stderr.log"
  else
    a="$(spec_adapter "$n")"; m="$(spec_model "$n")"
    seff="$(spec_effort "$n")"; [ -n "$seff" ] || seff="$eff"   # per-entry @effort overrides frozen
    run_adapter "$T" "$ROOT/adapters/$a.sh" "$p" "$seff" "$o" "$m" "$run/synth.stderr.log"
  fi
}

# ---------- emit (shared by cmd_run and, later, cmd_collect) ----------
# Status lines: one per verifier, exactly like the monolith's status.txt.
emit_status_lines() { # <run> <runnable_nl> <skip_nl> <fail_nl>
  # ORDER must match the monolith's status.txt: runnable -> fail -> skip.
  local run="$1" v cls
  while IFS= read -r v; do [ -n "$v" ] || continue
    cls="$(cat "$run/$v/cls" 2>/dev/null)"; printf '[%s] %s\n' "$v" "$cls"
  done <<EOF
$2
EOF
  while IFS= read -r v; do [ -n "$v" ] || continue
    printf '[%s] FAIL (%s)\n' "${v%%	*}" "${v#*	}"
  done <<EOF
$4
EOF
  while IFS= read -r v; do [ -n "$v" ] || continue
    printf '[%s] SKIP (unavailable)\n' "${v%%	*}"
  done <<EOF
$3
EOF
}

# Detail/synth/drill-down — ported from the monolith (lines 159-223 of the original).
emit_detail() { # <run> <mode> <synth> <runnable_nl>
  local run="$1" mode="$2" synth="$3" v cls
  # synthlist = non-FAIL runnable verdicts
  local synthlist=() nsynth=0
  while IFS= read -r v; do [ -n "$v" ] || continue
    [ "$(cat "$run/$v/cls" 2>/dev/null)" = FAIL ] || { synthlist+=("$v"); nsynth=$((nsynth+1)); }
  done <<EOF
$4
EOF
  local nrep=0; while IFS= read -r v; do [ -n "$v" ] && nrep=$((nrep+1)); done <<EOF
$4
EOF

  if [ "$nsynth" -ge 2 ] && [ -n "$synth" ] && [ "$synth" != none ] && synth_available "$synth"; then
    local sp="$run/synth-prompt.txt"
    { printf 'You are consolidating independent %s reports from several agents into ONE report.\n' "$mode"
      printf '%s\n' \
        'Rules:' \
        '- Keep EVERY distinct finding. Merge only TRUE duplicates; never drop a unique issue.' \
        '- Tag each finding with its source agent(s) and a locator (file:line, or a short quote/id)' \
        '  so a reader can find it in the raw report without re-reading everything.' \
        '- Group by file/severity; note where agents agree vs disagree; end with one overall takeaway.' \
        '- Do not invent anything beyond the reports.' \
        ''
      for v in "${synthlist[@]:-}"; do [ -n "$v" ] || continue
        printf -- '--- %s (%s) ---\n' "$v" "$(cat "$run/$v/cls" 2>/dev/null)"
        cat "$run/$v/verdict" 2>/dev/null; printf '\n'
      done
    } > "$sp"
    if run_synth "$synth" "$sp" "$run/consolidated.txt" "$run" && [ -s "$run/consolidated.txt" ]; then
      printf '\n=== consolidated report (by %s · %s agents) ===\n' "$synth" "$nsynth"
      cat "$run/consolidated.txt"
      printf '\n(raw per-verifier verdicts for drill-down: %s/<verifier>/verdict)\n' "$run"
      while IFS= read -r v; do [ -n "$v" ] || continue
        [ "$(cat "$run/$v/cls" 2>/dev/null)" = FAIL ] || continue
        printf '\n--- %s (FAIL — excluded from consolidation) ---\n' "$v"; cat "$run/$v/verdict" 2>/dev/null
      done <<EOF
$4
EOF
    else
      printf '\n(synthesizer "%s" unavailable/failed — showing reports directly)\n' "$synth"
      emit_bodies "$run" "$mode" "$4"
    fi
  elif [ "$nrep" -eq 1 ]; then
    while IFS= read -r v; do [ -n "$v" ] || continue
      printf '\n--- %s (%s) ---\n' "$v" "$(cat "$run/$v/cls" 2>/dev/null)"; cat "$run/$v/verdict" 2>/dev/null
    done <<EOF
$4
EOF
  elif [ "$nrep" -ge 2 ]; then
    emit_bodies "$run" "$mode" "$4"
  fi
}

emit_bodies() { # <run> <mode> <runnable_nl>   (review: only non-PASS; else all)
  local run="$1" mode="$2" v cls
  while IFS= read -r v; do [ -n "$v" ] || continue
    cls="$(cat "$run/$v/cls" 2>/dev/null)"
    [ "$mode" = review ] && [ "$cls" = PASS ] && continue
    printf '\n--- %s (%s) ---\n' "$v" "$cls"; cat "$run/$v/verdict" 2>/dev/null
  done <<EOF
$3
EOF
  printf '\n(full verdicts on disk: %s/<verifier>/verdict)\n' "$run"
}

emit_table() { # <run> <runnable_nl> <skip_nl> <fail_nl>
  # NOTE: lists arrive via command substitution (trailing newline stripped), so feed them
  # with `printf '%s\n'` — `printf '%s'` would drop the last line in a `while read` loop.
  local run="$1" v st
  printf '\n=== verdicts ===\n'
  printf '%s\n' "$2" | while IFS= read -r v; do [ -n "$v" ] || continue
    if [ -f "$run/$v/rc" ]; then st="$(cat "$run/$v/cls" 2>/dev/null)"; [ -n "$st" ] || st=MISSING
    else st=MISSING; fi
    printf '%s\t%s\t%s\n' "$v" "$st" "$run/$v/verdict"
  done
  printf '%s\n' "$3" | while IFS= read -r v; do [ -n "$v" ] || continue
    printf '%s\tSKIP\tn/a (%s)\n' "${v%%	*}" "${v#*	}"
  done
  printf '%s\n' "$4" | while IFS= read -r v; do [ -n "$v" ] || continue
    printf '%s\tFAIL\tn/a (%s)\n' "${v%%	*}" "${v#*	}"
  done
}

# ---------- subcommands ----------
cleanup_old() {
  [ -d "$DATA/handoff" ] || return 0
  local d
  while IFS= read -r d; do [ -n "$d" ] || continue
    if [ -f "$d/complete" ] && [ ! -f "$d/.inflight" ]; then rm -rf "$d"
    elif ! manifest_valid "$d"; then rm -rf "$d"; fi
  done < <(find "$DATA/handoff" -maxdepth 2 -name 'run-*' -type d -mtime +1 2>/dev/null)
}

cmd_prepare() {
  [ "$#" -ge 3 ] || { echo "usage: verify.sh prepare <mode> <effort> <request-file>" >&2; exit 64; }
  local mode="$1" effort="$2" req="$3"
  validate_invocation "$mode" "$req"
  warn_no_timeout   # prepare is the entry point the manager actually calls — warn where it is seen
  local repo; repo="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo" >&2; exit 64; }
  cleanup_old
  local reqid key run
  reqid="$(gen_reqid)"; key="$(repo_key "$repo")"
  run="$DATA/handoff/$key/run-$reqid"; mkdir -p "$run"
  : > "$run/.inflight"
  case "$mode" in review|consult) build_diff "$repo" "$run/diff.patch";; esac
  freeze_skills "$req" "$run"
  build_prompt "$mode" "$req" "$reqid" "$repo" "$run"

  # probe/partition (newline-delimited; entries may carry a TAB+reason)
  local v ad prc runnable="" skip="" fail=""
  while IFS= read -r v; do [ -n "$v" ] || continue
    if ! spec_valid "$v"; then
      # a rejected entry is arbitrary text — neutralise any TAB before it enters the
      # TAB-delimited fail record, so the manifest/stdout contract stays intact.
      vsafe="$(printf '%s' "$v" | tr '\t' ' ')"
      fail="$fail$vsafe	bad-spec
"; continue
    fi
    ad="$ROOT/adapters/$(spec_adapter "$v").sh"
    if [ ! -f "$ad" ]; then fail="$fail$v	no-adapter
"; continue; fi
    probe_adapter "$ad" "$(spec_model "$v")"; prc=$?
    if   [ "$prc" -eq 0 ];  then runnable="$runnable$v
"
    elif [ "$prc" -eq 64 ]; then skip="$skip$v	unavailable
"
    else fail="$fail$v	probe-rc-$prc
"; fi
  done < <(read_verifiers)

  local synth=none sconf="$DATA/synthesizer.conf"
  # trim only surrounding whitespace — stripping INNER spaces would silently "repair" a
  # malformed value (e.g. `codex:bad model` -> `codex:badmodel`) into something runnable.
  [ -f "$sconf" ] && synth="$(head -n1 "$sconf" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"; [ -n "$synth" ] || synth=none
  # a hand-edited synthesizer.conf is untrusted: anything that is not claude/none and not a
  # well-formed spec is disabled (never serialized into the TAB manifest, never run blindly).
  case "$synth" in none|claude) ;; *) spec_valid "$synth" || synth=none ;; esac

  # atomic manifest
  local m="$run/manifest.tmp"
  { printf 'mode\t%s\n' "$mode"
    printf 'effort\t%s\n' "$effort"
    printf 'reqid\t%s\n' "$reqid"
    printf 'repo\t%s\n' "$repo"
    printf 'root\t%s\n' "$ROOT"
    printf 'prompt\t%s\n' "$run/prompt.txt"
    [ -f "$run/diff.patch" ] && printf 'diff\t%s\n' "$run/diff.patch"
    printf 'timeout\t%s\n' "$T"
    printf 'synthesizer\t%s\n' "$synth"
    printf '%s' "$runnable" | while IFS= read -r v; do [ -n "$v" ] && printf 'runnable\t%s\n' "$v"; done
    printf '%s' "$skip"     | while IFS= read -r v; do [ -n "$v" ] && printf 'skip\t%s\n' "$v"; done
    printf '%s' "$fail"     | while IFS= read -r v; do [ -n "$v" ] && printf 'fail\t%s\n' "$v"; done
  } > "$m"
  mv "$m" "$run/manifest"

  # contract stdout (ordered: runnable, skip, fail)
  printf 'RUN_DIR\t%s\n' "$run"
  printf '%s' "$runnable" | while IFS= read -r v; do [ -n "$v" ] || continue
    printf 'RUNNABLE\t%s\n' "$v"
    printf 'SPAWN\t%s\tbash %s run-one %s %s\n' "$v" "$(sq "$ROOT/verify.sh")" "$(sq "$run")" "$(sq "$v")"
  done
  printf '%s' "$skip" | while IFS= read -r v; do [ -n "$v" ] && printf 'SKIP\t%s\n' "$v"; done
  printf '%s' "$fail" | while IFS= read -r v; do [ -n "$v" ] && printf 'FAIL\t%s\n' "$v"; done
}
cmd_run_one() {
  [ "$#" -ge 2 ] || { echo "usage: verify.sh run-one <run-dir> <verifier>" >&2; exit 64; }
  local run="$1" v="$2"
  manifest_valid "$run" || { echo "invalid run-dir/manifest: $run" >&2; exit 64; }
  manifest_list "$run" runnable | grep -qxF -- "$v" || { echo "verifier not in runnable: $v" >&2; exit 64; }
  local effort prompt to adapter model eff
  effort="$(manifest_get "$run" effort)"
  prompt="$(manifest_get "$run" prompt)"
  to="$(manifest_get "$run" timeout)"; [ -n "$to" ] || to="$T"
  # $v is the full spec (cli[:model][@effort]) — resolve the adapter/model and let a
  # per-entry @effort override the frozen dispatch effort.
  adapter="$(spec_adapter "$v")"; model="$(spec_model "$v")"
  eff="$(spec_effort "$v")"; [ -n "$eff" ] || eff="$effort"
  local vdir="$run/$v"; mkdir -p "$vdir"
  rm -f "$vdir/finished" "$vdir/rc"
  : > "$vdir/started"
  # adapter writes its verdict to the FILE; its stdout is silenced (no context leak),
  # diagnostics go to stderr.log. run-one itself prints nothing to stdout.
  run_adapter "$to" "$ROOT/adapters/$adapter.sh" "$prompt" "$eff" "$vdir/verdict" "$model" "$vdir/stderr.log"
  printf '%s' "$?" > "$vdir/rc.tmp"; mv "$vdir/rc.tmp" "$vdir/rc"
  : > "$vdir/finished"
  exit 0
}
cmd_collect() {
  [ "$#" -ge 1 ] || { echo "usage: verify.sh collect <run-dir>" >&2; exit 64; }
  local run="$1"
  manifest_valid "$run" || { echo "invalid run-dir/manifest: $run" >&2; exit 64; }
  local mode reqid synth
  mode="$(manifest_get "$run" mode)"; reqid="$(manifest_get "$run" reqid)"; synth="$(manifest_get "$run" synthesizer)"

  # rebuild partitions from manifest (newline-delimited; skip/fail carry TAB+reason)
  local runnable skip fail v
  runnable="$(manifest_list "$run" runnable)"
  skip="$(awk -F'\t' '$1=="skip"{print $2"\t"$3}' "$run/manifest")"
  fail="$(awk -F'\t' '$1=="fail"{print $2"\t"$3}' "$run/manifest")"

  # detect MISSING (runnable without rc) -> incomplete: minimal output, markers untouched.
  # Lists come from $(...) WITHOUT a trailing newline -> feed with `printf '%s\n'`, else a
  # `while read` loop drops the last line.
  local missing=""
  printf '%s\n' "$runnable" | { while IFS= read -r v; do [ -n "$v" ] || continue
      [ -f "$run/$v/rc" ] || printf '%s\n' "$v"; done; } > "$run/.missing.tmp"
  missing="$(cat "$run/.missing.tmp")"; rm -f "$run/.missing.tmp"
  if [ -n "$missing" ]; then
    printf '%s\n' "$missing" | while IFS= read -r v; do [ -n "$v" ] && printf 'MISSING\t%s\n' "$v"; done
    echo "INCOMPLETE" >&2
    echo "collect: incomplete — verifier(s) without rc" >&2
    exit 64
  fi

  # classify runnable (writes <v>/cls). overall_fail ALSO picks up the fail partition.
  local overall_changes=0 overall_fail=0 rc cls
  printf '%s\n' "$runnable" | { while IFS= read -r v; do [ -n "$v" ] || continue
      rc="$(cat "$run/$v/rc" 2>/dev/null || echo 1)"
      if [ "$rc" != 0 ]; then cls=FAIL; else cls="$(classify_verdict "$run/$v/verdict" "$reqid" "$mode")"; fi
      printf '%s' "$cls" > "$run/$v/cls"
    done; }
  printf '%s\n' "$runnable" | while IFS= read -r v; do [ -n "$v" ] || continue
    cls="$(cat "$run/$v/cls" 2>/dev/null)"
    [ "$cls" = CHANGES ] && echo CHANGES; [ "$cls" = FAIL ] && echo FAIL
  done > "$run/.flags.tmp"
  grep -q CHANGES "$run/.flags.tmp" && overall_changes=1
  grep -q FAIL    "$run/.flags.tmp" && overall_fail=1
  rm -f "$run/.flags.tmp"
  printf '%s' "$fail" | grep -q . && overall_fail=1   # probe-fail/no-adapter block (monolith parity)

  # legacy status lines ALWAYS emit first (incl. the all-skip case, for parity).
  emit_status_lines "$run" "$runnable" "$skip" "$fail"

  # considered_count == 0 (everything skipped) -> terminal NO_VERIFIER. Status already shown.
  local nrun nfail
  nrun="$(printf '%s\n' "$runnable" | grep -c .)"; nfail="$(printf '%s\n' "$fail" | grep -c .)"
  if [ $(( nrun + nfail )) -eq 0 ]; then
    echo "no verifier available — review skipped" >&2
    echo "NO_VERIFIER" >&2
    : > "$run/complete"; rm -f "$run/.inflight"
    exit 64
  fi

  # verdict table FIRST (clickable per-agent paths, visible without expanding the long
  # synthesis below), then bodies/synthesis.
  emit_table "$run" "$runnable" "$skip" "$fail"
  emit_detail "$run" "$mode" "$synth" "$runnable"

  # finalize markers (terminal result) and gate
  : > "$run/complete"; rm -f "$run/.inflight"
  case "$mode" in
    review) { [ "$overall_fail" = 1 ] || [ "$overall_changes" = 1 ]; } && exit 10; exit 0;;
    *) exit 0;;
  esac
}

cmd_run() {
  [ "$#" -ge 3 ] || { echo "usage: verify.sh run <mode> <effort> <request-file>" >&2; exit 64; }
  # prepare with contract stdout suppressed (we spawn run-one ourselves; no need to parse);
  # warn_no_timeout fires inside cmd_prepare.
  local out prc
  out="$(cmd_prepare "$@")"; prc=$?
  [ "$prc" -eq 0 ] || exit "$prc"
  local run; run="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
  # spawn run-one for each RUNNABLE synchronously, in parallel
  local v
  while IFS= read -r v; do [ -n "$v" ] || continue
    ( cmd_run_one "$run" "$v" ) >/dev/null 2>&1 &
  done < <(printf '%s\n' "$out" | awk -F'\t' '$1=="RUNNABLE"{print $2}')
  wait
  cmd_collect "$run"   # prints legacy superset + table, returns 0/10/64, finalizes markers
}

# ---------- dispatch ----------
CMD="${1:-}"
case "$CMD" in
  prepare) shift; cmd_prepare "$@";;
  run-one) shift; cmd_run_one "$@";;
  collect) shift; cmd_collect "$@";;
  run)     shift; cmd_run "$@";;
  review|consult|audit|diagnose|research) cmd_run "$@";;   # legacy 3-arg form
  '') echo "usage: verify.sh <prepare|run-one|collect|run> ... | <mode> <effort> <request-file>" >&2; exit 64;;
  *) echo "unknown subcommand/mode: $CMD" >&2; exit 64;;
esac
