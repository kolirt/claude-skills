#!/usr/bin/env bash
# Single owner of the agent-companion panel configuration.
#
# The panel (verifiers + synthesizer) lives in ONE JSON document:
#
#   {
#     "version": 1,
#     "verifiers": [
#       { "adapter": "codex", "model": "gpt-5.6-sol", "effort": "high" },
#       { "adapter": "agy",   "model": "Gemini 3.5 Flash (Medium)", "effort": "" }
#     ],
#     "synthesizer": { "adapter": "none", "model": "", "effort": "" }
#   }
#
# WHY JSON and not the old `cli[:model][@effort]` line format: that grammar forced the
# model id to double as a path component and a manifest key, so it had to stay inside
# [A-Za-z0-9._-]. agy's model names ("Gemini 3.5 Flash (Medium)") contain spaces and
# parentheses and cannot be expressed at all. Here the model is DATA — identity is a
# separate generated label — so the name is stored verbatim.
#
# The JSON boundary stops here: every consumer downstream keeps its existing TAB/awk
# plumbing and only ever sees TAB-delimited records emitted by this file.
#
# Parsing uses `jq` with a `python3` fallback — the same chain as lib/grok-run.sh.
# Neither present is a hard, actionable error: the panel cannot be read at all.

# Callers (verify.sh, verifiers.sh, synthesizer.sh) set ROOT/DATA before sourcing;
# the defaults keep this file usable standalone (tests source it directly).
: "${ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"
: "${DATA:=${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}}"

PANEL_USER="$DATA/panel.json"
PANEL_DEFAULT="$ROOT/panel.json"

# panel_file -> the panel document actually in effect (user override, else bundled default).
# Presence is tested with -e OR -L, not -f: a user panel.json that exists but is unusable (a
# directory, a dangling symlink) must NOT read as "no override" and silently fall back to the
# bundled empty default — that is a fail-open that would quietly run with no verifiers.
# It is returned here and rejected by panel_readable below, so the failure is explicit.
panel_file() {
  if [ -e "$PANEL_USER" ] || [ -L "$PANEL_USER" ]; then printf '%s\n' "$PANEL_USER"
  else printf '%s\n' "$PANEL_DEFAULT"; fi
}
# panel_readable <file> -> 0 only for a regular, readable file.
panel_readable() { [ -f "$1" ] && [ -r "$1" ]; }

# ---------- legacy config detection ----------
# Old-format .conf files are NEVER read and NEVER migrated (deliberate hard break).
# Leaving them silently ignored would quietly shrink a user's panel back to the bundled
# default, so say so loudly, once, on stderr.
panel_warn_legacy() {
  local found=""
  [ -f "$DATA/verifiers.conf" ]   && found="$found $DATA/verifiers.conf"
  [ -f "$DATA/synthesizer.conf" ] && found="$found $DATA/synthesizer.conf"
  [ -n "$found" ] || return 0
  echo "agent-companion: IGNORING obsolete panel config:$found" >&2
  echo "agent-companion: the panel moved to JSON ($PANEL_USER) in 0.3.0 and old .conf files are NOT migrated." >&2
  # Only claim the bundled default when that is actually what is in effect — a user who has
  # already rebuilt their panel still has the stale .conf lying around, and telling them
  # their panel is empty would be false.
  if [ -f "$PANEL_USER" ]; then
    echo "agent-companion: your panel is being read from $PANEL_USER; the files above are just leftovers." >&2
    echo "agent-companion: delete them once you have confirmed the panel is right." >&2
  else
    echo "agent-companion: your panel is running on the BUNDLED DEFAULT until you rebuild it, e.g." >&2
    echo "agent-companion:   /agent-companion:verifiers add codex --effort high" >&2
    echo "agent-companion: delete the files above once you have rebuilt the panel." >&2
  fi
}

# ---------- validation (single implementation, shared by read and write paths) ----------
# adapter: unchanged from the old grammar — it is still a filename component (adapters/<a>.sh).
panel_valid_adapter() { case "$1" in ''|-*|*[!A-Za-z0-9_-]*) return 1;; esac; return 0; }
# model: free-form and stored verbatim. Control characters are the only hostile class — they
# would break the TAB-delimited records and the line-oriented manifest this file feeds.
panel_valid_model() {
  [ "${#1}" -le 200 ] || return 1
  # Mirrors the engine-boundary rule (jq fld() / python3 f()): no control characters at all.
  # TAB and newline would forge records; U+001F would forge fields (it is panel_us's IFS).
  case "$1" in *[[:cntrl:]]*) return 1;; esac
  return 0
}

