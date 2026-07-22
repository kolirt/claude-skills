#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# isolated plugin root (copy real files) + fake adapters
cp -R "$HERE" "$TMP/plugin"
ROOT="$TMP/plugin"; DATA="$TMP/data"; mkdir -p "$DATA"
# mock adapters: pass, changes, missing
cat > "$ROOT/adapters/mpass.sh"   <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
# use the LAST REQUEST_ID line — the real appended nonce (VERIFIER.md may carry example ones)
printf 'STATUS: PASS\nREQUEST_ID: %s\n' "$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')" > "$4"
A
cat > "$ROOT/adapters/mchg.sh"    <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
printf 'STATUS: CHANGES_REQUESTED\nREQUEST_ID: %s\nfix x\n' "$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')" > "$4"
A
cat > "$ROOT/adapters/mgone.sh"   <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 64
exit 64
A
# mfail: probe OK, but run fails to execute (non-zero rc) -> dispatcher must FAIL it
cat > "$ROOT/adapters/mfail.sh"   <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
exit 3
A
# mprobe: probe returns an UNKNOWN non-64 code -> fail-closed FAIL (not skip)
cat > "$ROOT/adapters/mprobe.sh"  <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 2
exit 0
A
chmod +x "$ROOT"/adapters/*.sh

run() { CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$DATA" bash "$ROOT/verify.sh" "$@"; }

# ---- panel config helpers (panel.json; the old .conf files are gone) ----
# Entries are POSITIONAL, so a test can predict an entry's label: the Nth argument becomes
# entry N, whose identity is "<N>-<slug of 'adapter model effort'>" (see panel_label).
# Argument syntax here is a TEST convenience only: adapter[|model[|effort]] — '|' is not
# IFS whitespace, so empty middle fields survive.
panel_lib() { env ROOT="$ROOT" DATA="$DATA" bash -c '. "$ROOT/lib/panel.sh"; '"$1"; }
panel_write() { env ROOT="$ROOT" DATA="$DATA" bash -c '. "$ROOT/lib/panel.sh"; panel_save'; }
SYNTH=none; SYNTH_MODEL=""
set_verifiers() {
  local spec a m e
  { for spec in "$@"; do
      IFS='|' read -r a m e <<<"$spec"
      printf 'V\t%s\t%s\t%s\n' "$a" "${m:-}" "${e:-}"
    done
    printf 'S\t%s\t%s\t\n' "$SYNTH" "$SYNTH_MODEL"
  } | panel_write
}
# set_synth <adapter|claude|none> [model] — rewrites only the S record.
set_synth() {
  SYNTH="$1"; SYNTH_MODEL="${2:-}"
  { panel_lib panel_records | awk -F'\t' '$1=="V"'
    printf 'S\t%s\t%s\t\n' "$SYNTH" "$SYNTH_MODEL"
  } | panel_write
}

# review, all pass -> exit 0
set_verifiers mpass
echo "MODE: review" > "$TMP/req.md"
( cd "$TMP" && git init -q )   # a repo for git diff
# Keep the harness's OWN files out of the repo under review. build_diff diffs every
# untracked file, so without this each prepare would diff the previous runs' diff.patch
# files — and since every patch then embeds all earlier ones, the suite blows up
# exponentially (it does not finish). The plugin copy is just noise in the same way.
printf 'data/\nplugin/\npaneltest/\n' > "$TMP/.gitignore"
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 0 ] && echo "OK pass-only" || { echo "FAIL expected 0 got $rc"; exit 1; }

# review, one changes -> exit 10 (any-blocks)
set_verifiers mpass mchg
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 10 ] && echo "OK any-blocks" || { echo "FAIL expected 10 got $rc"; exit 1; }

# missing verifier skipped, remaining pass -> exit 0, summary lists skip
set_verifiers mpass mgone
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -qi 'skip' && echo "OK skip-listed" || { echo "FAIL skip handling: $rc"; exit 1; }

# adapter run fails (rc!=0) -> classified FAIL -> review blocks (exit 10)
set_verifiers mpass mfail
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
[ "$rc" = 10 ] && echo "$out" | grep -q '\[2-mfail\] FAIL' && echo "OK run-fail blocks" || { echo "FAIL run-fail handling: $rc"; exit 1; }

# probe returns unknown code (not 0/64) -> fail-closed FAIL -> review blocks
set_verifiers mpass mprobe
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
[ "$rc" = 10 ] && echo "$out" | grep -q '\[2-mprobe\] FAIL' && echo "OK probe-unknown blocks" || { echo "FAIL probe-unknown handling: $rc"; exit 1; }

# --- synthesizer ---
cat > "$ROOT/adapters/msynth.sh" <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
printf 'CONSOLIDATED_OK (merged report)\n' > "$4"
A
chmod +x "$ROOT/adapters/msynth.sh"

# 2 reports + synthesizer -> consolidated output; gate still deterministic (mchg => exit 10)
set_verifiers mpass mchg
set_synth msynth
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
echo "$out" | grep -q 'consolidated report (by msynth' && echo "$out" | grep -q 'CONSOLIDATED_OK' && [ "$rc" = 10 ] \
  && echo "OK synth-2reports" || { echo "FAIL synth-2reports rc=$rc"; echo "$out"; exit 1; }

# 1 report + synthesizer set -> NO synthesis (single report returned as-is)
set_verifiers mpass
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
! echo "$out" | grep -q 'consolidated report' && [ "$rc" = 0 ] \
  && echo "OK synth-skip-1report" || { echo "FAIL synth-1report rc=$rc"; echo "$out"; exit 1; }

# synthesizer=none + 2 reports -> compact listing, no consolidation
set_verifiers mpass mchg
set_synth none
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
! echo "$out" | grep -q 'consolidated report' && [ "$rc" = 10 ] \
  && echo "OK synth-none" || { echo "FAIL synth-none rc=$rc"; echo "$out"; exit 1; }
set_synth none

# --- markdown-wrapped verdict (e.g. Grok Build emits **STATUS:**/**REQUEST_ID:**) ---
# classify_verdict must tolerate emphasis decoration, else a valid PASS reads as FAIL.
cat > "$ROOT/adapters/mmd.sh" <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
printf '**STATUS: PASS**\n**REQUEST_ID: %s**\n' "$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')" > "$4"
A
chmod +x "$ROOT/adapters/mmd.sh"
set_verifiers mmd
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 0 ] && echo "OK markdown-wrapped-pass" || { echo "FAIL markdown-wrapped expected 0 got $rc"; exit 1; }

# key-only emphasis: **STATUS**: PASS / **REQUEST_ID**: <nonce> (bold around the key only)
cat > "$ROOT/adapters/mmd2.sh" <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
printf '**STATUS**: PASS\n**REQUEST_ID**: %s\n' "$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')" > "$4"
A
chmod +x "$ROOT/adapters/mmd2.sh"
set_verifiers mmd2
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 0 ] && echo "OK markdown-key-only-pass" || { echo "FAIL markdown-key-only expected 0 got $rc"; exit 1; }

# --- synthesizer excludes FAIL verdicts (M3) ---
# 2 valid reports (mpass + mchg) get consolidated; mfail is excluded yet surfaced.
set_verifiers mpass mchg mfail
set_synth msynth
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
echo "$out" | grep -q 'consolidated report (by msynth · 2 agents' \
  && echo "$out" | grep -q 'FAIL — excluded from consolidation' && [ "$rc" = 10 ] \
  && echo "OK synth-excludes-fail" || { echo "FAIL synth-excludes-fail rc=$rc"; echo "$out"; exit 1; }
set_synth none

# --- echoed-prompt hijack: a valid verdict that ALSO echoes the prompt (carrying a
# bare nonce with no STATUS above it) must still classify from the real STATUS anchor ---
cat > "$ROOT/adapters/mhijack.sh" <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
n="$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')"
{ printf 'STATUS: PASS\nREQUEST_ID: %s\n\n' "$n"
  printf '## Echoed request for reference\n'
  printf 'REQUEST_ID: %s\n' "$n"; } > "$4"
A
chmod +x "$ROOT/adapters/mhijack.sh"
set_verifiers mhijack
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 0 ] && echo "OK echoed-prompt-not-hijacked" || { echo "FAIL echoed-prompt expected 0 got $rc"; exit 1; }

# --- bad invocation (missing args) -> exit 64, not the shell default 1 ---
( cd "$TMP" && run review ); rc=$?
[ "$rc" = 64 ] && echo "OK bad-args-64" || { echo "FAIL bad-args expected 64 got $rc"; exit 1; }

# --- missing request file -> exit 64 ---
set_verifiers mpass
( cd "$TMP" && run review medium "$TMP/does-not-exist.md" ) >/dev/null 2>&1; rc=$?
[ "$rc" = 64 ] && echo "OK missing-reqfile-64" || { echo "FAIL missing-reqfile expected 64 got $rc"; exit 1; }

# --- unknown mode (typo) -> exit 64, NOT a silent non-gating exit 0 ---
set_verifiers mpass
( cd "$TMP" && run reveiw medium "$TMP/req.md" ) >/dev/null 2>&1; rc=$?
[ "$rc" = 64 ] && echo "OK unknown-mode-64" || { echo "FAIL unknown-mode expected 64 got $rc"; exit 1; }

