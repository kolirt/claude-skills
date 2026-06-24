#!/usr/bin/env bash
# Verifier adapter for the Google Gemini CLI (https://geminicli.com).
# probe: usable only if the binary exists AND a non-interactive API key is set
#        (headless auth needs GEMINI_API_KEY; OAuth login is interactive-only).
# run:   feed the prompt on stdin (non-TTY → headless), capture the answer to <out>.
set -uo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v gemini >/dev/null 2>&1 || exit 64
    [ -n "${GEMINI_API_KEY:-}" ] || exit 64
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:-}"; out="${3:?}"
    : "${effort:=}"  # Gemini CLI has no reasoning-effort knob; ignored.
    # stdin (redirected, non-TTY) is read as the prompt and forces headless mode.
    # approval-mode=plan = read-only "plan" mode: the agent may read/grep/glob files
    # but cannot run any filesystem-mutating tool (write_file/replace) — a read-only
    # sandbox for a verifier. skip-trust avoids the repo trust prompt. Confirmed
    # against the gemini CLI as the correct headless read-only invocation.
    gemini --approval-mode=plan --skip-trust < "$prompt" > "$out" 2>/dev/null
    exit $?;;
  *) echo "usage: gemini.sh probe|run" >&2; exit 64;;
esac
