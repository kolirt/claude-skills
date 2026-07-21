#!/usr/bin/env bash
# Verifier adapter for the Google Antigravity CLI (agy).
#
# probe:  checks the binary is installed and supports `--mode` (the plan-mode flag, which
#         doubles as a version floor — older releases lack it). Auth is agy's own business:
#         it is OAuth-browser-login only and exposes no reliable on-disk "logged in" marker,
#         so probe does NOT test it. An unauthenticated agy passes probe and fails at run.
# models: OPTIONAL in the adapter contract — prints one model display name per line. The
#         panel calls this ONCE, at `verifiers add` time, to resolve the user's loose input
#         to agy's own spelling. It is never on the verification hot path.
# run:    the prompt goes on argv (`-p` REQUIRES an argument — agy does not read stdin),
#         the answer is captured to <out>. The model arrives already canonical and is
#         passed to --model verbatim.
set -uo pipefail

# agy auto-updates itself in the background; a version change between probe and run would
# invalidate the capability check above. Pin the binary for every invocation below.
export AGY_CLI_DISABLE_AUTO_UPDATE=true

cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v agy >/dev/null 2>&1 || exit 64
    # --mode (accept-edits|plan) is the read-only-ish execution mode; absent on old builds.
    # Captured into a variable rather than piped into `grep -q`: grep exits on the first match
    # and closes the pipe, agy then dies of SIGPIPE (141), and `pipefail` promotes that 141 to
    # the pipeline status — so a PRESENT flag intermittently probed as absent and the verifier
    # was skipped at random (~60% of runs, verified via PIPESTATUS). A capability probe cares
    # only about the help TEXT, so the producer's exit status is deliberately discarded (`|| :`):
    # a CLI that prints usage and exits non-zero is still a usable CLI.
    # Matched on an OPTION BOUNDARY, not as a substring: agy's help lists both `--mode` and
    # `--model`, so a bare *"--mode"* glob would be satisfied by `--model` alone and would keep
    # passing on a build that had dropped the flag this adapter actually needs.
    # A herestring, not a pipe: it has no producer process, so the SIGPIPE race cannot come
    # back in through the very check that fixes it.
    help="$(agy --help 2>&1 || :)"
    grep -qE -- '(^|[[:space:]])--mode([[:space:]]|=|$)' <<<"$help" || exit 64
    exit 0;;
  models)
    # `agy models` prints display names only — there is no --json and unknown flags error
    # out, so stdout is the only interface. Names look like "Gemini 3.5 Flash (Medium)":
    # spaces and parentheses included, which is exactly why the panel stores models as
    # free-form data instead of packing them into an identifier.
    command -v agy >/dev/null 2>&1 || exit 64
    agy models 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$'
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:-}"; out="${3:?}"; model="${4:-}"
    : "${effort:=}"  # agy has no reasoning-effort knob — the tier is baked into the model
                     # name ("Gemini 3.1 Pro (High)"), so the effort field is ignored.
    # --add-dir is REQUIRED: in print mode agy ignores the caller's cwd and would otherwise
    # answer from an empty default scratch project, i.e. review nothing. verify.sh keeps the
    # caller's cwd at the repo root, so $PWD is the tree under review.
    #
    # THE RUN DIR IS A SECOND WORKSPACE ENTRY, and it is load-bearing. Inside an --add-dir
    # workspace agy auto-allows reads; OUTSIDE it a read needs a permission decision, which
    # headless mode cannot prompt for and therefore auto-DENIES. The request prompt points the
    # verifier at "$run/diff.patch" — the very artifact under review — which lives under
    # ~/.claude/plugins/data/..., NOT under the repo. With only $PWD in the workspace agy was
    # denied that read, printed nothing, and every agy verdict came back an empty FAIL.
    # Verified: adding the run dir makes the same read succeed (it reported the diff's exact
    # file count) with NO change to the user's settings.json.
    # Derived from $out rather than taken as a new argument, so the adapter contract stays
    # `run <prompt> <effort> <out> [model]`.
    # $out has TWO shapes: "<run>/<verifier>/verdict" for a verifier, but "<run>/consolidated
    # .txt" when this adapter runs as the SYNTHESIZER. Blindly going up two levels would, in
    # the synth case, land on the parent handoff dir and hand over read access to every
    # SIBLING run. So anchor on the file that marks a run dir instead of counting levels.
    # codex.sh derives run_dir the same way, for the same reason, once it too became confined.
    # kimi and grok still reach absolute paths outside their workspace and so do not need it.
    # FAIL CLOSED. An earlier version fell back to `dirname` unconditionally, so an $out whose
    # run dir carried no `manifest` silently resolved to the PARENT handoff dir — granting read
    # access to every sibling run. Never widen the workspace on a failed lookup: if neither
    # candidate is a run dir, refuse to run at all.
    run_dir="$(dirname "$out")"
    if [ ! -f "$run_dir/manifest" ]; then
      run_dir="$(dirname "$run_dir")"
      [ -f "$run_dir/manifest" ] || {
        echo "agy: cannot locate the run dir (no manifest beside or above \"$out\") —" \
             "refusing to run rather than widen the workspace." >&2
        exit 1
      }
    fi
    #
    # --mode plan is NOT a write barrier (verified: in a scratch project it happily creates
    # files). What actually stops writes here is headless permission handling: inside the
    # workspace a write_file call cannot be prompted for and is auto-denied. We simply never
    # pass --dangerously-skip-permissions. NOTE: a user who adds write rules under
    # permissions.allow in ~/.gemini/antigravity-cli/settings.json weakens that barrier.
    #
    # Adding the run dir above therefore grants READS ONLY, and does not let a verifier
    # tamper with the run (e.g. overwrite a peer's verdict). Verified directly: asked to
    # create a file and overwrite a canary inside an --add-dir'd directory, agy was denied
    # ("a tool required the write_file permission ... auto-denied"), the canary was byte
    # unchanged and no file appeared. Workspace membership auto-allows reads, never writes.
    #
    # --print-timeout stays below the dispatcher's own per-verifier cap (default 1800s) so a
    # slow run ends with agy's own diagnostic instead of being SIGKILLed mid-sentence.
    #
    # model is optional (4th arg): absent -> agy's configured default. When present it was
    # already resolved against `models` when the entry was added, so it goes through as-is;
    # an unknown name makes agy exit 1 and print its own list, which is the right failure.
    # --sandbox turns on agy's OS-level isolation, which confines the TERMINAL to the
    # --add-dir set. Reads by the model's own tools were already confined to the workspace
    # (that is why agy alone did not leak a $HOME canary, and why the run dir had to be
    # added above), so this closes the remaining path: shell commands reaching outside it.
    # Keep it alongside --mode plan; agy's own guidance is to remove neither for read/analysis
    # runs. Verified not to break the allowed reads: with --sandbox and a prompt touching only
    # workspace paths, agy read the run dir's diff.patch and answered normally.
    #
    # AGY DIES ON A DENIED READ — it does not degrade, it produces NOTHING.
    # Unlike codex (which reports the failed read in its answer and still returns a verdict),
    # a single unreadable path anywhere in the prompt ends the whole run: agy exits 0 having
    # printed nothing, and the guard below turns that into rc=1. Verified by A/B on one
    # prompt: with an out-of-workspace path in it -> empty verdict; with that path removed and
    # everything else identical -> correct answer.
    # So a request handed to agy must not name paths outside the workspace. This is not
    # hypothetical: it is why agy returned empty verdicts all session — the request's
    # `SKILL_FILES:` line pointed at ~/.claude/plugins/marketplaces/..., outside both
    # --add-dir roots. (Skill CONTENT is spliced into the prompt, so nothing needs to be read
    # from there — the bare path in the text was enough to kill the run.)
    # SHELL IS THE OTHER WAY TO TRIP THE SAME WIRE. A terminal call needs the `command`
    # permission, which headless mode cannot prompt for and therefore auto-DENIES — and by the
    # rule above one denial ends the run. This is NOT caused by --sandbox (A/B'd: with and
    # without the flag, a prompt asking for `cat` died identically); --sandbox only confines the
    # terminal to the --add-dir set, it does not create the permission gate. Nor is it a
    # regression from adding read-only confinement: agy could never run shell here. It stayed
    # invisible only while the model happened to answer via its file tools, and surfaced the
    # moment one reached for `git diff`.
    # Costs nothing to forbid: verified that agy solves the same task with list_dir +
    # view_file + grep_search, which are auto-allowed inside the workspace. The diff is
    # already materialised as a file ($run/diff.patch, named by the request's DIFF_PATCH:
    # line), so nothing here ever needs git.
    # Stated with its REASON rather than as a bare ban, so the model does not "try anyway".
    # Prepended by the adapter instead of living in VERIFIER.md: the other CLIs run shell
    # fine, and only agy dies for it.
    guard='TOOL CONSTRAINT (agy, headless print mode): shell/terminal tool calls require a
`command` permission that cannot be prompted for here and are therefore auto-denied — and a
single denied call aborts this entire run with no output. Do not run shell commands (git, ls,
grep, cat, find, rg). Use your file tools (list_dir, view_file, grep_search) inside the
--add-dir workspace, where reads are auto-allowed.'
    if [ -n "$model" ]; then
      agy --mode plan --sandbox --add-dir "$PWD" --add-dir "$run_dir" --print-timeout 25m --model "$model" -p "$guard

$(cat "$prompt")" > "$out"
    else
      agy --mode plan --sandbox --add-dir "$PWD" --add-dir "$run_dir" --print-timeout 25m -p "$guard

$(cat "$prompt")" > "$out"
    fi
    rc=$?
    # An auto-denied tool call makes agy exit 0 having printed NOTHING. Left alone that empty
    # file would be classified as a verdict, so turn the silent failure into a loud one.
    if [ "$rc" -eq 0 ] && [ ! -s "$out" ]; then
      echo "agy: exited 0 but produced no output — a tool call was likely auto-denied in headless mode." >&2
      exit 1
    fi
    exit "$rc";;
  *) echo "usage: agy.sh probe|models|run" >&2; exit 64;;
esac