# --- classify_verdict unit matrix: every mode + wrong-mode fail-closed ---
( . "$ROOT/lib/verdict.sh"
  mk() { printf '%s\nREQUEST_ID: NONCE\n' "$1" > "$TMP/uv"; }
  ok() { [ "$(classify_verdict "$TMP/uv" NONCE "$2")" = "$3" ] || { echo "FAIL classify $1"; exit 1; }; }
  mk "STATUS: PASS";               ok p1 review   PASS
  mk "STATUS: CHANGES_REQUESTED";  ok p2 review   CHANGES
  mk "STATUS: ADVICE";             ok p3 consult  PASS
  mk "STATUS: AUDIT_COMPLETE";     ok p4 audit    PASS
  mk "STATUS: DIAGNOSIS_COMPLETE"; ok p5 diagnose PASS
  mk "STATUS: RESEARCH_COMPLETE";  ok p6 research PASS
  mk "STATUS: PASS";               ok p7 audit    FAIL   # wrong-mode status -> fail-closed
) || exit 1
echo "OK classify-matrix"

# ---- prepare: contract + manifest + markers ----
set_verifiers mpass mgone
out="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"; rc=$?
RUNP="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
[ "$rc" = 0 ] \
  && printf '%s\n' "$out" | grep -q "^RUNNABLE	1-mpass$" \
  && printf '%s\n' "$out" | grep -q "^SPAWN	1-mpass	bash " \
  && printf '%s\n' "$out" | grep -q "^SKIP	2-mgone	unavailable$" \
  && [ -f "$RUNP/manifest" ] && [ -f "$RUNP/.inflight" ] && [ -f "$RUNP/prompt.txt" ] \
  && grep -q "^mode	review$" "$RUNP/manifest" \
  && grep -q "^runnable	1-mpass	mpass		$" "$RUNP/manifest" \
  && grep -q "^skip	2-mgone	unavailable$" "$RUNP/manifest" \
  && echo "OK prepare-contract" || { echo "FAIL prepare-contract rc=$rc"; echo "$out"; exit 1; }

# prepare for audit must NOT produce a diff key (scope-centric)
out="$( cd "$TMP" && run prepare audit high "$TMP/req.md" 2>/dev/null )"
RUNA="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
! grep -q "^diff	" "$RUNA/manifest" && [ ! -f "$RUNA/diff.patch" ] \
  && echo "OK prepare-audit-no-diff" || { echo "FAIL prepare-audit-no-diff"; exit 1; }

# safe cleanup: only (complete && !inflight) OR (invalid manifest), and only when old (-mtime +1).
# An old in-flight run WITH a valid manifest must survive.
H="$DATA/handoff/fakekey"; mkdir -p "$H/run-old-complete" "$H/run-old-orphan" "$H/run-old-inflight"
: > "$H/run-old-complete/complete"
: > "$H/run-old-inflight/.inflight"
printf 'mode\treview\neffort\thigh\nreqid\tX\nrepo\t/r\nroot\t/p\n' > "$H/run-old-inflight/manifest"
touch -t 200001010000 "$H"/run-old-* 2>/dev/null     # force "old" (> 1 day)
set_verifiers mpass
( cd "$TMP" && run prepare review high "$TMP/req.md" ) >/dev/null 2>&1   # prepare runs cleanup_old
[ ! -d "$H/run-old-complete" ] && [ ! -d "$H/run-old-orphan" ] && [ -d "$H/run-old-inflight" ] \
  && echo "OK prepare-cleanup" || { echo "FAIL prepare-cleanup (complete=$([ -d "$H/run-old-complete" ]&&echo y) orphan=$([ -d "$H/run-old-orphan" ]&&echo y) inflight=$([ -d "$H/run-old-inflight" ]&&echo y))"; exit 1; }

# ---- run-one: writes rc+verdict on a prepared dir ----
set_verifiers mpass
out="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNO="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
( cd "$TMP" && run run-one "$RUNO" 1-mpass ); rc=$?
[ "$rc" = 0 ] && [ "$(cat "$RUNO/1-mpass/rc")" = 0 ] \
  && [ -f "$RUNO/1-mpass/verdict" ] && [ -f "$RUNO/1-mpass/finished" ] \
  && echo "OK run-one-writes" || { echo "FAIL run-one-writes rc=$rc"; exit 1; }

# adapter failure (rc!=0) is recorded in rc, run-one itself still exits 0
set_verifiers mfail
out="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNF="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
( cd "$TMP" && run run-one "$RUNF" 1-mfail ); rc=$?
[ "$rc" = 0 ] && [ "$(cat "$RUNF/1-mfail/rc")" = 3 ] \
  && echo "OK run-one-records-rc" || { echo "FAIL run-one-records-rc rc=$rc"; exit 1; }

# verifier not in runnable -> exit 64
( cd "$TMP" && run run-one "$RUNF" nope ) 2>/dev/null; rc=$?
[ "$rc" = 64 ] && echo "OK run-one-bad-verifier" || { echo "FAIL run-one-bad-verifier rc=$rc"; exit 1; }

# ---- collect: happy path (status + table + exit) ----
set_verifiers mpass mchg
O="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNC="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
printf '%s\n' "$O" | awk -F'\t' '$1=="RUNNABLE"{print $2}' | while IFS= read -r vv; do ( cd "$TMP" && run run-one "$RUNC" "$vv" ) >/dev/null 2>&1; done
out="$( cd "$TMP" && run collect "$RUNC" 2>/dev/null )"; rc=$?
[ "$rc" = 10 ] \
  && echo "$out" | grep -q '\[1-mpass\] PASS' \
  && echo "$out" | grep -q '\[2-mchg\] CHANGES' \
  && echo "$out" | grep -q '=== verdicts ===' \
  && echo "$out" | grep -q "1-mpass	PASS	$RUNC/1-mpass/verdict" \
  && [ -f "$RUNC/complete" ] && [ ! -f "$RUNC/.inflight" ] \
  && echo "OK collect-happy" || { echo "FAIL collect-happy rc=$rc"; echo "$out"; exit 1; }

# ---- collect: incomplete (runnable without rc) -> 64, MISSING, markers untouched ----
set_verifiers mpass
O="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNI="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
# deliberately do NOT run run-one
out="$( cd "$TMP" && run collect "$RUNI" 2>/dev/null )"; rc=$?
err="$( cd "$TMP" && run collect "$RUNI" 2>&1 >/dev/null )"
[ "$rc" = 64 ] && echo "$out" | grep -q "^MISSING	1-mpass$" \
  && echo "$err" | grep -q 'INCOMPLETE' \
  && [ -f "$RUNI/.inflight" ] && [ ! -f "$RUNI/complete" ] \
  && echo "OK collect-incomplete" || { echo "FAIL collect-incomplete rc=$rc"; echo "$out"; exit 1; }

# ---- collect: terminal NO_VERIFIER (all skip) -> 64, markers finalized ----
set_verifiers mgone
O="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNN="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
err="$( cd "$TMP" && run collect "$RUNN" 2>&1 >/dev/null )"; rc=$?
[ "$rc" = 64 ] && echo "$err" | grep -q 'NO_VERIFIER' \
  && [ -f "$RUNN/complete" ] && [ ! -f "$RUNN/.inflight" ] \
  && echo "OK collect-no-verifier" || { echo "FAIL collect-no-verifier rc=$rc"; echo "$err"; exit 1; }

