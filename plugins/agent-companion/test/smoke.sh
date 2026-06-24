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

echo "ALL SMOKE OK"
