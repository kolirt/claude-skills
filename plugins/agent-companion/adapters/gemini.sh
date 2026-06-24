#!/usr/bin/env bash
# Verifier adapter for the Google Gemini CLI (https://geminicli.com).
# probe: only checks the binary is installed. Auth is gemini's own business — it may
#        be a browser/OAuth login, a settings file, or GEMINI_API_KEY; we do NOT
#        require any specific method. If gemini isn't authenticated the run fails and
#        the dispatcher logs its stderr.
# run:   feed the prompt on stdin (non-TTY → headless), capture the answer to <out>.
set -uo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v gemini >/dev/null 2>&1 || exit 64
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:-}"; out="${3:?}"
    : "${effort:=}"  # Gemini CLI has no reasoning-effort knob; ignored.
    # stdin (redirected, non-TTY) is read as the prompt and forces headless mode.
    # approval-mode=plan = read-only "plan" mode: the agent may read/grep/glob files
    # but cannot run any filesystem-mutating tool (write_file/replace) — a read-only
    # sandbox for a verifier. skip-trust avoids the repo trust prompt. Confirmed
    # against the gemini CLI as the correct headless read-only invocation.
    # stdout = verdict; stderr left to the caller (dispatcher logs it for diagnosis).
    gemini --approval-mode=plan --skip-trust < "$prompt" > "$out"
    exit $?;;
  *) echo "usage: gemini.sh probe|run" >&2; exit 64;;
esac