# ---- lib/panel.sh unit matrix (JSON round-trip, identity, validation) ----
( ROOT="$ROOT"; DATA="$TMP/paneltest"; mkdir -p "$DATA"; . "$ROOT/lib/panel.sh"

  # a model name with spaces AND parentheses — the whole point of the JSON format — must
  # survive config -> records -> config byte-for-byte.
  printf 'V\tagy\tGemini 3.5 Flash (Medium)\t\nV\tcodex\t\thigh\nS\tclaude\t\t\n' | panel_save \
    || { echo "FAIL panel-save"; exit 1; }
  got="$(panel_verifiers | sed -n '1p' | cut -f3)"
  [ "$got" = "Gemini 3.5 Flash (Medium)" ] \
    || { echo "FAIL panel verbatim model: got [$got]"; exit 1; }

  # an empty model must NOT shift the effort field (TAB is IFS whitespace — the reason
  # every record read here goes through panel_us).
  [ "$(panel_verifiers | sed -n '2p' | cut -f3)" = "" ] && [ "$(panel_verifiers | sed -n '2p' | cut -f4)" = high ] \
    || { echo "FAIL panel empty-model shifted the record"; exit 1; }

  # identity: generated <index>-<slug>, never the raw model text
  [ "$(panel_verifiers | sed -n '1p' | cut -f5)" = "1-agy-gemini-3-5-flash-medium" ] \
    || { echo "FAIL panel label: $(panel_verifiers | sed -n '1p' | cut -f5)"; exit 1; }

  # two IDENTICAL entries still get distinct identities (the index guarantees it)
  printf 'V\tcodex\tm\t\nV\tcodex\tm\t\nS\tnone\t\t\n' | panel_save
  [ "$(panel_verifiers | cut -f5 | sort -u | wc -l | tr -d ' ')" = 2 ] \
    || { echo "FAIL panel label uniqueness"; exit 1; }

  # synthesizer round-trip
  printf 'V\tcodex\t\t\nS\tmsynth\tsome model\t\n' | panel_save
  [ "$(panel_synth | cut -f1)" = msynth ] && [ "$(panel_synth | cut -f2)" = "some model" ] \
    || { echo "FAIL panel synth round-trip"; exit 1; }

  # validation: value rules (adapter charset, effort tier, TAB/newline in a model)
  panel_valid_adapter codex   || { echo "FAIL adapter rejected"; exit 1; }
  for bad in '' 'co dex' 'codex/x' '-n'; do
    panel_valid_adapter "$bad" && { echo "FAIL adapter accepted [$bad]"; exit 1; }; done
  for good in '' low medium high xhigh max; do
    panel_valid_effort "$good" || { echo "FAIL effort rejected [$good]"; exit 1; }; done
  panel_valid_effort bogus && { echo "FAIL effort accepted [bogus]"; exit 1; }
  panel_valid_model 'Gemini 3.5 Flash (Medium)' || { echo "FAIL model rejected"; exit 1; }
  panel_valid_model "$(printf 'a\tb')" && { echo "FAIL model accepted a TAB"; exit 1; }
  panel_valid_model "$(printf 'a\nb')" && { echo "FAIL model accepted a newline"; exit 1; }
  panel_valid_model "$(printf 'x%.0s' $(seq 300))" && { echo "FAIL model accepted 300 chars"; exit 1; }

  # Invalid documents are rejected, not half-read. The falsey wrong-type cases below are the
  # ENGINE-PARITY set: `d.get("verifiers") or []` in python3 used to coerce every one of them
  # to an empty list and accept the document, while jq rejected it — a fail-open gap that let
  # a malformed panel look like "no verifiers configured". This block runs under whichever
  # engine is active, and the suite is run once per engine, so it pins both.
  for bad in '[]' '{"verifiers":{"a":1}}' '{"verifiers":[1,2]}' 'not json at all' \
             '{"verifiers":false,"synthesizer":{"adapter":"claude"}}' \
             '{"verifiers":0,"synthesizer":{"adapter":"claude"}}' \
             '{"verifiers":"","synthesizer":{"adapter":"claude"}}' \
             '{"verifiers":{},"synthesizer":{"adapter":"claude"}}' \
             '{"verifiers":[],"synthesizer":false}' \
             '{"verifiers":[],"synthesizer":[]}' \
             '{"verifiers":[],"synthesizer":0}'; do
    printf '%s' "$bad" > "$DATA/panel.json"
    panel_verifiers >/dev/null 2>&1 && { echo "FAIL panel accepted invalid doc: $bad"; exit 1; }
  done
  # NO FALSE POSITIVES: the hardening must not start rejecting legitimate model names. The
  # shell-metacharacter cases double as proof that nothing on this path is expanded or eval'd.
  for probe_model in 'He said "hi"' 'a\b\c' 'Модель «Кирилиця» — тире' 'Gemini 3.5 🚀 Flash' \
                     '--model-looking-value' 'Gemini 3.5 Flash (Medium)' '$HOME `whoami` $(id)' \
                     'a; rm -rf /; b'; do
    python3 -c 'import json,sys; json.dump({"version":1,
      "verifiers":[{"adapter":"codex","model":sys.argv[2],"effort":""}],
      "synthesizer":{"adapter":"none","model":"","effort":""}}, open(sys.argv[1],"w"))' \
      "$DATA/panel.json" "$probe_model"
    got="$(panel_verifiers 2>/dev/null | cut -f3)"
    [ "$got" = "$probe_model" ] \
      || { echo "FAIL legitimate model rejected/mangled: [$probe_model] -> [$got]"; exit 1; }
  done

  # an entry failing VALUE validation is surfaced (empty adapter), not silently dropped
  printf '{"verifiers":[{"adapter":"co dex"}],"synthesizer":{"adapter":"none"}}' > "$DATA/panel.json"
  [ "$(panel_verifiers | cut -f2)" = "" ] && [ "$(panel_verifiers | grep -c .)" = 1 ] \
    || { echo "FAIL panel invalid entry not surfaced"; exit 1; }

  # RECORD-PROTOCOL INTEGRITY (found by the verifier panel, 2026-07-19).
  # A newline inside a JSON value used to SPLIT into extra records, letting a hand-edited
  # model forge an S record and hijack the synthesizer. Must be rejected at the engine.
  python3 -c 'import json,sys; json.dump({"version":1,
    "verifiers":[{"adapter":"codex","model":"x\nS\tgrok\thijacked\t","effort":""}],
    "synthesizer":{"adapter":"claude","model":"","effort":""}}, open(sys.argv[1],"w"))' "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL newline injection accepted"; exit 1; }
  [ "$(panel_synth | cut -f1)" = "grok" ] && { echo "FAIL synthesizer hijacked by injection"; exit 1; }
  # a TAB inside a value would shift fields the same way
  python3 -c 'import json,sys; json.dump({"version":1,
    "verifiers":[{"adapter":"codex","model":"a\tb"}],"synthesizer":{"adapter":"none"}},
    open(sys.argv[1],"w"))' "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL TAB in value accepted"; exit 1; }
  # The payload above is caught by the RECORD-SHAPE check alone (its first line has 3 fields),
  # so it does NOT exercise the per-field TAB/newline rule. This one does: it carries BOTH a
  # TAB and a newline, arranged so every produced line still has exactly 4 fields and there is
  # still exactly one S record — it sails through _panel_records_sane and, without the
  # engine-level fld()/f() check, injects a SECOND VERIFIER the user never configured.
  # (Verified by mutation: disabling fld() makes this yield entry 2 = grok/INJECTED.)
  python3 -c 'import json,sys; json.dump({"version":1,
    "verifiers":[{"adapter":"codex","model":"a\tb\nV\tgrok\tINJECTED","effort":""}],
    "synthesizer":{"adapter":"claude","model":"","effort":""}}, open(sys.argv[1],"w"))' "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL shape-passing record injection accepted"; exit 1; }
  [ "$(panel_verifiers 2>/dev/null | grep -c .)" = 0 ] \
    || { echo "FAIL injected verifier reached the panel"; exit 1; }
  # U+001F forges FIELDS rather than records: it is the separator panel_us feeds to `read`
  # as IFS, so an adapter value "grok<US>INJECTED" would split into adapter=grok,
  # model=INJECTED. The engine bans the whole C0 range, so this must be rejected outright.
  python3 -c 'import json,sys; json.dump({"version":1,"verifiers":[],
    "synthesizer":{"adapter":"grok"+chr(31)+"INJECTED","model":"","effort":""}}, open(sys.argv[1],"w"))' \
    "$DATA/panel.json"
  [ "$(panel_synth 2>/dev/null | cut -f1)" = "grok" ] \
    && { echo "FAIL unit-separator field injection accepted"; exit 1; }
  python3 -c 'import json,sys; json.dump({"version":1,
    "verifiers":[{"adapter":"codex","model":"a"+chr(7)+"b"}],"synthesizer":{"adapter":"none"}},
    open(sys.argv[1],"w"))' "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL control character in a model accepted"; exit 1; }

  # ENGINE PARITY: jq accepts concatenated top-level documents, python3 does not; both must
  # reject here (it shows up as more than one S record).
  printf '{"verifiers":[],"synthesizer":{"adapter":"claude"}}{"verifiers":[],"synthesizer":{"adapter":"grok"}}' > "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL concatenated documents accepted"; exit 1; }
  # a non-string field: jq's `//` would coerce false to "", python3 errors — force agreement
  printf '{"verifiers":[{"adapter":"codex","model":false}],"synthesizer":{"adapter":"none"}}' > "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL non-string field accepted"; exit 1; }

  # TRAILING GARBAGE after a valid document. Apple's jq emits the first document's records,
  # writes a parse error to stderr, and exits 0 — so neither the exit code nor the record
  # shape catches it, while python3 rejects it. Caught by treating non-empty engine stderr as
  # a parse failure. (Found in review round 4 by codex:gpt-5.5.)
  printf '%s' '{"verifiers":[],"synthesizer":{"adapter":"claude"}} trailing' > "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL trailing garbage accepted"; exit 1; }
  # ...but the stderr rule is jq-ONLY. python3 writes warnings to stderr on a HEALTHY run when
  # PYTHONWARNINGS/PYTHONDEVMODE are set, so applying it there would reject VALID panels.
  printf '%s' '{"verifiers":[{"adapter":"codex","model":"m","effort":"high"}],"synthesizer":{"adapter":"claude"}}' \
    > "$DATA/panel.json"
  for warnenv in PYTHONWARNINGS=always PYTHONDEVMODE=1; do
    env "$warnenv" ROOT="$ROOT" DATA="$DATA" \
      bash -c '. "$ROOT/lib/panel.sh"; panel_verifiers >/dev/null 2>&1' \
      || { echo "FAIL valid panel rejected under $warnenv"; exit 1; }
  done
  # The jq side has the same trap: a malformed JQ_COLORS makes jq print "Failed to set
  # $JQ_COLORS" and exit 0. Treating any stderr as corruption would reject a valid panel, so
  # only PARSE-ERROR text counts (and JQ_COLORS is unset for the call).
  env JQ_COLORS=bogus ROOT="$ROOT" DATA="$DATA" \
    bash -c '. "$ROOT/lib/panel.sh"; panel_verifiers >/dev/null 2>&1' \
    || { echo "FAIL valid panel rejected under JQ_COLORS=bogus"; exit 1; }

  # A user panel.json that EXISTS but is unusable must fail closed, not silently fall back to
  # the bundled empty default (which would run the panel with no verifiers at all).
  rm -f "$DATA/panel.json"; mkdir -p "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL directory panel.json fell back silently"; exit 1; }
  rmdir "$DATA/panel.json"
  ln -sf /nonexistent/nope "$DATA/panel.json"
  panel_verifiers >/dev/null 2>&1 && { echo "FAIL dangling symlink panel.json fell back silently"; exit 1; }
  panel_synth >/dev/null 2>&1 && { echo "FAIL dangling symlink read as unset synthesizer"; exit 1; }
  rm -f "$DATA/panel.json"

  # panel_save must NEVER turn a failed read into data loss
  printf '{"verifiers":[{"adapter":"codex","model":"","effort":"high"}],"synthesizer":{"adapter":"claude"}}' > "$DATA/panel.json"
  before="$(cat "$DATA/panel.json")"
  printf '' | panel_save 2>/dev/null && { echo "FAIL panel_save accepted an empty stream"; exit 1; }
  printf 'V\tcodex\t\thigh\n' | panel_save 2>/dev/null && { echo "FAIL panel_save accepted a stream with no S record"; exit 1; }
  printf 'garbage\n' | panel_save 2>/dev/null && { echo "FAIL panel_save accepted junk"; exit 1; }
  [ "$(cat "$DATA/panel.json")" = "$before" ] \
    || { echo "FAIL panel_save clobbered the config on a rejected write"; exit 1; }
  true
) || exit 1
echo "OK panel-unit-matrix"

