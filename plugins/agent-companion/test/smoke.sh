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
  mk "STATUS: PASS";               ok p6 audit    FAIL   # wrong-mode status -> fail-closed
) || exit 1
echo "OK classify-matrix"

echo "ALL SMOKE OK"
