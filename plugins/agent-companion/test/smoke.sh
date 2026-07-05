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

# review, all pass -> exit 0
printf 'mpass\n' > "$DATA/verifiers.conf"
echo "MODE: review" > "$TMP/req.md"
( cd "$TMP" && git init -q )   # a repo for git diff
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 0 ] && echo "OK pass-only" || { echo "FAIL expected 0 got $rc"; exit 1; }

# review, one changes -> exit 10 (any-blocks)
printf 'mpass\nmchg\n' > "$DATA/verifiers.conf"
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 10 ] && echo "OK any-blocks" || { echo "FAIL expected 10 got $rc"; exit 1; }

# missing verifier skipped, remaining pass -> exit 0, summary lists skip
printf 'mpass\nmgone\n' > "$DATA/verifiers.conf"
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -qi 'skip' && echo "OK skip-listed" || { echo "FAIL skip handling: $rc"; exit 1; }

# adapter run fails (rc!=0) -> classified FAIL -> review blocks (exit 10)
printf 'mpass\nmfail\n' > "$DATA/verifiers.conf"
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
[ "$rc" = 10 ] && echo "$out" | grep -q '\[mfail\] FAIL' && echo "OK run-fail blocks" || { echo "FAIL run-fail handling: $rc"; exit 1; }

# probe returns unknown code (not 0/64) -> fail-closed FAIL -> review blocks
printf 'mpass\nmprobe\n' > "$DATA/verifiers.conf"
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
[ "$rc" = 10 ] && echo "$out" | grep -q '\[mprobe\] FAIL' && echo "OK probe-unknown blocks" || { echo "FAIL probe-unknown handling: $rc"; exit 1; }

# --- synthesizer ---
cat > "$ROOT/adapters/msynth.sh" <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
printf 'CONSOLIDATED_OK (merged report)\n' > "$4"
A
chmod +x "$ROOT/adapters/msynth.sh"

# 2 reports + synthesizer -> consolidated output; gate still deterministic (mchg => exit 10)
printf 'mpass\nmchg\n' > "$DATA/verifiers.conf"
printf 'msynth\n' > "$DATA/synthesizer.conf"
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
echo "$out" | grep -q 'consolidated report (by msynth' && echo "$out" | grep -q 'CONSOLIDATED_OK' && [ "$rc" = 10 ] \
  && echo "OK synth-2reports" || { echo "FAIL synth-2reports rc=$rc"; echo "$out"; exit 1; }

# 1 report + synthesizer set -> NO synthesis (single report returned as-is)
printf 'mpass\n' > "$DATA/verifiers.conf"
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
! echo "$out" | grep -q 'consolidated report' && [ "$rc" = 0 ] \
  && echo "OK synth-skip-1report" || { echo "FAIL synth-1report rc=$rc"; echo "$out"; exit 1; }

# synthesizer=none + 2 reports -> compact listing, no consolidation
printf 'mpass\nmchg\n' > "$DATA/verifiers.conf"
printf 'none\n' > "$DATA/synthesizer.conf"
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
! echo "$out" | grep -q 'consolidated report' && [ "$rc" = 10 ] \
  && echo "OK synth-none" || { echo "FAIL synth-none rc=$rc"; echo "$out"; exit 1; }
rm -f "$DATA/synthesizer.conf"

# --- markdown-wrapped verdict (e.g. Grok Build emits **STATUS:**/**REQUEST_ID:**) ---
# classify_verdict must tolerate emphasis decoration, else a valid PASS reads as FAIL.
cat > "$ROOT/adapters/mmd.sh" <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
printf '**STATUS: PASS**\n**REQUEST_ID: %s**\n' "$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')" > "$4"
A
chmod +x "$ROOT/adapters/mmd.sh"
printf 'mmd\n' > "$DATA/verifiers.conf"
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 0 ] && echo "OK markdown-wrapped-pass" || { echo "FAIL markdown-wrapped expected 0 got $rc"; exit 1; }