# ---------- reading TAB records in bash ----------
# TAB is IFS *whitespace*, so `IFS=$'\t' read -r a b c` collapses runs of tabs and silently
# merges empty fields: `codex\t\thigh` (empty model) would read back as model=high. Every
# record here has optional empty fields, so that is a correctness bug, not a nicety.
# Translate TAB to \037 (unit separator, NOT IFS whitespace) just for the read.
# awk readers are unaffected — `awk -F'\t'` never collapses.
panel_us() { tr '\t' '\037'; }
panel_valid_effort() { case "$1" in ''|low|medium|high|xhigh|max) return 0;; *) return 1;; esac; }

# ---------- identity ----------
# panel_slug <text> -> lowercase, every run of non-alphanumerics collapsed to one '-'.
panel_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9][^a-z0-9]*/-/g' -e 's/^-*//' -e 's/-*$//'
}

# panel_label <index> <adapter> <model> <effort> -> the entry's IDENTITY.
# This is what becomes a run-directory name and a manifest key — never the raw model text.
# The index guarantees uniqueness when two entries share an adapter and model; the slug
# only keeps the path readable. Truncated so the component stays well under 255 bytes.
panel_label() {
  local idx="$1" slug
  slug="$(panel_slug "$2 $3 $4")"
  [ -n "$slug" ] || slug=entry
  printf '%s-%s' "$idx" "$(printf '%s' "$slug" | cut -c1-100)"
}

# ---------- model resolution (add time only, never on the verification hot path) ----------
# `models` is an OPTIONAL adapter subcommand printing one model display name per line.
# Adapters that can enumerate (agy) implement it; adapters that cannot (codex, grok) do not,
# and their models are stored exactly as typed.
#
# panel_models <adapter> -> the adapter's model list on stdout, rc 1 if it cannot enumerate.
panel_models() {
  local sh="$ROOT/adapters/$1.sh" list
  [ -f "$sh" ] || return 1
  list="$(bash "$sh" models 2>/dev/null)" || return 1
  [ -n "$list" ] || return 1
  printf '%s\n' "$list"
}

# panel_resolve_model <adapter> <input> -> canonical name on stdout.
#   rc 0  resolved            — store what was printed
#   rc 1  cannot enumerate    — store the input verbatim
#   rc 2  unknown/ambiguous   — reject and show the candidates (never guess, never fall back)
# The user speaks loosely ("gemini 3.5 flash medium"); both sides are slug-normalised so the
# stored value is the adapter's own spelling, resolved ONCE, here.
panel_resolve_model() {
  local a="$1" raw="$2" list line want hit="" n=0
  [ -n "$raw" ] || return 1
  list="$(panel_models "$a")" || return 1
  want="$(panel_slug "$raw")"
  # An input that normalises to nothing ("()", "---") must not fall through to prefix
  # matching, where the empty slug is a prefix of EVERY model and would "resolve" to the
  # first one whenever the list has a single entry.
  [ -n "$want" ] || return 2
  # exact match, counted: two models can share a slug, and picking the first silently would
  # pin a different model than the user meant.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ "$(panel_slug "$line")" = "$want" ] && { hit="$line"; n=$((n + 1)); }
  done <<EOF
$list
EOF
  [ "$n" -eq 1 ] && { printf '%s' "$hit"; return 0; }
  [ "$n" -gt 1 ] && return 2
  hit=""; n=0
  # no exact match — accept a prefix only when it is unambiguous
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$(panel_slug "$line")" in "$want"*) hit="$line"; n=$((n + 1));; esac
  done <<EOF
$list
EOF
  [ "$n" -eq 1 ] && { printf '%s' "$hit"; return 0; }
  return 2
}

# ---------- JSON engine ----------
panel_engine() {
  if   command -v jq      >/dev/null 2>&1; then printf 'jq\n'
  elif command -v python3 >/dev/null 2>&1; then printf 'python3\n'
  else return 1; fi
}
panel_require_engine() {
  panel_engine >/dev/null && return 0
  echo "agent-companion: cannot read the panel config — neither 'jq' nor 'python3' is on PATH." >&2
  echo "agent-companion: install one of them, e.g. 'brew install jq' (macOS) or 'apt install jq'." >&2
  return 1
}