# a panel that cannot be READ must abort the run loudly — NOT degrade to NO_VERIFIER, which
# the manager protocol treats as benign and proceeds without verification.
printf 'this is not json' > "$DATA/panel.json"
err="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>&1 >/dev/null )"; rc=$?
[ "$rc" = 64 ] && echo "$err" | grep -q 'refusing to run unverified' \
  && echo "OK unreadable-panel-fails-loudly" || { echo "FAIL unreadable-panel rc=$rc"; echo "$err"; exit 1; }

# ...and `synthesizer show` must not describe an unreadable panel as "unset" (that would read
# as "you never chose one" when the truth is "your config is broken").
out="$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$DATA" bash "$ROOT/synthesizer.sh" show 2>&1)"; rc=$?
[ "$rc" != 0 ] && echo "$out" | grep -q 'UNKNOWN' && ! echo "$out" | grep -q 'synthesizer: unset' \
  && echo "OK synth-show-unreadable-panel" || { echo "FAIL synth-show unreadable rc=$rc"; echo "$out"; exit 1; }

# `verifiers list` must not report a broken panel as an empty one, and must exit non-zero.
out="$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$DATA" bash "$ROOT/verifiers.sh" list 2>&1)"; rc=$?
[ "$rc" != 0 ] && echo "$out" | grep -q 'UNKNOWN' && ! echo "$out" | grep -q '(none active)' \
  && echo "OK list-unreadable-panel" || { echo "FAIL list unreadable rc=$rc"; echo "$out"; exit 1; }

# `verifiers remove` must blame the config, not the user's index ("panel has 0").
out="$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$DATA" bash "$ROOT/verifiers.sh" remove 1 2>&1)"; rc=$?
[ "$rc" != 0 ] && echo "$out" | grep -q 'cannot read the current panel' && ! echo "$out" | grep -q 'panel has 0' \
  && echo "OK remove-unreadable-panel" || { echo "FAIL remove unreadable rc=$rc"; echo "$out"; exit 1; }

# A NON-REGULAR user panel must fail closed on the WRITE path too. Before this was fixed,
# `add` printed "added codex" against a directory and actually CLOBBERED a dangling symlink
# by writing a fresh panel over it.
mkdir -p "$DATA/nonreg"; NR="$DATA/nonreg"
mkdir -p "$NR/panel.json"
CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$NR" bash "$ROOT/verifiers.sh" add mpass >/dev/null 2>&1 \
  && { echo "FAIL add succeeded against a directory panel.json"; exit 1; }
[ -d "$NR/panel.json" ] || { echo "FAIL directory panel.json was replaced"; exit 1; }
rmdir "$NR/panel.json"
ln -sf /nonexistent/nope "$NR/panel.json"
CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$NR" bash "$ROOT/verifiers.sh" add mpass >/dev/null 2>&1 \
  && { echo "FAIL add succeeded against a dangling symlink"; exit 1; }
CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$NR" bash "$ROOT/synthesizer.sh" set claude >/dev/null 2>&1 \
  && { echo "FAIL synthesizer set succeeded against a dangling symlink"; exit 1; }
{ [ -L "$NR/panel.json" ] && [ ! -e "$NR/panel.json" ]; } \
  || { echo "FAIL dangling symlink panel.json was clobbered"; exit 1; }
rm -f "$NR/panel.json"; rmdir "$NR" 2>/dev/null
echo "OK nonregular-panel-write-fails-closed"

# ...and an edit against an unreadable panel must refuse, leaving the file untouched.
before="$(cat "$DATA/panel.json")"
out="$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$DATA" bash "$ROOT/verifiers.sh" add mpass 2>&1)"; rc=$?
[ "$rc" != 0 ] && echo "$out" | grep -q 'refusing to edit' && [ "$(cat "$DATA/panel.json")" = "$before" ] \
  && echo "OK unreadable-panel-edit-refused" || { echo "FAIL unreadable-panel edit rc=$rc"; echo "$out"; exit 1; }
rm -f "$DATA/panel.json"

# mecho: echoes the effort ($3) and model ($5) it was invoked with into its verdict.
# NOTE arg positions — adapters are NOT shifted: $1=run $2=prompt $3=effort $4=out $5=model.
cat > "$ROOT/adapters/mecho.sh" <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
n="$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')"
printf 'STATUS: PASS\nREQUEST_ID: %s\nEFFORT=%s MODEL=%s\n' "$n" "$3" "${5:-}" > "$4"
A
chmod +x "$ROOT/adapters/mecho.sh"

# routing: a model with SPACES AND PARENTHESES reaches the adapter verbatim, and a
# per-entry effort overrides the dispatch effort (medium). The run dir is the generated
# label — the model text never becomes a path component.
set_verifiers 'mecho|Gemini 3.5 Flash (Medium)|high'
O="$( cd "$TMP" && run prepare review medium "$TMP/req.md" 2>/dev/null )"
RUNX="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
LX="1-mecho-gemini-3-5-flash-medium-high"
printf '%s\n' "$O" | grep -q "^RUNNABLE	$LX$" || { echo "FAIL routing: RUNNABLE line"; echo "$O"; exit 1; }
grep -q "^runnable	$LX	mecho	Gemini 3.5 Flash (Medium)	high$" "$RUNX/manifest" \
  || { echo "FAIL routing: manifest record"; grep '^runnable' "$RUNX/manifest"; exit 1; }
( cd "$TMP" && run run-one "$RUNX" "$LX" ) >/dev/null 2>&1
VX="$RUNX/$LX/verdict"
grep -q 'MODEL=Gemini 3.5 Flash (Medium)' "$VX" && grep -q 'EFFORT=high' "$VX" \
  && echo "OK verbatim-model-effort-routing" || { echo "FAIL routing verdict"; cat "$VX" 2>/dev/null; exit 1; }

# effort fallback: an entry with no model/effort uses the dispatch effort and passes NO model.
set_verifiers mecho
O="$( cd "$TMP" && run prepare review medium "$TMP/req.md" 2>/dev/null )"
RUNY="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
( cd "$TMP" && run run-one "$RUNY" 1-mecho ) >/dev/null 2>&1
VY="$RUNY/1-mecho/verdict"
grep -q 'EFFORT=medium' "$VY" && grep -q 'MODEL=$' "$VY" \
  && echo "OK effort-fallback" || { echo "FAIL effort-fallback"; cat "$VY" 2>/dev/null; exit 1; }

# an entry failing validation -> FAIL partition (invalid-entry), never run blindly.
printf '{"verifiers":[{"adapter":"me cho"}],"synthesizer":{"adapter":"none"}}' > "$DATA/panel.json"
O="$( cd "$TMP" && run prepare review medium "$TMP/req.md" 2>/dev/null )"
printf '%s\n' "$O" | grep -q "^FAIL	1-invalid	invalid-entry$" \
  && echo "OK invalid-entry-fails" || { echo "FAIL invalid-entry"; echo "$O"; exit 1; }

# a configured verifier whose adapter FILE is gone degrades to SKIP(removed-adapter) with an
# actionable warning — it must NOT FAIL and block the review gate.
set_verifiers mpass mvanished
O="$( cd "$TMP" && run prepare review medium "$TMP/req.md" 2>"$TMP/prep.err" )"
RUNV="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
printf '%s\n' "$O" | grep -q "^SKIP	2-mvanished	removed-adapter$" \
  && grep -q 'no longer exists' "$TMP/prep.err" \
  && grep -q 'verifiers remove 2' "$TMP/prep.err" \
  && grep -q 'adapters currently available' "$TMP/prep.err" \
  || { echo "FAIL removed-adapter partition/warning"; echo "$O"; cat "$TMP/prep.err"; exit 1; }