# key-only emphasis: **STATUS**: PASS / **REQUEST_ID**: <nonce> (bold around the key only)
cat > "$ROOT/adapters/mmd2.sh" <<'A'
#!/usr/bin/env bash
[ "$1" = probe ] && exit 0
printf '**STATUS**: PASS\n**REQUEST_ID**: %s\n' "$(grep '^REQUEST_ID:' "$2" | tail -1 | awk '{print $2}')" > "$4"
A
chmod +x "$ROOT/adapters/mmd2.sh"
printf 'mmd2\n' > "$DATA/verifiers.conf"
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 0 ] && echo "OK markdown-key-only-pass" || { echo "FAIL markdown-key-only expected 0 got $rc"; exit 1; }

# --- synthesizer excludes FAIL verdicts (M3) ---
# 2 valid reports (mpass + mchg) get consolidated; mfail is excluded yet surfaced.
printf 'mpass\nmchg\nmfail\n' > "$DATA/verifiers.conf"
printf 'msynth\n' > "$DATA/synthesizer.conf"
out="$( cd "$TMP" && run review medium "$TMP/req.md" 2>&1 )"; rc=$?
echo "$out" | grep -q 'consolidated report (by msynth · 2 agents' \
  && echo "$out" | grep -q 'FAIL — excluded from consolidation' && [ "$rc" = 10 ] \
  && echo "OK synth-excludes-fail" || { echo "FAIL synth-excludes-fail rc=$rc"; echo "$out"; exit 1; }
rm -f "$DATA/synthesizer.conf"

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
printf 'mhijack\n' > "$DATA/verifiers.conf"
( cd "$TMP" && run review medium "$TMP/req.md" ); rc=$?
[ "$rc" = 0 ] && echo "OK echoed-prompt-not-hijacked" || { echo "FAIL echoed-prompt expected 0 got $rc"; exit 1; }

# --- bad invocation (missing args) -> exit 64, not the shell default 1 ---
( cd "$TMP" && run review ); rc=$?
[ "$rc" = 64 ] && echo "OK bad-args-64" || { echo "FAIL bad-args expected 64 got $rc"; exit 1; }

# --- missing request file -> exit 64 ---
printf 'mpass\n' > "$DATA/verifiers.conf"
( cd "$TMP" && run review medium "$TMP/does-not-exist.md" ) >/dev/null 2>&1; rc=$?
[ "$rc" = 64 ] && echo "OK missing-reqfile-64" || { echo "FAIL missing-reqfile expected 64 got $rc"; exit 1; }

# --- unknown mode (typo) -> exit 64, NOT a silent non-gating exit 0 ---
printf 'mpass\n' > "$DATA/verifiers.conf"
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
printf 'mpass\nmgone\n' > "$DATA/verifiers.conf"
out="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"; rc=$?
RUNP="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
[ "$rc" = 0 ] \
  && printf '%s\n' "$out" | grep -q "^RUNNABLE	mpass$" \
  && printf '%s\n' "$out" | grep -q "^SPAWN	mpass	bash " \
  && printf '%s\n' "$out" | grep -q "^SKIP	mgone	unavailable$" \
  && [ -f "$RUNP/manifest" ] && [ -f "$RUNP/.inflight" ] && [ -f "$RUNP/prompt.txt" ] \
  && grep -q "^mode	review$" "$RUNP/manifest" \
  && grep -q "^runnable	mpass$" "$RUNP/manifest" \
  && grep -q "^skip	mgone	unavailable$" "$RUNP/manifest" \
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
printf 'mpass\n' > "$DATA/verifiers.conf"
( cd "$TMP" && run prepare review high "$TMP/req.md" ) >/dev/null 2>&1   # prepare runs cleanup_old
[ ! -d "$H/run-old-complete" ] && [ ! -d "$H/run-old-orphan" ] && [ -d "$H/run-old-inflight" ] \
  && echo "OK prepare-cleanup" || { echo "FAIL prepare-cleanup (complete=$([ -d "$H/run-old-complete" ]&&echo y) orphan=$([ -d "$H/run-old-orphan" ]&&echo y) inflight=$([ -d "$H/run-old-inflight" ]&&echo y))"; exit 1; }

