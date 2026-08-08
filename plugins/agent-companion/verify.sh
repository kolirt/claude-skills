#!/usr/bin/env bash
set -uo pipefail

# Resolve bundled root WITHOUT changing the caller's cwd (so git diff targets the user repo).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF}"
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}"
. "$ROOT/lib/verdict.sh"
. "$ROOT/lib/panel.sh"
. "$ROOT/lib/metrics.sh"
# Per-verifier hard cap, seconds. A generous SAFETY NET, not a pacing tool: it wraps BOTH
# retry attempts of an adapter, and honest reviews run 4-12 min (codex 169-688s observed,
# grok ~290s) — anything still alive past 30 min is hung, not slow.
T="${AGENT_COMPANION_TIMEOUT:-1800}"

# run_adapter <timeout> <adapter-sh> <prompt> <effort> <out> <model> <stderr-log> [worktree] [read-roots]
# Invoke an adapter's `run`, passing the model as a 4th arg ONLY when non-empty (a bare
# spec keeps the exact 3-arg call contract). stdout silenced; diagnostics to the stderr log.
#
# The extra dirs travel as ENVIRONMENT variables, not as further arguments: the adapter contract
# is `run <prompt> <effort> <out> [model]` and every custom adapter on disk implements exactly
# that. An adapter that ignores the variables keeps working unchanged. Exported here rather
# than by each caller, and ALWAYS assigned (empty when there is none), so a value can never
# leak from one verifier's run into the next.
#
# TWO variables, because one of them is a published contract. AGENT_COMPANION_EXTRA_DIR keeps
# its exact original meaning — the declared WORKTREE, or empty — so a custom adapter written
# against it is untouched. AGENT_COMPANION_EXTRA_DIRS is the full read-root list, newline
# separated, WORKTREE first: the bundled adapters read that one. A path containing a newline is
# never admitted upstream (escaping_symlink_dirs drops it), so the separator is unambiguous.
run_adapter() {
  local to="$1" sh="$2" p="$3" e="$4" o="$5" m="$6" errlog="$7" dirs=""
  export AGENT_COMPANION_EXTRA_DIR="${8:-}"
  [ -n "${8:-}" ] && dirs="$8"
  [ -n "${9:-}" ] && dirs="${dirs:+$dirs$'\n'}$9"
  export AGENT_COMPANION_EXTRA_DIRS="$dirs"
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
# A runnable record is `runnable<TAB>label<TAB>adapter<TAB>model<TAB>effort`: the label is the
# entry's identity, the rest is data. This is what replaces re-parsing a spec string.
manifest_entry() { # <run> <label> -> adapter<TAB>model<TAB>effort
  awk -F'\t' -v l="$2" '$1=="runnable" && $2==l{print $3"\t"$4"\t"$5; exit}' "$1/manifest" 2>/dev/null
}
manifest_synth() { # <run> -> adapter<TAB>model<TAB>effort
  awk -F'\t' '$1=="synthesizer"{print $2"\t"$3"\t"$4; exit}' "$1/manifest" 2>/dev/null
}
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

# -> one record per active verifier: index<TAB>adapter<TAB>model<TAB>effort<TAB>label
# (panel.sh owns the JSON; everything below this line is TAB records as before.)
read_verifiers() { panel_verifiers; }

# available_adapters -> comma-separated basenames discovered on disk. Used in the
# removed-adapter warning: never hardcode the adapter list, it drifts.
available_adapters() {
  local a out=""
  for a in "$ROOT"/adapters/*.sh; do
    [ -f "$a" ] || continue
    out="$out, $(basename "$a" .sh)"
  done
  printf '%s' "${out#, }"
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

# root_exposable <resolved-abs-path> -> rc 0 when the path may be handed to a verifier as a read
# root, rc 1 when it is too broad. Refuses what is not "a snapshot of code" under any reading:
# `/`, `$HOME`, and any single-segment path (`/Users`, `/etc`).
# Defined ONCE and shared by every caller that widens a confined verifier's workspace: a second
# copy of this bar is a second place to get it wrong.
root_exposable() { # <resolved-abs-path>
  local resolved="$1" rest="${1#/}"
  [ "$resolved" = "/" ] && return 1
  [ "$resolved" = "$HOME" ] && return 1
  [ "$rest" = "${rest%%/*}" ] && return 1
  return 0
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
  if [ "$idx" -gt 0 ]; then
    echo "agent-companion: SKILL_FILES: $idx file(s) frozen, ${total} bytes total" >&2
  elif grep -q '^SKILL_FILES:[[:space:]]*$' "$req"; then
    # A block that yields NOTHING used to pass in silence, and the panel then reviewed with no
    # project conventions at all — indistinguishable from a request that supplied none. The
    # usual cause is bare paths: the grammar consumes only `- <path>` lines and stops at the
    # first line that is not one, so a whole block is dropped without any per-path skip message.
    echo "agent-companion: SKILL_FILES: block present but NO files were accepted — the panel" \
         "will run WITHOUT project conventions. Each path must be its own '- <absolute path>'" \
         "line directly under 'SKILL_FILES:'." >&2
  fi
}

# extra_workspace_dir <request-file>
# Prints ONE validated absolute directory — the snapshot the request asks the panel to judge,
# declared as a `WORKTREE: <absolute path>` line — or nothing when the request declares none.
# Unlike SKILL_FILES the line SURVIVES into the prompt: a verifier is told to read that tree,
# so it needs the path. This only makes the tree readable.
#
# WHY IT EXISTS: agy and codex run CONFINED — their workspace is exactly the repo (the caller's
# cwd) plus the run dir. A request that points the panel at a DETACHED WORKTREE — an audit of a
# PR head SHA, materialized under a temp dir — names code in neither, and the two behave very
# differently about it: codex silently judges what it can still read (the working tree, not the
# pinned snapshot), while agy dies outright — one denied read ends its run, it exits 0 having
# printed nothing, and the empty verdict is reported as FAIL. grok and kimi are unconfined and
# never noticed, which is why this presented as "agy is broken" rather than as a scope bug.
#
# FAIL CLOSED and never widen past ONE directory. This grants READ access to a tree the panel
# would otherwise not see, so it accepts only an absolute path that RESOLVES to an existing
# directory, and refuses the roots whose contents are not "a snapshot of code" under any
# reading: `/`, `$HOME`, and any single-segment path (`/Users`, `/etc`). A rejected value is
# reported and DROPPED — the panel then runs on the repo alone, exactly as it did before.
extra_workspace_dir() { # <request-file>
  local line path resolved
  # First occurrence wins; leading indentation allowed (the field is usually nested under
  # SCOPE). Everything after the colon is the path, trailing whitespace stripped.
  line="$(awk 'match($0, /^[[:space:]]*WORKTREE:[[:space:]]*/) {print substr($0, RLENGTH + 1); exit}' "$1")"
  [ -n "$line" ] || return 0
  path="${line%"${line##*[![:space:]]}"}"
  [ -n "$path" ] || return 0
  case "$path" in "~/"*) path="${HOME}/${path#\~/}";; esac   # ~/ expansion, no eval
  case "$path" in
    /*) : ;;
    *) echo "agent-companion: WORKTREE: ignored (not absolute): $path" >&2; return 0;;
  esac
  if ! resolved="$(resolve_path "$path")"; then
    echo "agent-companion: WORKTREE: ignored (unresolvable): $path" >&2; return 0
  fi
  if [ ! -d "$resolved" ]; then
    echo "agent-companion: WORKTREE: ignored (not a directory): $path" >&2; return 0
  fi
  if ! root_exposable "$resolved"; then
    echo "agent-companion: WORKTREE: refused (too broad to expose to a verifier): $resolved" >&2
    return 0
  fi
  # Emit the DECLARED path, not the resolved one, even though every check above ran on the
  # resolved form. The prompt carries the declared spelling (a verifier is told to read exactly
  # that), and a workspace root written differently from the path in the text is a permission
  # check waiting to fail: on macOS `mktemp -d` hands out /var/folders/… while resolution
  # returns /private/var/folders/… — the same directory under two names. Keeping both sides on
  # one spelling removes that class of mismatch, and grants nothing extra: a symlink still
  # lands on the same tree the resolved checks approved.
  echo "agent-companion: WORKTREE: accepted — verifier workspace extended (read-only) to $path" >&2
  printf '%s' "$path"
}

# escaping_symlink_dirs <root>...
# Prints, one absolute path per line, the RESOLVED targets of FIRST-LEVEL symlinks inside the
# given roots whose target directory lands OUTSIDE every root. Prints nothing when there are none.
#
# WHY IT EXISTS: a confined verifier's workspace is a set of directories, and confinement is
# enforced on REAL paths — agy runs under `--sandbox`, an OS-level jail. A symlink inside the repo
# therefore grants nothing on its own: `node_modules -> /elsewhere/node_modules` is NAMED inside
# the workspace but READ outside it, so every read through it needs a permission decision,
# headless mode auto-DENIES it, and for agy one denial ends the run with no output at all (see
# adapters/agy.sh). That is not a corner case — it is a monorepo's normal shape, and it made agy
# return an empty FAIL on a request that told the panel to read package sources under
# node_modules, while codex only complained and judged on.
#
# The targets are emitted RESOLVED, the opposite of extra_workspace_dir's declared-path rule and
# for the same underlying reason: here the declared spelling ("$repo/node_modules") is already
# inside the workspace by name and grants nothing, so only the real path can widen it.
#
# FAIL CLOSED, exactly as WORKTREE does. First-level entries only (no recursion); symlinks only;
# targets that are DIRECTORIES only (exposing a symlinked FILE would mean exposing its parent —
# far more than the link itself reaches); each target through root_exposable; at most $max of
# them. Every accepted target is announced on stderr — widening a verifier's workspace is never
# silent — and so is every one dropped by the cap.
#
# WHAT IT DOES NOT COVER, by design: a symlink deeper in the tree, and any path the REQUEST names
# that has nothing to do with the repo. Neither is a workspace problem — the request itself must
# stop naming paths the verifier cannot read.
escaping_symlink_dirs() { # <root>...
  local -a rroots=() out=()
  local r root entry resolved inside dup n=0 max=8
  for root in "$@"; do
    [ -n "$root" ] || continue
    r="$(resolve_path "$root")" || continue
    [ -d "$r" ] || continue
    rroots+=("$r")
  done
  [ "${#rroots[@]}" -gt 0 ] || return 0
  for root in "${rroots[@]}"; do
    for entry in "$root"/* "$root"/.*; do
      case "${entry##*/}" in .|..) continue;; esac
      # An unmatched glob stays literal here (no nullglob), and a literal `…/*` is not a symlink,
      # so this same test also discards it.
      [ -L "$entry" ] || continue
      resolved="$(resolve_path "$entry")" || continue
      [ -d "$resolved" ] || continue
      # A newline in a path would split into two roots downstream (the list is newline
      # separated). Drop it rather than emit something a reader would mis-parse.
      [[ "$resolved" == *$'\n'* ]] && continue
      inside=0
      for r in "${rroots[@]}"; do
        # The variable is QUOTED inside the pattern, so only the trailing `*` is a glob: a root
        # whose own name contains `*` or `?` still matches literally.
        case "$resolved/" in "$r"/*) inside=1; break;; esac
      done
      [ "$inside" -eq 1 ] && continue
      dup=0
      for r in "${out[@]:-}"; do [ "$r" = "$resolved" ] && { dup=1; break; }; done
      [ "$dup" -eq 1 ] && continue
      if ! root_exposable "$resolved"; then
        echo "agent-companion: symlink root refused (too broad to expose to a verifier):" \
             "$entry -> $resolved" >&2
        continue
      fi
      if [ "$n" -ge "$max" ]; then
        # Keep scanning instead of breaking: a cap that hides what it dropped reads as
        # "nothing else was there".
        echo "agent-companion: symlink root DROPPED (cap of $max reached): $entry -> $resolved" >&2
        continue
      fi
      out+=("$resolved"); n=$((n + 1))
      echo "agent-companion: symlink root accepted — verifier workspace extended (read-only)" \
           "to $resolved (via $entry)" >&2
    done
  done
  [ "${#out[@]}" -gt 0 ] && printf '%s\n' "${out[@]}"
  return 0
}

# strip_skill_files <request-file>
# Emits the request WITHOUT its `SKILL_FILES:` block, using the SAME grammar freeze_skills
# parses with (header line, then `^[[:space:]]*-[[:space:]]+<path>` lines, stopping at the
# first line that is not one). Everything else passes through byte-identical.
#
# WHY the paths must not survive into the prompt: their CONTENT is already spliced in below
# as `=== SKILL: ... ===` blocks, so nothing needs to be read from disk — but a verifier that
# SEES a path reaches for it anyway. Those paths live in the plugin cache, outside both dirs
# an adapter puts in the CLI's workspace (the repo and the run dir), so the read needs a
# permission decision that headless mode cannot prompt for and therefore auto-denies.
# For agy that is fatal: one denied read ends the run, it exits 0 having printed nothing, and
# the empty verdict is reported as FAIL. It presented as FLAKY because the block only kills a
# run when the model happens to reach for it — same prompt, same panel, different outcome.
# Fixed here rather than in agy.sh: no adapter benefits from these paths, and every CLI that
# followed them was doing a pointless disk read.
strip_skill_files() {
  awk '
    /^SKILL_FILES:[[:space:]]*$/ { skip = 1; next }
    skip && /^[[:space:]]*-[[:space:]]+/ { next }
    { skip = 0; print }
  ' "$1"
}

build_prompt() { # <mode> <req> <reqid> <repo> <run>
  { cat "$ROOT/VERIFIER.md" 2>/dev/null || true
    strip_skill_files "$2"
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

# synth_available <adapter> <model> -> 0 if that synthesizer can actually run right now.
synth_available() {
  local a="$1" m="${2:-}"
  case "$a" in
    none|'') return 1 ;;
    claude)  command -v claude >/dev/null 2>&1 ;;
    *) panel_valid_adapter "$a" && [ -f "$ROOT/adapters/$a.sh" ] \
         && probe_adapter "$ROOT/adapters/$a.sh" "$m" ;;
  esac
}
run_synth() { # <prompt-file> <out-file> <run>
  local p="$1" o="$2" run="$3" eff a m seff ws
  eff="$(manifest_get "$run" effort)"; [ -n "$eff" ] || eff=medium  # frozen effort; medium fallback
  # The synthesizer reads only the verdicts it is handed, but a confined CLI still needs the
  # same workspace: it may follow a `file:line` locator back to the snapshot to resolve a
  # disagreement between two agents.
  ws="$(manifest_get "$run" workspace)"
  IFS=$'\037' read -r a m seff < <(manifest_synth "$run" | panel_us)
  [ -n "${seff:-}" ] || seff="$eff"          # a per-entry effort overrides the frozen dispatch one
  if [ "$a" = claude ]; then
    _with_timeout "$T" claude -p "$(cat "$p")" --allowedTools "Read Grep Glob" > "$o" 2>"$run/synth.stderr.log"
  else
    run_adapter "$T" "$ROOT/adapters/$a.sh" "$p" "$seff" "$o" "${m:-}" "$run/synth.stderr.log" "$ws"
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
    # print the REAL reason: `removed-adapter` must not masquerade as `unavailable`,
    # they call for different user action.
    printf '[%s] SKIP (%s)\n' "${v%%	*}" "${v#*	}"
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

  local sa sm se
  IFS=$'\037' read -r sa sm se < <(manifest_synth "$run" | panel_us)
  if [ "$nsynth" -ge 2 ] && [ -n "$synth" ] && [ "$synth" != none ] && synth_available "$sa" "${sm:-}"; then
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
    if run_synth "$sp" "$run/consolidated.txt" "$run" && [ -s "$run/consolidated.txt" ]; then
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

# ---------- metrics ----------
# manifest_entry_meta <run> <label> -> adapter<TAB>model<TAB>effort for ANY partition.
# manifest_entry() answers the same question for runnable entries only, because run-one has no
# use for a skipped entry's model. The metrics do: "codex was unavailable nine times running" is
# exactly the kind of fact that decides a subscription.
manifest_entry_meta() { # <run> <label>
  awk -F'\t' -v l="$2" '$1=="entry" && $2==l{print $3"\t"$4"\t"$5; exit}' "$1/manifest" 2>/dev/null
}

# record_run_metrics <run>
# Appends one runs-row per panel entry and, when at least one entry actually produced a report,
# arms the scoring gate with a snapshot of those entries.
#
# CALLED ONLY WHERE `complete` IS WRITTEN — the two terminal exits of cmd_collect. The INCOMPLETE
# exit is deliberately NOT one of them: it is a retry state (the manager re-spawns the MISSING
# agents into the SAME run dir and collects again), and a row written there would be frozen by
# the idempotency check, permanently recording a verifier as having produced nothing when it went
# on to return a full report seconds later.
record_run_metrics() { # <run>
  local run="$1" reqid repo key mode
  reqid="$(manifest_get "$run" reqid)"
  repo="$(manifest_get "$run" repo)"
  mode="$(manifest_get "$run" mode)"
  [ -n "$reqid" ] && [ -n "$repo" ] || return 1
  key="$(repo_key "$repo")"

  local runnable skiplist labels
  runnable="$(manifest_list "$run" runnable)"
  skiplist="$(awk -F'\t' '$1=="skip"{print $2}' "$run/manifest")"
  labels="$(awk -F'\t' '$1=="entry"{print $2}' "$run/manifest")"
  # A run frozen before entry rows existed still records, with unknown adapter metadata.
  if [ -z "$labels" ]; then
    labels="$(printf '%s\n%s\n%s\n' "$runnable" "$skiplist" \
      "$(awk -F'\t' '$1=="fail"{print $2}' "$run/manifest")" | grep -v '^$')"
  fi

  local label a m e outcome cls snapshot="" rc=0
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    IFS=$'\037' read -r a m e < <(manifest_entry_meta "$run" "$label" | panel_us)
    [ -n "${a:-}" ] || a='-'
    if grep -qxF -- "$label" <<<"$runnable"; then
      outcome=report
      cls="$(cat "$run/$label/cls" 2>/dev/null)"; [ -n "$cls" ] || cls='-'
      snapshot="$snapshot$label	$a	${m:--}	${e:--}	$outcome
"
    elif grep -qxF -- "$label" <<<"$skiplist"; then
      outcome=skip; cls='-'
    else
      outcome=fail; cls='-'
    fi
    metrics_record_run "$key" "$reqid" "$mode" "$label" "$a" "${m:--}" "${e:--}" "$outcome" "$cls" \
      || { [ "$?" = 2 ] || rc=1; }
  done <<EOF
$labels
EOF

  if [ "$rc" != 0 ]; then
    echo "agent-companion: failed to record run metrics for $reqid — the gate stays DISARMED" \
         "(no metric, no scoring obligation)." >&2
    return 1
  fi
  # No report, nothing to grade: an all-skip or all-probe-fail run is already fully described by
  # its runs-rows. Arming the gate there would block the next prepare over a judgement nobody
  # can make.
  [ -n "$snapshot" ] || return 0
  if ! printf '%s' "$snapshot" | metrics_pending_write "$key" "$reqid" "$mode"; then
    # Loud, and on STDOUT: a silently unarmed gate is precisely the hole the gate exists to
    # close, and stderr is where this manager's protocol expects only diagnostics.
    printf '\nagent-companion: WARNING — could not arm the scoring gate for %s.\n' "$reqid"
    printf 'agent-companion: score this run manually, or the metrics will be missing it.\n'
    return 1
  fi
  return 0
}

# emit_scoring_required <run> — the copy-paste block the manager acts on.
# Addressed by REQID, never by run path: `cleanup_old` deletes the directory about a day later,
# and a printed command that stops working is worse than none.
emit_scoring_required() { # <run>
  local run="$1" reqid key repo label a m e outcome
  reqid="$(manifest_get "$run" reqid)"; repo="$(manifest_get "$run" repo)"
  [ -n "$reqid" ] && [ -n "$repo" ] || return 0
  key="$(repo_key "$repo")"
  local entries; entries="$(metrics_pending_entries "$key" "$reqid" 2>/dev/null)" || return 0
  [ -n "$entries" ] || return 0
  printf '\n=== scoring required ===\n'
  printf 'Record what each verifier was actually worth, then the gate clears:\n'
  while IFS=$'\t' read -r label a m e outcome; do
    [ -n "$label" ] || continue
    printf '  bash %s score %s --label %s --accepted N --rejected N --duplicate N --report useful|noise|empty|duplicate\n' \
      "$(sq "$ROOT/verify.sh")" "$(sq "$reqid")" "$(sq "$label")"
  done <<EOF
$entries
EOF
  printf '  (or, deliberately: bash %s score %s --skip [reason])\n' "$(sq "$ROOT/verify.sh")" "$(sq "$reqid")"
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
  local reqid key run
  key="$(repo_key "$repo")"
  # THE SCORING GATE — first, before cleanup_old, the run directory, the diff, or the skill
  # freeze. A blocked prepare must leave nothing behind, so it runs ahead of every side effect.
  #
  # Exit 65, NOT 64: every existing 64 in this file is documented in MANAGER.md as an
  # environment condition the manager should degrade past ("continue and tell the user the step
  # ran unverified"). A gate that exits 64 would be routed around by a manager following its
  # own protocol. 65 has no such history and is defined as a stop.
  local pending; pending="$(metrics_pending_list "$key")"
  if [ -n "$pending" ]; then
    echo "agent-companion: refusing to start — earlier panel run(s) in this repo were collected" >&2
    echo "agent-companion: but never scored, and unscored runs silently hollow out the metrics." >&2
    printf '%s\n' "$pending" | while IFS=$'\t' read -r _k r; do
      [ -n "$r" ] || continue
      echo "agent-companion:   $r — score it, or record a deliberate skip:" >&2
      echo "agent-companion:     bash $(sq "$ROOT/verify.sh") score $(sq "$r") --skip" >&2
    done
    echo "UNSCORED" >&2
    exit 65
  fi
  cleanup_old
  reqid="$(gen_reqid)"
  run="$DATA/handoff/$key/run-$reqid"; mkdir -p "$run"
  : > "$run/.inflight"
  case "$mode" in review|consult) build_diff "$repo" "$run/diff.patch";; esac
  freeze_skills "$req" "$run"
  build_prompt "$mode" "$req" "$reqid" "$repo" "$run"
  # Resolved once, at freeze time, and carried in the manifest: `run-one` runs in its own
  # process (a separate background task) and must not re-read — or re-trust — the request.
  local workspace; workspace="$(extra_workspace_dir "$req")"
  # Symlinks that leave the tree are resolved into read roots of their own, or a confined
  # verifier dies on the first read through one. Scanned from the roots an adapter actually adds:
  # the caller's cwd (which is what `--add-dir` receives), the repo top level, and the declared
  # snapshot. Frozen here with everything else — run-one must not re-scan a tree that may have
  # changed since prepare.
  local readroots; readroots="$(escaping_symlink_dirs "$PWD" "$repo" "$workspace")"

  panel_warn_legacy   # obsolete .conf files present -> loud notice, then bundled default

  # Read the panel BEFORE the probe loop and fail loudly if it cannot be read. Feeding the
  # loop straight from a process substitution would swallow the error: a malformed panel (or
  # a missing jq/python3) would look exactly like "no verifiers configured", and the run
  # would degrade to NO_VERIFIER — which the manager protocol treats as a benign environment
  # condition and proceeds WITHOUT verification. A broken config must never silently
  # disable the gate.
  local vrecs
  if ! vrecs="$(read_verifiers)"; then
    echo "agent-companion: cannot read the panel config — refusing to run unverified." >&2
    echo "agent-companion: check $(panel_file) (or run '/agent-companion:verifiers list')." >&2
    exit 64
  fi

  # probe/partition. Entries arrive as panel records (index/adapter/model/effort/label);
  # runnable carries the full record, skip/fail carry `label<TAB>reason`. Identity is the
  # LABEL everywhere — the model text is data and never becomes a path or a key.
  # `entries` is a parallel record of EVERY panel entry — runnable, skipped and probe-failed
  # alike — carrying adapter/model/effort for each. The skip/fail partitions above deliberately
  # stay `label<TAB>reason` (emit_status_lines and emit_table split on the first TAB and would
  # mis-render a wider record), so the metadata the metrics need lives in its own manifest row
  # rather than being crammed into theirs.
  local idx a m e label ad prc runnable="" skip="" fail="" entries=""
  while IFS=$'\037' read -r idx a m e label; do
    [ -n "$label" ] || continue
    if [ -z "$a" ]; then
      # panel.sh emits an empty adapter for an entry that failed validation.
      fail="$fail$label	invalid-entry
"
      entries="$entries$label	-	-	-
"; continue
    fi
    entries="$entries$label	$a	$m	$e
"
    ad="$ROOT/adapters/$a.sh"
    if [ ! -f "$ad" ]; then
      # A configured verifier whose adapter file is gone (renamed/removed between releases)
      # is a CONFIG problem, not a review failure: SKIP it so review gates keep working,
      # and tell the user exactly how to clean it up.
      skip="$skip$label	removed-adapter
"
      echo "agent-companion: verifier #$idx ($label) refers to adapter \"$a\", which no longer exists — SKIPPED." >&2
      echo "agent-companion: remove it with '/agent-companion:verifiers remove $idx'." >&2
      echo "agent-companion: adapters currently available: $(available_adapters)" >&2
      continue
    fi
    probe_adapter "$ad" "$m"; prc=$?
    if   [ "$prc" -eq 0 ];  then runnable="$runnable$idx	$a	$m	$e	$label
"
    elif [ "$prc" -eq 64 ]; then skip="$skip$label	unavailable
"
    else fail="$fail$label	probe-rc-$prc
"; fi
  done < <(printf '%s\n' "$vrecs" | panel_us)

  local synth sm se
  IFS=$'\037' read -r synth sm se < <(panel_synth | panel_us)
  [ -n "${synth:-}" ] || synth=none

  # atomic manifest
  local m="$run/manifest.tmp"
  { printf 'mode\t%s\n' "$mode"
    printf 'effort\t%s\n' "$effort"
    printf 'reqid\t%s\n' "$reqid"
    printf 'repo\t%s\n' "$repo"
    printf 'root\t%s\n' "$ROOT"
    printf 'prompt\t%s\n' "$run/prompt.txt"
    [ -f "$run/diff.patch" ] && printf 'diff\t%s\n' "$run/diff.patch"
    [ -n "$workspace" ] && printf 'workspace\t%s\n' "$workspace"
    # Multi-valued, like `runnable`: one line per extra read root, order preserved.
    [ -n "$readroots" ] && printf '%s\n' "$readroots" \
      | while IFS= read -r v; do [ -n "$v" ] && printf 'readroot\t%s\n' "$v"; done
    printf 'timeout\t%s\n' "$T"
    printf 'synthesizer\t%s\t%s\t%s\n' "$synth" "${sm:-}" "${se:-}"
    # runnable record: label<TAB>adapter<TAB>model<TAB>effort (label first — it is the key
    # every other reader addresses the entry by; the rest is data carried along).
    printf '%s' "$runnable" | panel_us | while IFS=$'\037' read -r idx a m e label; do
      [ -n "$label" ] && printf 'runnable\t%s\t%s\t%s\t%s\n' "$label" "$a" "$m" "$e"; done
    printf '%s' "$skip"     | while IFS= read -r v; do [ -n "$v" ] && printf 'skip\t%s\n' "$v"; done
    printf '%s' "$fail"     | while IFS= read -r v; do [ -n "$v" ] && printf 'fail\t%s\n' "$v"; done
    # entry record: label<TAB>adapter<TAB>model<TAB>effort, for every partition. Purely
    # additive — manifest_valid does not require it, so a run frozen by an older version still
    # collects (it simply records no adapter/model against its metrics).
    printf '%s' "$entries"  | while IFS= read -r v; do [ -n "$v" ] && printf 'entry\t%s\n' "$v"; done
  } > "$m"
  mv "$m" "$run/manifest"

  # contract stdout (ordered: runnable, skip, fail) — addressed by label
  printf 'RUN_DIR\t%s\n' "$run"
  printf '%s' "$runnable" | panel_us | while IFS=$'\037' read -r idx a m e label; do [ -n "$label" ] || continue
    printf 'RUNNABLE\t%s\n' "$label"
    printf 'SPAWN\t%s\tbash %s run-one %s %s\n' "$label" "$(sq "$ROOT/verify.sh")" "$(sq "$run")" "$(sq "$label")"
  done
  printf '%s' "$skip" | while IFS= read -r v; do [ -n "$v" ] && printf 'SKIP\t%s\n' "$v"; done
  printf '%s' "$fail" | while IFS= read -r v; do [ -n "$v" ] && printf 'FAIL\t%s\n' "$v"; done
}
cmd_run_one() {
  [ "$#" -ge 2 ] || { echo "usage: verify.sh run-one <run-dir> <verifier>" >&2; exit 64; }
  local run="$1" v="$2"
  manifest_valid "$run" || { echo "invalid run-dir/manifest: $run" >&2; exit 64; }
  # Herestring, not a pipe: `grep -q` exits on the first match and SIGPIPEs `manifest_list`,
  # which `pipefail` (set at the top of this file) would surface as 141 — rejecting a verifier
  # that IS runnable. This runs on every single spawn, so the race must not exist here at all.
  local runnable_list; runnable_list="$(manifest_list "$run" runnable)" || true
  grep -qxF -- "$v" <<<"$runnable_list" || { echo "verifier not in runnable: $v" >&2; exit 64; }
  local effort prompt to adapter model eff ws rr
  effort="$(manifest_get "$run" effort)"
  prompt="$(manifest_get "$run" prompt)"
  to="$(manifest_get "$run" timeout)"; [ -n "$to" ] || to="$T"
  ws="$(manifest_get "$run" workspace)"   # optional; empty for a request with no WORKTREE:
  rr="$(manifest_list "$run" readroot)"   # optional; newline-separated, empty when none
  # $v is the entry's LABEL — a generated, path-safe identity. Adapter/model/effort come
  # from the manifest as data; nothing is re-derived by parsing the name.
  IFS=$'\037' read -r adapter model eff < <(manifest_entry "$run" "$v" | panel_us)
  [ -n "${adapter:-}" ] || { echo "verifier not found in manifest: $v" >&2; exit 64; }
  [ -n "${eff:-}" ] || eff="$effort"           # a per-entry effort overrides the frozen one
  local vdir="$run/$v"; mkdir -p "$vdir"
  rm -f "$vdir/finished" "$vdir/rc"
  : > "$vdir/started"
  # adapter writes its verdict to the FILE; its stdout is silenced (no context leak),
  # diagnostics go to stderr.log. run-one itself prints nothing to stdout.
  run_adapter "$to" "$ROOT/adapters/$adapter.sh" "$prompt" "$eff" "$vdir/verdict" "$model" "$vdir/stderr.log" "$ws" "$rr"
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

  # Validate the serialized synthesizer UNCONDITIONALLY — not only on the path that would
  # actually use it. A synthesizer pinned to an adapter that has since been removed used to
  # be rejected in silence, and the run fell back to listing raw reports with no explanation.
  local _sa _sm _se
  IFS=$'\037' read -r _sa _sm _se < <(manifest_synth "$run" | panel_us)
  if [ -n "${_sa:-}" ] && [ "$_sa" != none ] && ! synth_available "$_sa" "${_sm:-}"; then
    echo "agent-companion: synthesizer \"$_sa\" is configured but not usable" \
         "(adapter missing, or its CLI is not installed/authenticated) — reports will be listed directly." >&2
    echo "agent-companion: pick another with '/agent-companion:synthesizer set <claude|adapter|none>'." >&2
  fi

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
  # Herestring rather than `printf | grep -q` (SIGPIPE + pipefail would drop a real failure
  # block). Kept as `grep -q .` rather than `[ -n "$fail" ]`: they disagree on whitespace-only
  # input, and this decides whether a probe failure escalates to an overall FAIL.
  grep -q . <<<"$fail" && overall_fail=1   # probe-fail/no-adapter block (monolith parity)

  # legacy status lines ALWAYS emit first (incl. the all-skip case, for parity).
  emit_status_lines "$run" "$runnable" "$skip" "$fail"

  # considered_count == 0 (everything skipped) -> terminal NO_VERIFIER. Status already shown.
  local nrun nfail
  nrun="$(printf '%s\n' "$runnable" | grep -c .)"; nfail="$(printf '%s\n' "$fail" | grep -c .)"
  if [ $(( nrun + nfail )) -eq 0 ]; then
    echo "no verifier available — review skipped" >&2
    echo "NO_VERIFIER" >&2
    : > "$run/complete"; rm -f "$run/.inflight"
    # Terminal, so it counts: a panel whose every entry was unavailable is exactly the evidence
    # "this subscription is not earning its keep" is made of. No report means no gate.
    record_run_metrics "$run" || true
    metrics_gc || true
    exit 64
  fi

  # verdict table FIRST (clickable per-agent paths, visible without expanding the long
  # synthesis below), then bodies/synthesis.
  emit_table "$run" "$runnable" "$skip" "$fail"
  emit_detail "$run" "$mode" "$synth" "$runnable"

  # finalize markers (terminal result) and gate
  : > "$run/complete"; rm -f "$run/.inflight"
  record_run_metrics "$run" || true
  emit_scoring_required "$run"
  metrics_gc || true
  case "$mode" in
    review) { [ "$overall_fail" = 1 ] || [ "$overall_changes" = 1 ]; } && exit 10; exit 0;;
    *) exit 0;;
  esac
}

score_usage() {
  cat >&2 <<'USAGE'
usage:
  verify.sh score <reqid|run-dir> --label <label> --accepted N --rejected N --duplicate N \
                  [--redundant N] [--dup-of <label>] \
                  [--top-severity blocker|major|minor|none] \
                  --report useful|noise|empty|duplicate [--note <text>] [--force]
  verify.sh score <reqid|run-dir> --skip [reason]

Records what one verifier's report was actually worth, and clears the scoring gate once every
verifier of the run has been accounted for.

--redundant is how many of the ACCEPTED findings you already had in your own audit before you
read the report. It answers "would I have missed this?", which --duplicate does not: --duplicate
only ever compares one verifier against ANOTHER verifier, never against you. Omit it and the row
records "not graded" rather than zero, and the run is left out of the new% column in stats.
USAGE
}

# score_resolve <target> -> prints repo_key<TAB>reqid, rc 1 when the run is unknown.
# Accepts a run directory (convenient while it still exists) or a bare reqid (which keeps
# working after cleanup_old has deleted the directory — this is the addressing that matters).
score_resolve() { # <target>
  local target="$1" reqid key
  if [ -d "$target" ] && [ -f "$target/manifest" ]; then
    reqid="$(manifest_get "$target" reqid)"
  else
    reqid="$target"
  fi
  [ -n "$reqid" ] || return 1
  if key="$(metrics_pending_find "$reqid")"; then
    printf '%s\t%s' "$key" "$reqid"; return 0
  fi
  # No pending marker: already scored, or scored-and-cleared. Only a --force re-score has any
  # business here, and it needs the repo key from the recorded history.
  if key="$(metrics_repo_for_reqid "$reqid")"; then
    printf '%s\t%s' "$key" "$reqid"; return 0
  fi
  return 1
}

# score_labels <repo_key> <reqid> -> the labels this run expects a score for.
score_labels() {
  local out
  if out="$(metrics_pending_entries "$1" "$2" 2>/dev/null)" && [ -n "$out" ]; then
    printf '%s\n' "$out" | cut -f1
    return 0
  fi
  metrics_labels_for_reqid "$2"
}

# score_maybe_clear <repo_key> <reqid> — clear the gate once every expected label is scored.
score_maybe_clear() {
  local key="$1" reqid="$2" label pendingleft=0
  metrics_pending_entries "$key" "$reqid" >/dev/null 2>&1 || return 0
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    metrics_has_row scores "$reqid" "$label" || pendingleft=1
  done < <(score_labels "$key" "$reqid")
  [ "$pendingleft" = 0 ] || return 0
  metrics_pending_clear "$key" "$reqid"
  echo "agent-companion: run $reqid fully scored — gate cleared." >&2
}

cmd_score() {
  [ "$#" -ge 2 ] || { score_usage; exit 64; }
  local target="$1"; shift
  local resolved key reqid
  resolved="$(score_resolve "$target")" || {
    echo "agent-companion: unknown run: $target" >&2
    echo "agent-companion: pass the REQUEST_ID printed by collect, or the run directory." >&2
    exit 64; }
  key="${resolved%%	*}"; reqid="${resolved#*	}"

  local label="" acc="" rej="" dup="" red="-" dupof="-" sev="none" report="" note="-" force=0 skip=0 reason=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --label)        label="${2:-}"; shift 2 || true;;
      --accepted)     acc="${2:-}"; shift 2 || true;;
      --rejected)     rej="${2:-}"; shift 2 || true;;
      --duplicate)    dup="${2:-}"; shift 2 || true;;
      --redundant)    red="${2:-}"; shift 2 || true;;
      --dup-of)       dupof="${2:-}"; shift 2 || true;;
      --top-severity) sev="${2:-}"; shift 2 || true;;
      --report)       report="${2:-}"; shift 2 || true;;
      --note)         note="${2:-}"; shift 2 || true;;
      --force)        force=1; shift;;
      --skip)         skip=1; shift; reason="${1:-}"; [ "$#" -gt 0 ] && shift;;
      *) echo "agent-companion: unknown argument: $1" >&2; score_usage; exit 64;;
    esac
  done

  local labels; labels="$(score_labels "$key" "$reqid")"
  [ -n "$labels" ] || { echo "agent-companion: run $reqid recorded no report to score." >&2; exit 64; }

  if [ "$skip" = 1 ]; then
    # A deliberate skip is DATA, not an absence of it: `source=skip` is what tells the stats
    # reader that these runs were waived rather than judged, so a panel graded mostly by shrugs
    # cannot masquerade as evidence.
    local n=0
    while IFS= read -r label; do
      [ -n "$label" ] || continue
      metrics_has_row scores "$reqid" "$label" && continue
      metrics_record_score "$key" "$reqid" "$label" 0 0 0 '-' none empty skip "${reason:--}" \
        || { echo "agent-companion: failed to record the skip for $label" >&2; exit 64; }
      n=$((n + 1))
    done <<EOF
$labels
EOF
    metrics_pending_clear "$key" "$reqid"
    echo "agent-companion: run $reqid skipped ($n verifier(s) recorded as unscored) — gate cleared." >&2
    exit 0
  fi

  [ -n "$label" ] || { echo "agent-companion: --label is required" >&2; score_usage; exit 64; }
  grep -qxF -- "$label" <<<"$labels" || {
    echo "agent-companion: \"$label\" is not a verifier of run $reqid. Expected one of:" >&2
    printf '%s\n' "$labels" | sed 's/^/agent-companion:   /' >&2
    exit 64; }
  local n
  for n in "$acc" "$rej" "$dup"; do
    case "$n" in ''|*[!0-9]*) echo "agent-companion: --accepted/--rejected/--duplicate must each be a non-negative integer" >&2; exit 64;; esac
  done
  case "$sev" in blocker|major|minor|none) ;;
    *) echo "agent-companion: --top-severity must be blocker|major|minor|none" >&2; exit 64;; esac
  case "$report" in useful|noise|empty|duplicate) ;;
    *) echo "agent-companion: --report must be useful|noise|empty|duplicate" >&2; exit 64;; esac
  # `-` (the default) means "not graded" and stays out of new%. Anything else must be a count,
  # and it cannot exceed --accepted: redundant findings are a SUBSET of the accepted ones, so a
  # larger value would make "accepted findings you did NOT already have" come out negative.
  if [ "$red" != '-' ]; then
    case "$red" in ''|*[!0-9]*)
      echo "agent-companion: --redundant must be a non-negative integer" >&2; exit 64;; esac
    [ "$red" -le "$acc" ] || {
      echo "agent-companion: --redundant ($red) cannot exceed --accepted ($acc) — it counts which of the ACCEPTED findings you already had." >&2
      exit 64; }
  fi
  if [ "$dupof" != '-' ]; then
    grep -qxF -- "$dupof" <<<"$labels" || {
      echo "agent-companion: --dup-of \"$dupof\" is not another verifier of this run" >&2; exit 64; }
    [ "$dupof" != "$label" ] || {
      echo "agent-companion: --dup-of cannot name the entry being scored" >&2; exit 64; }
  fi

  METRICS_FORCE="$force" metrics_record_score "$key" "$reqid" "$label" \
    "$acc" "$rej" "$dup" "$dupof" "$sev" "$report" manager "$note" "$red"
  case "$?" in
    0) echo "agent-companion: scored $label (accepted=$acc rejected=$rej duplicate=$dup redundant=$red report=$report)" >&2
       # Loud rather than fatal: a missing --redundant costs one run's worth of new%, while
       # rejecting the call would leave the gate armed and the run unscorable by an older manager.
       [ "$red" != '-' ] || echo "agent-companion: no --redundant given — this run is excluded from new% (how much the verifier found that you did not)." >&2;;
    2) echo "agent-companion: $label is already scored for run $reqid — pass --force to supersede it." >&2; exit 64;;
    *) echo "agent-companion: failed to record the score for $label" >&2; exit 64;;
  esac
  score_maybe_clear "$key" "$reqid"
  exit 0
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
  score)   shift; cmd_score "$@";;
  run)     shift; cmd_run "$@";;
  review|consult|audit|diagnose|research) cmd_run "$@";;   # legacy 3-arg form
  '') echo "usage: verify.sh <prepare|run-one|collect|score|run> ... | <mode> <effort> <request-file>" >&2; exit 64;;
  *) echo "unknown subcommand/mode: $CMD" >&2; exit 64;;
esac