( cd "$TMP" && run run-one "$RUNV" 1-mpass ) >/dev/null 2>&1
out="$( cd "$TMP" && run collect "$RUNV" 2>/dev/null )"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q '\[2-mvanished\] SKIP (removed-adapter)' \
  && echo "OK removed-adapter-skips" || { echo "FAIL removed-adapter collect rc=$rc"; echo "$out"; exit 1; }

# ALL verifiers referring to missing adapters -> still terminal NO_VERIFIER (exit 64).
set_verifiers mvanished
O="$( cd "$TMP" && run prepare review medium "$TMP/req.md" 2>/dev/null )"
RUNW="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
err="$( cd "$TMP" && run collect "$RUNW" 2>&1 >/dev/null )"; rc=$?
[ "$rc" = 64 ] && echo "$err" | grep -q 'NO_VERIFIER' \
  && echo "OK removed-adapter-no-verifier" || { echo "FAIL removed-adapter NO_VERIFIER rc=$rc"; echo "$err"; exit 1; }

# a STALE synthesizer (adapter gone) must warn on stderr and leave the gate code unchanged.
set_verifiers mpass mchg
set_synth mvanished
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>"$TMP/synth.err" )"; rc=$?
[ "$rc" = 10 ] && ! echo "$out" | grep -q 'consolidated report' \
  && grep -q 'synthesizer "mvanished" is configured but not usable' "$TMP/synth.err" \
  && grep -q 'synthesizer set' "$TMP/synth.err" \
  && echo "OK synth-stale-warns" || { echo "FAIL synth-stale rc=$rc"; echo "$out"; cat "$TMP/synth.err"; exit 1; }
set_synth none

# leftover old-format .conf files are IGNORED but reported loudly — and the warning must say
# which panel is ACTUALLY in effect, since claiming "you are on the bundled default" to
# someone who already rebuilt their panel would be plain false.
: > "$DATA/verifiers.conf"; : > "$DATA/synthesizer.conf"
set_verifiers mpass          # this writes $DATA/panel.json -> the rebuilt-panel branch
err="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 >/dev/null )"; rc=$?
[ "$rc" = 0 ] && echo "$err" | grep -q 'IGNORING obsolete panel config' \
  && echo "$err" | grep -q 'just leftovers' \
  && ! echo "$err" | grep -q 'BUNDLED DEFAULT' \
  && echo "OK legacy-conf-warned-rebuilt" || { echo "FAIL legacy-conf rebuilt rc=$rc"; echo "$err"; exit 1; }
# no panel.json -> the bundled-default branch, with the rebuild instructions
rm -f "$DATA/panel.json"
err="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 >/dev/null )"; rc=$?
[ "$rc" = 64 ] && echo "$err" | grep -q 'BUNDLED DEFAULT' \
  && echo "$err" | grep -q 'verifiers add' \
  && echo "OK legacy-conf-warned-default" || { echo "FAIL legacy-conf default rc=$rc"; echo "$err"; exit 1; }
rm -f "$DATA/verifiers.conf" "$DATA/synthesizer.conf"

# ---- verifiers.sh / synthesizer.sh management commands ----
vsh() { CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$DATA" bash "$ROOT/verifiers.sh" "$@"; }
ssh_() { CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$DATA" bash "$ROOT/synthesizer.sh" "$@"; }
# an adapter that CAN enumerate its models -> loose input resolves to the canonical name
cat > "$ROOT/adapters/mmodels.sh" <<'A'
#!/usr/bin/env bash
case "$1" in
  probe)  exit 0;;
  models) printf 'Gemini 3.5 Flash (Medium)\nGemini 3.5 Flash (High)\n'; exit 0;;
esac
n="$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')"
printf 'STATUS: PASS\nREQUEST_ID: %s\n' "$n" > "$4"
A
chmod +x "$ROOT/adapters/mmodels.sh"
set_verifiers   # reset to an empty panel
vsh add mmodels --model 'gemini 3.5 flash medium' >/dev/null 2>&1 \
  && [ "$(panel_lib panel_verifiers | cut -f3)" = "Gemini 3.5 Flash (Medium)" ] \
  && echo "OK add-resolves-canonical" || { echo "FAIL add-resolves-canonical: $(panel_lib panel_verifiers)"; exit 1; }
# ambiguous input is REJECTED with the candidate list, never silently stored
out="$(vsh add mmodels --model 'gemini 3.5 flash' 2>&1)"; rc=$?
[ "$rc" != 0 ] && echo "$out" | grep -q 'unknown or ambiguous' && echo "$out" | grep -q 'Gemini 3.5 Flash (High)' \
  && echo "OK add-rejects-ambiguous" || { echo "FAIL add-rejects-ambiguous rc=$rc"; echo "$out"; exit 1; }
# an adapter with NO models subcommand stores the value verbatim
vsh add mpass --model 'whatever-i-typed' >/dev/null 2>&1 \
  && [ "$(panel_lib panel_verifiers | sed -n '2p' | cut -f3)" = 'whatever-i-typed' ] \
  && echo "OK add-verbatim-when-no-models" || { echo "FAIL add-verbatim: $(panel_lib panel_verifiers)"; exit 1; }
# remove is by INDEX and keeps the synthesizer intact
ssh_ set claude >/dev/null 2>&1
vsh remove 1 >/dev/null 2>&1 \
  && [ "$(panel_lib panel_verifiers | grep -c .)" = 1 ] \
  && [ "$(panel_lib panel_verifiers | cut -f2)" = mpass ] \
  && [ "$(panel_lib panel_synth | cut -f1)" = claude ] \
  && echo "OK remove-by-index" || { echo "FAIL remove-by-index"; exit 1; }
# unset (never chosen) must NOT read as none (chosen: disabled) — commands/on.md asks the
# user to pick a synthesizer only while it is unset, and must not re-ask after they said none.
# NOTE: capture into a variable first — `cmd | grep -q` under `set -o pipefail` fails the
# pipeline, because grep -q exits on the first match and SIGPIPEs the producer.
printf '{"verifiers":[],"synthesizer":{"adapter":""}}' > "$DATA/panel.json"
out="$(ssh_ show 2>&1)"
echo "$out" | grep -q 'synthesizer: unset' \
  || { echo "FAIL synth-unset not reported as unset"; echo "$out"; exit 1; }
ssh_ off >/dev/null 2>&1
out="$(ssh_ show 2>&1)"
echo "$out" | grep -q 'synthesizer: none' \
  && echo "OK synth-unset-vs-none" || { echo "FAIL synth-none after off"; echo "$out"; exit 1; }
# the BUNDLED default must ship as unset, so a fresh install still prompts
[ "$(panel_lib 'panel_synth "$ROOT/panel.json"' | cut -f1)" = "" ] \
  && echo "OK bundled-synth-unset" || { echo "FAIL bundled panel.json is not unset"; exit 1; }

# `show` must not error on a stale synthesizer — it must FLAG it
ssh_ set mmodels >/dev/null 2>&1
rm -f "$ROOT/adapters/mmodels.sh"
out="$(ssh_ show 2>&1)"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q 'STALE' \
  && echo "OK synth-show-flags-stale" || { echo "FAIL synth-show-stale rc=$rc"; echo "$out"; exit 1; }
ssh_ off >/dev/null 2>&1

# a bare entry must invoke `probe` with NO extra arg (custom strict adapters rely on this).
cat > "$ROOT/adapters/mstrict.sh" <<'A'
#!/usr/bin/env bash
if [ "$1" = probe ]; then [ "$#" -eq 1 ] && exit 0 || exit 64; fi
n="$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')"
printf 'STATUS: PASS\nREQUEST_ID: %s\n' "$n" > "$4"
A
chmod +x "$ROOT/adapters/mstrict.sh"
set_verifiers mstrict
( cd "$TMP" && run review medium "$TMP/req.md" ) >/dev/null; rc=$?
[ "$rc" = 0 ] && echo "OK bare-probe-no-extra-arg" || { echo "FAIL bare-probe-no-extra-arg rc=$rc"; exit 1; }

# ============================================================================
# lib/state.sh + hooks/* + SKILL_FILES coverage (plan step 9).
#
# These cases are deliberately kept to DIRECT invocations (lib/state.sh subcommands, hooks
# fed fake stdin JSON, verify.sh `prepare` only) instead of the synchronous `run <mode>
# <effort> <req>` panel-wait form — that form is already the slowest part of this suite.
# Every state/hook case below gets its OWN isolated CLAUDE_PLUGIN_DATA temp dir so state and
# GC never leak between cases (the suite would otherwise become order-dependent). `skey`
# resolves a session_id's on-disk key without touching any DATA dir (session_key is pure).
# ============================================================================
skey() { bash "$ROOT/lib/state.sh" key "$1"; }

# ---- state.sh: on / off / status ----
SD="$(mktemp -d)"
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" on sess-onoff >/dev/null
out="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-onoff)"
echo "$out" | grep -qE '^active 0 [0-9]+$' || { echo "FAIL state-on-status: $out"; exit 1; }
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" off sess-onoff >/dev/null
out2="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-onoff)"
[ -z "$out2" ] && echo "OK state-on-off-status" || { echo "FAIL state-on-off-status: $out2"; exit 1; }