# _panel_read <file> -> raw TAB records on stdout, rc 1 on unparseable/ill-shaped JSON:
#   V<TAB>adapter<TAB>model<TAB>effort   (one per verifier, in document order)
#   S<TAB>adapter<TAB>model<TAB>effort   (exactly one, always last)
# Structural checks live in the engine; value checks live in bash (panel_valid_*), so each
# rule has exactly one implementation regardless of which engine parsed the document.
# _panel_records_sane <record-text> -> 0 if the stream is exactly:
# zero or more V lines plus EXACTLY ONE S line, each with exactly 4 TAB-separated fields.
#
# This is the record protocol's integrity check, and it is load-bearing twice over:
#  - a JSON string value containing a newline would otherwise SPLIT into extra records, so a
#    hand-edited model like "x\nS\tgrok\t" could inject a synthesizer (the per-value charset
#    check in panel_valid_model runs after the split, far too late to prevent it);
#  - jq accepts several concatenated top-level documents where python3 rejects them, which
#    shows up here as more than one S record — so the two engines cannot silently disagree.
_panel_records_sane() {
  local line ns=0 nf
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      'V'$'\t'*) ;;
      'S'$'\t'*) ns=$((ns + 1)) ;;
      *) return 1 ;;
    esac
    nf="$(printf '%s' "$line" | awk -F'\t' '{print NF}')"
    [ "$nf" = 4 ] || return 1
    # No control characters INSIDE a field. TAB is the field separator and is expected;
    # anything else in the C0 range (notably U+001F, panel_us's IFS) would forge a field
    # once the record is read back. Checked here so the WRITE path is guarded too, not just
    # the engine read path.
    case "${line//$'\t'/}" in *[[:cntrl:]]*) return 1;; esac
  done <<EOF
$1
EOF
  [ "$ns" -eq 1 ] || return 1
  return 0
}

# _panel_read <file> — validated wrapper around the engine.
# The engine's EXIT CODE alone cannot be trusted: macOS /usr/bin/jq prints
# "parse error" and still exits 0. The record-stream shape is the reliable signal.
_panel_read() {
  local out
  out="$(_panel_read_engine "$1")" || return 1
  _panel_records_sane "$out" || return 1
  printf '%s\n' "$out"
}

_panel_read_engine() {
  local f="$1" err rc
  case "$(panel_engine)" in
    jq)
      err="$(mktemp)" || return 1
      # fld() enforces at the ENGINE boundary what the record protocol needs: a string, with
      # no TAB or newline. Doing it here (not after the split) is what stops a newline inside
      # a value from forging extra records. Rejecting non-strings also keeps jq and python3
      # in agreement — jq would otherwise coerce `false` to "" via `//` while python3 errors.
      env -u JQ_COLORS jq -r '
        def fld(v): (if v == null then "" else v end)
          | if type != "string" then error("non-string field")
            elif (explode | map(select(. < 32 or . == 127)) | length) > 0
              then error("field contains a control character")
            else . end;
        if type != "object" then error("root is not an object") else . end
        | if (.verifiers != null and (.verifiers|type) != "array")
            then error("verifiers is not an array") else . end
        | if (.synthesizer != null and (.synthesizer|type) != "object")
            then error("synthesizer is not an object") else . end
        | ((.verifiers // []) | map(
              if type != "object" then error("verifier entry is not an object") else . end
            | "V\t" + fld(.adapter) + "\t" + fld(.model) + "\t" + fld(.effort)))
          + [ (.synthesizer // {})
              | "S\t" + fld(.adapter) + "\t" + fld(.model) + "\t" + fld(.effort) ]
        | .[]
      ' "$f" 2>"$err"
      rc=$?
      # Apple's /usr/bin/jq exits 0 on a parse error AND still emits records for whatever it
      # parsed — `{...valid...} trailing` yields a perfectly shaped one-S stream that neither
      # the exit code nor the record shape catches, so jq's stderr is the only signal left.
      # Match the PARSE-ERROR text specifically, not "stderr is non-empty": jq also writes
      # unrelated diagnostics there (e.g. "Failed to set $JQ_COLORS" for a malformed
      # JQ_COLORS), and treating those as corruption would reject perfectly valid panels.
      # JQ_COLORS is additionally unset above, since it is the one such source we know of.
      if [ "$rc" -ne 0 ] || grep -qiE 'parse error|invalid (literal|numeric|character)|unfinished' "$err"
      then rm -f "$err"; return 1; fi
      rm -f "$err"
      ;;
    python3)
      # Exit code is authoritative here: json.load raises on malformed input. stderr is NOT
      # usable as a signal — PYTHONWARNINGS=always / PYTHONDEVMODE=1 make a HEALTHY run write
      # warnings, which would reject a perfectly valid panel.
      python3 - "$f" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