# ---- run-one: writes rc+verdict on a prepared dir ----
printf 'mpass\n' > "$DATA/verifiers.conf"
out="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNO="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
( cd "$TMP" && run run-one "$RUNO" mpass ); rc=$?
[ "$rc" = 0 ] && [ "$(cat "$RUNO/mpass/rc")" = 0 ] \
  && [ -f "$RUNO/mpass/verdict" ] && [ -f "$RUNO/mpass/finished" ] \
  && echo "OK run-one-writes" || { echo "FAIL run-one-writes rc=$rc"; exit 1; }

# adapter failure (rc!=0) is recorded in rc, run-one itself still exits 0
printf 'mfail\n' > "$DATA/verifiers.conf"
out="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNF="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
( cd "$TMP" && run run-one "$RUNF" mfail ); rc=$?
[ "$rc" = 0 ] && [ "$(cat "$RUNF/mfail/rc")" = 3 ] \
  && echo "OK run-one-records-rc" || { echo "FAIL run-one-records-rc rc=$rc"; exit 1; }

# verifier not in runnable -> exit 64
( cd "$TMP" && run run-one "$RUNF" nope ) 2>/dev/null; rc=$?
[ "$rc" = 64 ] && echo "OK run-one-bad-verifier" || { echo "FAIL run-one-bad-verifier rc=$rc"; exit 1; }

# ---- collect: happy path (status + table + exit) ----
printf 'mpass\nmchg\n' > "$DATA/verifiers.conf"
O="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNC="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
printf '%s\n' "$O" | awk -F'\t' '$1=="RUNNABLE"{print $2}' | while IFS= read -r vv; do ( cd "$TMP" && run run-one "$RUNC" "$vv" ) >/dev/null 2>&1; done
out="$( cd "$TMP" && run collect "$RUNC" 2>/dev/null )"; rc=$?
[ "$rc" = 10 ] \
  && echo "$out" | grep -q '\[mpass\] PASS' \
  && echo "$out" | grep -q '\[mchg\] CHANGES' \
  && echo "$out" | grep -q '=== verdicts ===' \
  && echo "$out" | grep -q "mpass	PASS	$RUNC/mpass/verdict" \
  && [ -f "$RUNC/complete" ] && [ ! -f "$RUNC/.inflight" ] \
  && echo "OK collect-happy" || { echo "FAIL collect-happy rc=$rc"; echo "$out"; exit 1; }

# ---- collect: incomplete (runnable without rc) -> 64, MISSING, markers untouched ----
printf 'mpass\n' > "$DATA/verifiers.conf"
O="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNI="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
# deliberately do NOT run run-one
out="$( cd "$TMP" && run collect "$RUNI" 2>/dev/null )"; rc=$?
err="$( cd "$TMP" && run collect "$RUNI" 2>&1 >/dev/null )"
[ "$rc" = 64 ] && echo "$out" | grep -q "^MISSING	mpass$" \
  && echo "$err" | grep -q 'INCOMPLETE' \
  && [ -f "$RUNI/.inflight" ] && [ ! -f "$RUNI/complete" ] \
  && echo "OK collect-incomplete" || { echo "FAIL collect-incomplete rc=$rc"; echo "$out"; exit 1; }

# ---- collect: terminal NO_VERIFIER (all skip) -> 64, markers finalized ----
printf 'mgone\n' > "$DATA/verifiers.conf"
O="$( cd "$TMP" && run prepare review high "$TMP/req.md" 2>/dev/null )"
RUNN="$(printf '%s\n' "$O" | awk -F'\t' '$1=="RUN_DIR"{print $2; exit}')"
err="$( cd "$TMP" && run collect "$RUNN" 2>&1 >/dev/null )"; rc=$?
[ "$rc" = 64 ] && echo "$err" | grep -q 'NO_VERIFIER' \
  && [ -f "$RUNN/complete" ] && [ ! -f "$RUNN/.inflight" ] \
  && echo "OK collect-no-verifier" || { echo "FAIL collect-no-verifier rc=$rc"; echo "$err"; exit 1; }

echo "ALL SMOKE OK"