# ---- state.sh: claim of a fresh `want` ----
SD="$(mktemp -d)"
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" want-on >/dev/null
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" claim sess-freshwant >/dev/null
out="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-freshwant)"
echo "$out" | grep -qE '^active 0 [0-9]+$' && echo "OK state-claim-fresh-want" || { echo "FAIL state-claim-fresh-want: $out"; exit 1; }

# ---- state.sh: a stale `want` (>120s) is NOT applied ----
SD="$(mktemp -d)"; mkdir -p "$SD"
printf 'on %s\n' "$(( $(date +%s) - 200 ))" > "$SD/want"
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" claim sess-stalewant >/dev/null
out="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-stalewant)"
[ -z "$out" ] && echo "OK state-claim-stale-want-ignored" || { echo "FAIL state-claim-stale-want-ignored: $out"; exit 1; }

# ---- state.sh: `want-off` after `want-on` wins (last-write-wins) ----
SD="$(mktemp -d)"
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" on sess-lastwrite >/dev/null   # start active
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" want-on  >/dev/null
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" want-off >/dev/null
content="$(cat "$SD/want" 2>/dev/null)"
echo "$content" | grep -q '^off ' || { echo "FAIL state-want-off-wins marker: $content"; exit 1; }
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" claim sess-lastwrite >/dev/null
out="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-lastwrite)"
[ -z "$out" ] && echo "OK state-want-off-after-want-on-wins" || { echo "FAIL state-want-off-after-want-on-wins: $out"; exit 1; }

# ---- state.sh: GC of old sessions, stale `want`, and orphaned `want.claimed.*` (>10min) ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
printf 'active=1\nprompt_count=0\nlast_inject_ts=0\n' > "$SD/sessions/oldsess"
printf 'on 1\n' > "$SD/want"
: > "$SD/want.claimed.9999"
touch -t 202001010000 "$SD/sessions/oldsess" "$SD/want" "$SD/want.claimed.9999" 2>/dev/null
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" gc >/dev/null
[ ! -f "$SD/sessions/oldsess" ] && [ ! -f "$SD/want" ] && [ ! -f "$SD/want.claimed.9999" ] \
  && echo "OK state-gc-sweeps-old" || { echo "FAIL state-gc-sweeps-old"; ls -la "$SD" "$SD/sessions"; exit 1; }

# ---- state.sh: empty session_id exits 0 (silently, on every command that takes one) ----
SD="$(mktemp -d)"
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" claim "" >/dev/null 2>&1; rc1=$?
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" on ""    >/dev/null 2>&1; rc2=$?
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status "" >/dev/null 2>&1; rc3=$?
[ "$rc1" = 0 ] && [ "$rc2" = 0 ] && [ "$rc3" = 0 ] \
  && echo "OK state-empty-session-id-exits-0" || { echo "FAIL state-empty-session-id-exits-0: $rc1 $rc2 $rc3"; exit 1; }

# ---- state.sh: a session_id containing `../` cannot escape the sessions dir ----
SD="$(mktemp -d)"
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" on '../../../../tmp/agent-companion-escape-test' >/dev/null
outside="$(find "$SD" -mindepth 1 -maxdepth 1 ! -name sessions)"
[ -z "$outside" ] || { echo "FAIL state-traversal-safe: stray entries: $outside"; exit 1; }
cnt="$(find "$SD/sessions" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
fname="$(basename "$(find "$SD/sessions" -mindepth 1 -maxdepth 1 2>/dev/null)")"
[ "$cnt" = 1 ] && echo "$fname" | grep -qE '^[0-9a-f]{16}$' && [ ! -e "/tmp/agent-companion-escape-test" ] \
  && echo "OK state-traversal-safe" || { echo "FAIL state-traversal-safe: cnt=$cnt fname=$fname"; exit 1; }

# ---- hooks/user-prompt-submit: reminder fires when the throttle is ripe (count>=8) ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-ripe-count)"
printf 'active=1\nprompt_count=8\nlast_inject_ts=%s\n' "$(date +%s)" > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-ripe-count","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
echo "$out" | grep -q 'agent-companion reminder' && echo "OK ups-reminder-fires-count-ripe" \
  || { echo "FAIL ups-reminder-fires-count-ripe"; echo "$out"; exit 1; }

# ---- hooks/user-prompt-submit: silence with no state ----
SD="$(mktemp -d)"
out="$(printf '%s' '{"session_id":"sess-nostate","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
[ -z "$out" ] && echo "OK ups-silent-no-state" || { echo "FAIL ups-silent-no-state"; echo "$out"; exit 1; }

# ---- hooks/user-prompt-submit: prompt_count grows even on silent (non-injecting) prompts ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-count-grows)"
printf 'active=1\nprompt_count=0\nlast_inject_ts=%s\n' "$(date +%s)" > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-count-grows","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
[ -z "$out" ] && grep -q '^prompt_count=1$' "$SD/sessions/$K" \
  && echo "OK ups-count-grows-silently" || { echo "FAIL ups-count-grows-silently"; cat "$SD/sessions/$K"; exit 1; }

# ---- hooks/user-prompt-submit: 7->8 boundary fires, 6->7 stays silent ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-boundary78)"
printf 'active=1\nprompt_count=7\nlast_inject_ts=%s\n' "$(date +%s)" > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-boundary78","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
echo "$out" | grep -q 'agent-companion reminder' && echo "OK ups-boundary-7-to-8-fires" \
  || { echo "FAIL ups-boundary-7-to-8-fires"; echo "$out"; exit 1; }

SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-boundary67)"
printf 'active=1\nprompt_count=5\nlast_inject_ts=%s\n' "$(date +%s)" > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-boundary67","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
[ -z "$out" ] && echo "OK ups-below-8-stays-silent" || { echo "FAIL ups-below-8-stays-silent"; echo "$out"; exit 1; }

# ---- hooks/user-prompt-submit: 20-minute boundary (>=1200s fires, 1199s stays silent) ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-boundary20a)"
now="$(date +%s)"
printf 'active=1\nprompt_count=0\nlast_inject_ts=%s\n' "$((now - 1200))" > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-boundary20a","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
echo "$out" | grep -q 'agent-companion reminder' && echo "OK ups-boundary-20min-fires" \
  || { echo "FAIL ups-boundary-20min-fires"; echo "$out"; exit 1; }

SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-boundary20b)"
now="$(date +%s)"
# a safe margin below the 1200s threshold (not 1199) — avoids flakiness from clock drift
# between this write and the hook's own now_ts() a moment later.
printf 'active=1\nprompt_count=0\nlast_inject_ts=%s\n' "$((now - 1150))" > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-boundary20b","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
[ -z "$out" ] && echo "OK ups-below-20min-stays-silent" || { echo "FAIL ups-below-20min-stays-silent"; echo "$out"; exit 1; }

# ---- hooks/user-prompt-submit: `/agent-companion:on` yields ONLY a confirmation ----
SD="$(mktemp -d)"
out="$(printf '%s' '{"session_id":"sess-oncmd","prompt":"/agent-companion:on"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
lines="$(printf '%s\n' "$out" | grep -c .)"
echo "$out" | grep -q 'now ACTIVE' && ! echo "$out" | grep -q 'reminder' && [ "$lines" = 1 ] \
  && echo "OK ups-on-command-only-confirmation" || { echo "FAIL ups-on-command-only-confirmation"; echo "$out"; exit 1; }

# ---- hooks/user-prompt-submit: `agent-companion:onward` does NOT match the on/off regex ----
SD="$(mktemp -d)"
printf '%s' '{"session_id":"sess-onward","prompt":"/agent-companion:onward"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit" >/dev/null
st="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-onward)"
[ -z "$st" ] && echo "OK ups-onward-does-not-match" || { echo "FAIL ups-onward-does-not-match: $st"; exit 1; }

# ---- hooks/user-prompt-submit: an explicit `/off` is not undone by a stale marker ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-offwins)"
printf 'active=1\nprompt_count=0\nlast_inject_ts=%s\n' "$(date +%s)" > "$SD/sessions/$K"
printf 'on %s\n' "$(( $(date +%s) - 500 ))" > "$SD/want"   # stale want-on must not resurrect
out="$(printf '%s' '{"session_id":"sess-offwins","prompt":"/agent-companion:off"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
st="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-offwins)"
echo "$out" | grep -q 'now OFF' && [ -z "$st" ] && [ ! -f "$SD/want" ] \
  && echo "OK ups-explicit-off-not-undone-by-stale-want" || { echo "FAIL ups-explicit-off-not-undone-by-stale-want"; echo "$out"; exit 1; }

# ---- hooks/user-prompt-submit: malformed and empty stdin -> exit 0, no output ----
SD="$(mktemp -d)"
out="$(printf '' | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && echo "OK ups-empty-stdin" || { echo "FAIL ups-empty-stdin rc=$rc"; echo "$out"; exit 1; }
out="$(printf 'not-json{{{' | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && echo "OK ups-malformed-stdin" || { echo "FAIL ups-malformed-stdin rc=$rc"; echo "$out"; exit 1; }

# ---- hooks/user-prompt-submit: output is exactly ONE valid JSON document ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-json-shape)"
printf 'active=1\nprompt_count=8\nlast_inject_ts=%s\n' "$(date +%s)" > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-json-shape","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
lines="$(printf '%s\n' "$out" | grep -c .)"
echo "$out" | python3 -m json.tool >/dev/null 2>&1; jrc=$?
[ "$lines" = 1 ] && [ "$jrc" = 0 ] && echo "OK ups-output-single-valid-json" \
  || { echo "FAIL ups-output-single-valid-json lines=$lines jrc=$jrc"; echo "$out"; exit 1; }