if not isinstance(d, dict): raise SystemExit(1)
# `d.get("verifiers") or []` would be WRONG: every falsey wrong type (false, 0, "", {}) would
# coerce to an empty list and be accepted as "no verifiers configured", while jq rejects it.
# That is a fail-open parity gap — only an ABSENT/null field may default.
vs = d.get("verifiers")
if vs is None: vs = []
if not isinstance(vs, list): raise SystemExit(1)
s = d.get("synthesizer")
if s is None: s = {}
if not isinstance(s, dict): raise SystemExit(1)
out = []
def f(o, k, dflt=""):
    v = o.get(k, dflt)
    if v is None: v = dflt
    if not isinstance(v, str): raise SystemExit(1)
    # Same engine-boundary rule as jq's fld(). Reject the whole C0 control range, not just
    # TAB/newline: TAB and newline forge RECORDS, but U+001F (the unit separator panel_us
    # uses as IFS when bash reads those records) forges FIELDS — e.g. an adapter value
    # "grok<US>INJECTED" would split into adapter=grok, model=INJECTED. Model names are
    # display text, so banning all control characters closes the class outright.
    if any(ord(c) < 32 or ord(c) == 127 for c in v): raise SystemExit(1)
    return v
for e in vs:
    if not isinstance(e, dict): raise SystemExit(1)
    out.append("V\t%s\t%s\t%s" % (f(e, "adapter"), f(e, "model"), f(e, "effort")))
out.append("S\t%s\t%s\t%s" % (f(s, "adapter"), f(s, "model"), f(s, "effort")))
sys.stdout.write("\n".join(out) + "\n")
PY
      ;;
    *) return 1;;
  esac
}

# _panel_build -> reads V/S records on stdin, prints the JSON document on stdout.
_panel_build() {
  case "$(panel_engine)" in
    jq)
      jq -R -s '
        split("\n") | map(select(length > 0)) | map(split("\t")) as $r
        | { version: 1,
            verifiers: [ $r[] | select(.[0] == "V") | {adapter: .[1], model: .[2], effort: .[3]} ],
            synthesizer: ( [ $r[] | select(.[0] == "S") ]
                           | if length > 0
                               then (.[0] | {adapter: .[1], model: .[2], effort: .[3]})
                               else {adapter: "none", model: "", effort: ""} end ) }
      '
      ;;
    python3)
      # `-c`, NOT a heredoc: with `python3 - <<PY` the heredoc IS stdin, so the records
      # piped in here would never reach the script (it would silently emit an empty panel).
      python3 -c '
import json, sys
vs, s = [], {"adapter": "none", "model": "", "effort": ""}
for line in sys.stdin.read().split("\n"):
    if not line: continue
    p = line.split("\t")
    if len(p) != 4: continue
    e = {"adapter": p[1], "model": p[2], "effort": p[3]}
    if p[0] == "V": vs.append(e)
    elif p[0] == "S": s = e
json.dump({"version": 1, "verifiers": vs, "synthesizer": s}, sys.stdout, indent=2)
sys.stdout.write("\n")
'
      ;;
    *) return 1;;
  esac
}

# ---------- public read API ----------
# panel_verifiers [file] -> one record per active verifier:
#   <index><TAB><adapter><TAB><model><TAB><effort><TAB><label>
# Index is 1-based and positional; the label is the entry's identity (see panel_label).
# An entry that fails value validation is emitted with adapter "" so the caller can
# partition it as invalid rather than silently dropping it.
panel_verifiers() {
  local f="${1:-$(panel_file)}" line kind a m e idx=0
  panel_require_engine || return 1
  panel_readable "$f" || {
    echo "agent-companion: panel config is missing or not a readable regular file: $f" >&2
    return 1; }
  local recs
  recs="$(_panel_read "$f")" || {
    echo "agent-companion: panel config is not valid JSON or has the wrong shape: $f" >&2; return 1; }
  while IFS=$'\037' read -r kind a m e; do
    [ "$kind" = V ] || continue
    idx=$((idx + 1))
    if ! panel_valid_adapter "$a" || ! panel_valid_model "$m" || ! panel_valid_effort "$e"; then
      printf '%s\t\t%s\t%s\t%s\n' "$idx" "$(printf '%s' "$m" | tr '\t\n' '  ')" "$e" "$idx-invalid"
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$idx" "$a" "$m" "$e" "$(panel_label "$idx" "$a" "$m" "$e")"
  done < <(printf '%s\n' "$recs" | panel_us)
}

