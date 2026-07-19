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
    agy --help 2>&1 | grep -q -- '--mode' || exit 64
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
    # --mode plan is NOT a write barrier (verified: in a scratch project it happily creates
    # files). What actually stops writes here is headless permission handling: inside the
    # workspace a write_file call cannot be prompted for and is auto-denied. We simply never
    # pass --dangerously-skip-permissions. NOTE: a user who adds write rules under
    # permissions.allow in ~/.gemini/antigravity-cli/settings.json weakens that barrier.
    #
    # --print-timeout stays below the dispatcher's own per-verifier cap (default 1800s) so a
    # slow run ends with agy's own diagnostic instead of being SIGKILLed mid-sentence.
    #
    # model is optional (4th arg): absent -> agy's configured default. When present it was
    # already resolved against `models` when the entry was added, so it goes through as-is;
    # an unknown name makes agy exit 1 and print its own list, which is the right failure.
    if [ -n "$model" ]; then
      agy --mode plan --add-dir "$PWD" --print-timeout 25m --model "$model" -p "$(cat "$prompt")" > "$out"
    else
      agy --mode plan --add-dir "$PWD" --print-timeout 25m -p "$(cat "$prompt")" > "$out"
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