# ---- fail-open: python3 unavailable on PATH (coreutils kept, PATH not blanked) ----
# A curated bin/ of symlinks to every coreutil the hook needs (dirname, cat, mkdir, mktemp,
# mv, rm, date, grep, basename, bash, sh) minus python3 — NOT a filtered-down real $PATH,
# because on this machine python3 and dirname/coreutils live in the SAME directories, so
# dropping "any dir containing python3" would also hide dirname and make the test meaningless.
SD="$(mktemp -d)"
NOPY_BIN="$(mktemp -d)"
for tool in dirname cat mkdir mktemp mv rm date grep basename bash sh head cut tr; do
  t="$(command -v "$tool" 2>/dev/null)"; [ -n "$t" ] && ln -sf "$t" "$NOPY_BIN/$tool"
done
out="$(printf '%s' '{"session_id":"sess-nopython","prompt":"hi"}' \
  | PATH="$NOPY_BIN" CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit" 2>"$TMP/nopy.err")"; rc=$?
! grep -qi 'dirname.*not found\|dirname.*command not found' "$TMP/nopy.err" || { echo "FAIL failopen-no-python3 setup: dirname missing from curated PATH"; cat "$TMP/nopy.err"; exit 1; }
[ "$rc" = 0 ] && [ -z "$out" ] && echo "OK failopen-no-python3" || { echo "FAIL failopen-no-python3 rc=$rc"; echo "$out"; exit 1; }

# ---- fail-open: $DATA unwritable ----
SD="$(mktemp -d)"; chmod 555 "$SD"
out="$(printf '%s' '{"session_id":"sess-nowrite","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"; rc=$?
chmod 755 "$SD"
[ "$rc" = 0 ] && [ -z "$out" ] && echo "OK failopen-data-unwritable" || { echo "FAIL failopen-data-unwritable rc=$rc"; echo "$out"; exit 1; }

# ---- fail-open: corrupt/unparsable session file ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-corrupt)"
printf 'active=1\nprompt_count=garbage\nlast_inject_ts=123\n' > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-corrupt","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && echo "OK failopen-corrupt-session" || { echo "FAIL failopen-corrupt-session rc=$rc"; echo "$out"; exit 1; }

# ---- marker concurrency: two claims against one `want` -> exactly one wins, other silent ----
SD="$(mktemp -d)"
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" want-on >/dev/null
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" claim sess-race1 >/dev/null
CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" claim sess-race2 >/dev/null
st1="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-race1)"
st2="$(CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/lib/state.sh" status sess-race2)"
ok=0
if [ -n "$st1" ] && [ -z "$st2" ]; then ok=1; winner="$st1"
elif [ -z "$st1" ] && [ -n "$st2" ]; then ok=1; winner="$st2"; fi
[ "$ok" = 1 ] && echo "OK state-claim-concurrency-exactly-one-wins" || { echo "FAIL state-claim-concurrency-exactly-one-wins: st1=$st1 st2=$st2"; exit 1; }
# claim initialises prompt_count/last_inject_ts the same way `/on` does (active, count 0).
echo "$winner" | grep -qE '^active 0 [0-9]+$' && echo "OK state-claim-inits-like-on" \
  || { echo "FAIL state-claim-inits-like-on: $winner"; exit 1; }

# ---- hooks/session-start: skeleton injected on `compact` with active state ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-compact)"
printf 'active=1\nprompt_count=5\nlast_inject_ts=1\n' > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-compact","source":"compact"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/session-start")"
echo "$out" | grep -q 'MANAGER MODE IS ACTIVE' && grep -q '^prompt_count=0$' "$SD/sessions/$K" \
  && echo "OK sessionstart-compact-skeleton" || { echo "FAIL sessionstart-compact-skeleton"; echo "$out"; exit 1; }

# ---- hooks/session-start: same on `source=resume` ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-resume)"
printf 'active=1\nprompt_count=0\nlast_inject_ts=1\n' > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-resume","source":"resume"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/session-start")"
echo "$out" | grep -q 'MANAGER MODE IS ACTIVE' && echo "OK sessionstart-resume-skeleton" \
  || { echo "FAIL sessionstart-resume-skeleton"; echo "$out"; exit 1; }

# ---- hooks/session-start: silence with no state ----
SD="$(mktemp -d)"
out="$(printf '%s' '{"session_id":"sess-nostate2","source":"compact"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/session-start")"
[ -z "$out" ] && echo "OK sessionstart-silent-no-state" || { echo "FAIL sessionstart-silent-no-state"; echo "$out"; exit 1; }

# ---- hooks/session-start: `clear` deletes the state ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-clear)"
printf 'active=1\nprompt_count=0\nlast_inject_ts=1\n' > "$SD/sessions/$K"
out="$(printf '%s' '{"session_id":"sess-clear","source":"clear"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/session-start")"
[ -z "$out" ] && [ ! -f "$SD/sessions/$K" ] && echo "OK sessionstart-clear-deletes" \
  || { echo "FAIL sessionstart-clear-deletes"; echo "$out"; exit 1; }

# ---- hooks/session-start: counter reset suppresses an immediate duplicate injection ----
SD="$(mktemp -d)"; mkdir -p "$SD/sessions"
K="$(skey sess-dedup)"
printf 'active=1\nprompt_count=8\nlast_inject_ts=1\n' > "$SD/sessions/$K"   # would be ripe
out="$(printf '%s' '{"session_id":"sess-dedup","source":"compact"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/session-start")"
echo "$out" | grep -q 'MANAGER MODE IS ACTIVE' || { echo "FAIL sessionstart-counter-reset-suppresses (sanity)"; exit 1; }
out2="$(printf '%s' '{"session_id":"sess-dedup","prompt":"hi"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$SD" bash "$ROOT/hooks/user-prompt-submit")"
[ -z "$out2" ] && echo "OK sessionstart-counter-reset-suppresses-duplicate" \
  || { echo "FAIL sessionstart-counter-reset-suppresses-duplicate"; echo "$out2"; exit 1; }

# ---- hooks.json parses as valid JSON; both hook scripts are executable ----
python3 -c "import json; json.load(open('$ROOT/hooks/hooks.json'))" >/dev/null 2>&1
hjrc=$?
[ "$hjrc" = 0 ] && [ -x "$ROOT/hooks/user-prompt-submit" ] && [ -x "$ROOT/hooks/session-start" ] \
  && echo "OK hooks-json-valid-and-executable" || { echo "FAIL hooks-json-valid-and-executable hjrc=$hjrc"; exit 1; }

# ---- SKILL_FILES: content lands in prompt.txt; section headers present; frozen copies exist ----
mkdir -p "$TMP/skills"
cat > "$TMP/skills/one.md" <<'EOF'
# Skill One
Some content line.
EOF
cat > "$TMP/req-skill1.md" <<EOF
MODE: review
Do the thing.

SKILL_FILES:
  - $TMP/skills/one.md
EOF
set_verifiers mpass
O="$( cd "$TMP" && run prepare review high "$TMP/req-skill1.md" 2>/dev/null )"
RUNSK1="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
# NOTE: the slug in `=== SKILL: <slug> ===` is the frozen file's basename (minus .md), which
# carries the NN- disambiguation prefix build_prompt reads off disk — so "one.md" freezes to
# "01-one.md" and renders as "=== SKILL: 01-one ===", not "=== SKILL: one ===".
grep -q '=== SKILL: 01-one ===' "$RUNSK1/prompt.txt" && grep -q '=== END SKILL: 01-one ===' "$RUNSK1/prompt.txt" \
  && grep -q 'Some content line.' "$RUNSK1/prompt.txt" && [ -f "$RUNSK1/skills/01-one.md" ] \
  && echo "OK skillfiles-content-headers-frozen-copy" || { echo "FAIL skillfiles-content-headers-frozen-copy"; exit 1; }

# SKILL sections appear BEFORE the last REQUEST_ID: line
lastreqid_line="$(grep -n '^REQUEST_ID:' "$RUNSK1/prompt.txt" | tail -1 | cut -d: -f1)"
skill_line="$(grep -n '=== SKILL: 01-one ===' "$RUNSK1/prompt.txt" | head -1 | cut -d: -f1)"
[ -n "$skill_line" ] && [ -n "$lastreqid_line" ] && [ "$skill_line" -lt "$lastreqid_line" ] \
  && echo "OK skillfiles-before-last-request-id" || { echo "FAIL skillfiles-before-last-request-id"; exit 1; }

# ---- the SKILL_FILES: block itself is STRIPPED from prompt.txt (content stays) ----
# A verifier that sees a skill PATH reaches for it, and those paths sit outside the dirs an
# adapter puts in the CLI workspace, so the read is auto-denied in headless mode — fatal for
# agy (exits 0 with no output -> empty verdict -> FAIL). The content is already spliced in as
# a `=== SKILL: ... ===` section, so nothing is lost by dropping the paths.
! grep -q '^SKILL_FILES:' "$RUNSK1/prompt.txt" && ! grep -q "$TMP/skills/one.md" "$RUNSK1/prompt.txt" \
  && grep -q 'Some content line.' "$RUNSK1/prompt.txt" \
  && echo "OK skillfiles-block-stripped-from-prompt" \
  || { echo "FAIL skillfiles-block-stripped-from-prompt"; grep -n 'SKILL_FILES\|one.md' "$RUNSK1/prompt.txt"; exit 1; }

