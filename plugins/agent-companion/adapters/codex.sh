#!/usr/bin/env bash
set -uo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v codex >/dev/null 2>&1 || exit 64
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:?}"; out="${3:?}"; model="${4:-}"

    # The run dir holds diff.patch — the artifact under review — and lives under
    # ~/.claude/plugins/data/..., NOT under the repo. Until the permission profile below
    # existed codex could read the whole disk, so this was free; a confined codex must be
    # given it as an explicit workspace root or it cannot read what it is reviewing.
    # $out is "<run>/<verifier>/verdict" for a verifier but "<run>/consolidated.txt" when
    # codex runs as the SYNTHESIZER, so anchor on the file that marks a run dir rather than
    # counting path levels (going up two would expose every SIBLING run in the synth case).
    run_dir="$(dirname "$out")"
    [ -f "$run_dir/manifest" ] || run_dir="$(dirname "$run_dir")"

    # --- read confinement (R2) --------------------------------------------------------
    # DO NOT pass --sandbox here. `--sandbox` switches codex to its sandbox model, which
    # supersedes permission profiles — and the sandbox model's `read-only` restricts WRITES
    # while leaving reads unrestricted across the whole filesystem (verified: a canary in
    # $HOME was read and echoed straight into the verdict). Permission profiles are the only
    # mechanism here that narrows READ scope.
    #
    # --ignore-user-config: the user's ~/.codex/config.toml may set sandbox_mode or its own
    # permissions, which would override or conflict with the profile below. The barrier must
    # not depend on a user config we do not control.
    # -C "$PWD": the repo under review becomes the primary workspace root (verify.sh keeps
    # the caller's cwd at the repo root). Passed explicitly rather than inherited so the
    # workspace-roots allowlist below has a defined meaning.
    # approval_policy="never": headless has nobody to answer a prompt; without this a tool
    # call that wants approval stalls or fails instead of being denied.
    # filesystem: ":minimal" = the system/runtime paths codex needs to function at all;
    # ":workspace_roots" = -C plus every --add-dir. "." = "read" grants read (never write)
    # across those roots; "**/*.env" = "deny" carves .env back OUT even inside them, so the
    # single most common in-repo secret is not readable by a verifier that legitimately has
    # the repo. Everything not listed is denied by default.
    # network.enabled=false: blocks the AGENT's network tools (web fetch/search) so readable
    # content cannot be exfiltrated out-of-band. It does NOT block codex's own API call to
    # its vendor — that is the CLI's transport, not an agent tool.
    perm_fs='permissions.readonly_selected.filesystem={":minimal"="read",":workspace_roots"={"."="read","**/*.env"="deny"}}'
    perm_net='permissions.readonly_selected.network={enabled=false}'

    # NOTE: `codex exec` does NOT accept --ask-for-approval (interactive-only flag);
    # passing it makes exec fail with rc=2.
    # stdout is discarded; stderr is left to the caller (the dispatcher logs it).
    # model is optional (4th arg): absent → codex's own default (its current frontier);
    # a bad model id surfaces as a codex error → non-zero rc → verdict FAIL (visible).
    if [ -n "$model" ]; then
      codex exec --ignore-user-config --ephemeral --skip-git-repo-check \
        -C "$PWD" --add-dir "$run_dir" \
        -c 'approval_policy="never"' \
        -c 'default_permissions="readonly_selected"' \
        -c "$perm_fs" -c "$perm_net" \
        -m "$model" -c model_reasoning_effort="$effort" -o "$out" - < "$prompt" >/dev/null
    else
      codex exec --ignore-user-config --ephemeral --skip-git-repo-check \
        -C "$PWD" --add-dir "$run_dir" \
        -c 'approval_policy="never"' \
        -c 'default_permissions="readonly_selected"' \
        -c "$perm_fs" -c "$perm_net" \
        -c model_reasoning_effort="$effort" -o "$out" - < "$prompt" >/dev/null
    fi
    exit $?;;
  *) echo "usage: codex.sh probe|run" >&2; exit 64;;
esac