# panel_synth [file] -> <adapter><TAB><model><TAB><effort>. adapter is an adapter basename,
# or the special values "claude" (headless `claude -p`) / "none" (explicitly disabled).
#
# An EMPTY adapter means UNSET — the user has never chosen. That is deliberately distinct
# from "none": the manager protocol (commands/on.md) asks the user to pick a synthesizer on
# first run precisely when it is unset, and must not re-ask once they answered "none".
panel_synth() {
  local f="${1:-$(panel_file)}" line kind a m e
  panel_require_engine || return 1
  # Genuinely absent (neither the override nor the bundled default exists) = unset.
  # Present but unusable = a read failure, reported as rc 1 by the check below.
  if [ ! -e "$f" ] && [ ! -L "$f" ]; then printf '\t\t\n'; return 0; fi
  panel_readable "$f" || return 1
  local recs
  # A read FAILURE is not "unset": reporting an unreadable panel as "no synthesizer chosen"
  # would have `synthesizer show` quietly misdescribe a broken config. Absent file = unset
  # (rc 0 above); unparseable file = rc 1, and the caller decides how to say so.
  recs="$(_panel_read "$f")" || return 1
  while IFS=$'\037' read -r kind a m e; do
    [ "$kind" = S ] || continue
    case "$a" in '')      printf '\t\t\n';     return 0;; esac
    case "$a" in none|off) printf 'none\t\t\n'; return 0;; esac
    if [ "$a" != claude ] && { ! panel_valid_adapter "$a" || ! panel_valid_model "$m" || ! panel_valid_effort "$e"; }; then
      printf 'none\t\t\n'; return 0
    fi
    printf '%s\t%s\t%s\n' "$a" "$m" "$e"; return 0
  done < <(printf '%s\n' "$recs" | panel_us)
  printf '\t\t\n'
}

# ---------- public write API ----------
# Writes ALWAYS go to $DATA/panel.json ($ROOT is ephemeral — wiped on plugin update) and
# are ALWAYS atomic (mktemp + mv), fixing the torn-write window the old .conf appenders had.
#
# KNOWN LIMITATION (accepted, 2026-07-19): edits are read-modify-write with NO lock, so two
# concurrent `verifiers add` calls can lose one of the two entries. The file itself can never
# be corrupted or truncated — mv is atomic and panel_save refuses malformed streams — so the
# worst case is a missing entry that `verifiers list` makes immediately visible. These are
# interactive slash commands that do not realistically race; adding a mutex (mkdir-based,
# since macOS ships no flock) was considered and deliberately not done.
# panel_save -> reads V/S records on stdin and replaces the user panel.
panel_save() {
  panel_require_engine || return 1
  local recs
  recs="$(cat)"
  # REFUSE to write a stream that is not a well-formed panel. Without this, any failed
  # read-modify-write upstream (an unreadable panel, a dead engine) pipes nothing in here and
  # `_panel_build` cheerfully serializes an EMPTY panel over the user's real config —
  # turning a read error into silent data loss.
  if ! _panel_records_sane "$recs"; then
    echo "agent-companion: refusing to write the panel — the record stream is malformed or empty." >&2
    echo "agent-companion: your existing config at $PANEL_USER was left untouched." >&2
    return 1
  fi
  mkdir -p "$DATA"
  local tmp; tmp="$(mktemp "$DATA/panel.json.XXXXXX")" || return 1
  if printf '%s\n' "$recs" | _panel_build > "$tmp" && [ -s "$tmp" ]; then
    mv "$tmp" "$PANEL_USER"
  else
    rm -f "$tmp"; echo "agent-companion: failed to serialize the panel config" >&2; return 1
  fi
}

# panel_records [file] -> the raw V/S records of the EFFECTIVE panel, ready to be edited and
# piped back into panel_save. Seeds from the bundled default on the first edit.
panel_records() {
  local f="${1:-$(panel_file)}"
  panel_require_engine || return 1
  # Genuinely absent = an empty panel to seed the first edit from (rc 0). But a path that
  # EXISTS and is unusable must fail: returning 0-with-no-output here let `verifiers add`
  # report "added codex" against a directory, and actually CLOBBER a dangling symlink by
  # writing a fresh panel over it. Same rule as panel_verifiers/panel_synth.
  if [ ! -e "$f" ] && [ ! -L "$f" ]; then return 0; fi
  panel_readable "$f" || {
    echo "agent-companion: panel config is not a readable regular file: $f" >&2
    return 1; }
  _panel_read "$f"
}