# ---- a skill file containing STATUS:/REQUEST_ID: lines must not break verdict classification ----
# (this is the one SKILL_FILES case that genuinely needs collect — via prepare+run-one+collect,
# never the synchronous panel-wait `run` form.)
cat > "$TMP/skills/tricky.md" <<'EOF'
# Tricky Skill
STATUS: CHANGES_REQUESTED
REQUEST_ID: FAKE-NONCE-SHOULD-BE-IGNORED
Some convention text.
EOF
cat > "$TMP/req-skill2.md" <<EOF
MODE: review
Do the thing.

SKILL_FILES:
  - $TMP/skills/tricky.md
EOF
set_verifiers mpass
O="$( cd "$TMP" && run prepare review high "$TMP/req-skill2.md" 2>/dev/null )"
RUNSK2="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
( cd "$TMP" && run run-one "$RUNSK2" 1-mpass ) >/dev/null 2>&1
out="$( cd "$TMP" && run collect "$RUNSK2" 2>/dev/null )"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q '\[1-mpass\] PASS' \
  && echo "OK skillfiles-tricky-status-doesnt-break-classification" \
  || { echo "FAIL skillfiles-tricky-status-doesnt-break-classification rc=$rc"; echo "$out"; exit 1; }

# ---- warning for a missing skill file ----
cat > "$TMP/req-skill3.md" <<EOF
MODE: review
SKILL_FILES:
  - $TMP/skills/does-not-exist.md
EOF
err="$( cd "$TMP" && run prepare review high "$TMP/req-skill3.md" 2>&1 >/dev/null )"
echo "$err" | grep -qi 'skip (missing' && echo "OK skillfiles-missing-file-warns" \
  || { echo "FAIL skillfiles-missing-file-warns"; echo "$err"; exit 1; }

# ---- block terminator does not swallow a following bullet list ----
cat > "$TMP/req-skill4.md" <<EOF
MODE: review
SKILL_FILES:
  - $TMP/skills/one.md

Notes:
- first bullet
- second bullet
EOF
O="$( cd "$TMP" && run prepare review high "$TMP/req-skill4.md" 2>/dev/null )"
RUNSK4="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
grep -q '^- first bullet$' "$RUNSK4/prompt.txt" && grep -q '^- second bullet$' "$RUNSK4/prompt.txt" \
  && echo "OK skillfiles-terminator-preserves-bullets" || { echo "FAIL skillfiles-terminator-preserves-bullets"; exit 1; }

# ---- a path with a space, and a `~` path (HOME overridden for this call only, no touching
# the real $HOME) ----
mkdir -p "$TMP/skills/dir with space"
cat > "$TMP/skills/dir with space/spaced.md" <<'EOF'
# Spaced Skill
content
EOF
mkdir -p "$TMP/fakehome/.claude-companion-smoke-test"
cat > "$TMP/fakehome/.claude-companion-smoke-test/tilde.md" <<'EOF'
# Tilde Skill
content
EOF
cat > "$TMP/req-skill5.md" <<EOF
MODE: review
SKILL_FILES:
  - $TMP/skills/dir with space/spaced.md
  - ~/.claude-companion-smoke-test/tilde.md
EOF
O="$( cd "$TMP" && HOME="$TMP/fakehome" run prepare review high "$TMP/req-skill5.md" 2>/dev/null )"
RUNSK5="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
# slugs carry the NN- freeze prefix (see note above): spaced.md is entry 1, tilde.md is entry 2.
grep -q '=== SKILL: 01-spaced ===' "$RUNSK5/prompt.txt" && grep -q '=== SKILL: 02-tilde ===' "$RUNSK5/prompt.txt" \
  && echo "OK skillfiles-space-and-tilde-path" || { echo "FAIL skillfiles-space-and-tilde-path"; exit 1; }

# ---- duplicates dedup; basename collision gets an NN- prefix ----
mkdir -p "$TMP/skills/altdir"
cat > "$TMP/skills/altdir/one.md" <<'EOF'
# Alt One
alt content
EOF
cat > "$TMP/req-skill6.md" <<EOF
MODE: review
SKILL_FILES:
  - $TMP/skills/one.md
  - $TMP/skills/one.md
  - $TMP/skills/altdir/one.md
EOF
O="$( cd "$TMP" && run prepare review high "$TMP/req-skill6.md" 2>/dev/null )"
RUNSK6="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
cnt="$(find "$RUNSK6/skills" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
[ "$cnt" = 2 ] && [ -f "$RUNSK6/skills/01-one.md" ] && [ -f "$RUNSK6/skills/02-one.md" ] \
  && echo "OK skillfiles-dedup-and-basename-collision" \
  || { echo "FAIL skillfiles-dedup-and-basename-collision cnt=$cnt"; find "$RUNSK6/skills" 2>&1; exit 1; }

# ---- a non-.md path is rejected with a warning ----
cat > "$TMP/skills/notmd.txt" <<'EOF'
plain text
EOF
cat > "$TMP/req-skill7.md" <<EOF
MODE: review
SKILL_FILES:
  - $TMP/skills/notmd.txt
EOF
err="$( cd "$TMP" && run prepare review high "$TMP/req-skill7.md" 2>&1 >/dev/null )"
echo "$err" | grep -qi 'not .md' && echo "OK skillfiles-nonmd-rejected" \
  || { echo "FAIL skillfiles-nonmd-rejected"; echo "$err"; exit 1; }

# ---- a `.md` SYMLINK whose resolved target is NOT a .md file is REJECTED (validation must
# run against the resolved target, not the symlink's own name) ----
cat > "$TMP/skills/secret.txt" <<'EOF'
super secret content, must never reach a verifier prompt
EOF
ln -sf "$TMP/skills/secret.txt" "$TMP/skills/looks-like-skill.md"
cat > "$TMP/req-skill8.md" <<EOF
MODE: review
SKILL_FILES:
  - $TMP/skills/looks-like-skill.md
EOF
out8="$( cd "$TMP" && run prepare review high "$TMP/req-skill8.md" 2>"$TMP/skill8.err" )"
RUNSK8="$(printf '%s\n' "$out8" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
err8="$(cat "$TMP/skill8.err")"
no_frozen=1
[ -d "$RUNSK8/skills" ] && [ -n "$(find "$RUNSK8/skills" -maxdepth 1 -type f 2>/dev/null)" ] && no_frozen=0
echo "$err8" | grep -qi 'not .md' && [ "$no_frozen" = 1 ] \
  && echo "OK skillfiles-md-symlink-to-nonmd-target-rejected" \
  || { echo "FAIL skillfiles-md-symlink-to-nonmd-target-rejected"; echo "$err8"; exit 1; }

# ---- a >64 KB file gets the [truncated] marker ----
python3 -c "print('A' * 70000)" > "$TMP/skills/big.md" 2>/dev/null
[ -s "$TMP/skills/big.md" ] || yes AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA \
  | head -c 70000 > "$TMP/skills/big.md"
cat > "$TMP/req-skill9.md" <<EOF
MODE: review
SKILL_FILES:
  - $TMP/skills/big.md
EOF
O="$( cd "$TMP" && run prepare review high "$TMP/req-skill9.md" 2>/dev/null )"
RUNSK9="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
grep -q '\[truncated\]' "$RUNSK9/skills/01-big.md" && grep -q '\[truncated\]' "$RUNSK9/prompt.txt" \
  && echo "OK skillfiles-oversize-truncated-marker" || { echo "FAIL skillfiles-oversize-truncated-marker"; exit 1; }

# ---- a request with NO SKILL_FILES block produces a byte-identical prompt.txt ----
cat > "$TMP/req-noskill.md" <<'EOF'
MODE: review
Just a plain request, no skill files here.
EOF
O="$( cd "$TMP" && run prepare review high "$TMP/req-noskill.md" 2>/dev/null )"
RUNNOSK="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
reqid_ns="$(awk -F'\t' '$1=="reqid"{print $2}' "$RUNNOSK/manifest")"
repo_ns="$(awk -F'\t' '$1=="repo"{print $2}' "$RUNNOSK/manifest")"
{ cat "$ROOT/VERIFIER.md" 2>/dev/null
  cat "$TMP/req-noskill.md"
  printf '\nREQUEST_ID: %s\n' "$reqid_ns"
  [ -s "$RUNNOSK/diff.patch" ] && printf 'DIFF_PATCH: %s\n' "$RUNNOSK/diff.patch"
  printf 'REPO_ROOT: %s\n' "$repo_ns"
} > "$TMP/expected-noskill-prompt.txt"
diff -q "$TMP/expected-noskill-prompt.txt" "$RUNNOSK/prompt.txt" >/dev/null 2>&1 && [ ! -d "$RUNNOSK/skills" ] \
  && echo "OK skillfiles-noblock-byte-identical-prompt" \
  || { echo "FAIL skillfiles-noblock-byte-identical-prompt"; diff "$TMP/expected-noskill-prompt.txt" "$RUNNOSK/prompt.txt"; exit 1; }

echo "ALL SMOKE OK"
