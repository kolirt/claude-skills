#!/usr/bin/env bash
# Verifier adapter for the Kimi Code CLI (kimi).
#
# probe:  checks the binary is installed, that `--help` advertises `--prompt` (the flag run
#         depends on, which doubles as a version floor), and that a source config.toml exists
#         to derive the sandbox home from. Auth is kimi's own business (`kimi login`,
#         device-code flow): there is no reliable on-disk "logged in" marker, so probe does
#         NOT test it. An unauthenticated kimi passes probe and fails at run.
# models: OPTIONAL in the adapter contract — prints one model alias per line. The panel calls
#         this ONCE, at `verifiers add` time, to resolve the user's loose input to kimi's own
#         spelling. It is never on the verification hot path. `provider list --json` is a
#         documented programmatic interface, but it carries no semver guarantee, so a failure
#         here degrades to empty stdout (= "this adapter cannot enumerate") rather than error.
# run:    the prompt goes on argv (`-p` REQUIRES an argument — kimi does not read stdin), the
#         answer is captured to <out>. The model arrives already canonical and is passed to
#         --model verbatim.
#
# READ-ONLY BARRIER — read this before changing the run branch.
# kimi has no read-only sandbox and no per-run permission flag. `--prompt` is mutually
# exclusive with ALL THREE permission-mode flags; the CLI rejects them outright:
#     Cannot combine --prompt with --auto. / --plan. / --yolo.
# Non-interactive mode fixes itself to the `auto` policy, which approves writes silently: a
# bare `kimi -p "create a file"` creates it, no prompt, exit 0. Verified.
# What DOES hold in prompt mode are static deny rules from config.toml, which apply on top of
# any permission mode. So the barrier here is a disposable KIMI_CODE_HOME whose config.toml is
# the user's own plus deny rules for every mutating tool. Verified enforced, not advisory:
# asked explicitly to write via Bash, the model chose to comply and the runtime denied the
# call ("Tool \"Bash\" was denied by permission rule") — the tree was untouched.
# Read/Glob/Grep stay allowed, including files outside --add-dir (the dispatcher hands over
# DIFF_PATCH as a path), which is all a reviewer needs.
set -uo pipefail

# The user's real kimi data root — the source for the sandbox config and the auth material.
# Respect a caller-set KIMI_CODE_HOME, since that is kimi's own override for this path.
KIMI_REAL_HOME="${KIMI_CODE_HOME:-$HOME/.kimi-code}"

cmd="${1:-}"; shift || true
case "$cmd" in
  probe)
    command -v kimi >/dev/null 2>&1 || exit 64
    # --prompt is load-bearing in run below; absent on old builds.
    # Captured into a variable rather than piped into `grep -q` — see the same fix in agy.sh:
    # `grep -q` closes the pipe on first match, the producer dies of SIGPIPE (141), and
    # `pipefail` turns that into a probe failure, skipping the verifier at random. Only the
    # help TEXT matters here, so the producer's exit status is discarded (`|| :`).
    # Matched on an OPTION BOUNDARY (see agy.sh): a bare *"--prompt"* glob would also be
    # satisfied by a longer unrelated flag such as `--prompt-file` or `--prompt-interactive`,
    # passing the probe on a build without the plain `--prompt` that `run` below depends on.
    help="$(kimi --help 2>&1 || :)"
    grep -qE -- '(^|[[:space:]])--prompt([[:space:]]|=|$)' <<<"$help" || exit 64
    # No source config.toml means no providers, no default model and nothing to derive the
    # sandboxed config from — kimi is installed but not set up. SKIP rather than fail.
    [ -r "$KIMI_REAL_HOME/config.toml" ] || exit 64
    exit 0;;
  models)
    # `kimi provider list --json` prints an object whose `.models` keys are the aliases
    # ("kimi-code/k3", "kimi-code/kimi-for-coding", ...). jq is not guaranteed on a user's
    # machine, so every failure path here prints nothing and exits 0 — the panel then just
    # stores the user's model verbatim.
    command -v kimi >/dev/null 2>&1 || exit 64
    command -v jq >/dev/null 2>&1 || exit 0
    kimi provider list --json 2>/dev/null \
      | jq -r '.models // {} | keys[]' 2>/dev/null \
      | grep -v '^$'
    exit 0;;
  run)
    prompt="${1:?}"; effort="${2:-}"; out="${3:?}"; model="${4:-}"

    # The run below switches cwd (see the neutral-cwd note), so any relative path handed in
    # would break. The dispatcher passes absolute paths, but make that independent of it.
    case "$prompt" in /*) ;; *) prompt="$PWD/$prompt";; esac
    case "$out"    in /*) ;; *) out="$PWD/$out";;       esac

    [ -r "$KIMI_REAL_HOME/config.toml" ] || {
      echo "kimi: no readable config.toml under $KIMI_REAL_HOME — run \`kimi login\` first." >&2
      exit 1
    }

    # Disposable data root for this one run. Rebuilt every time rather than cached, so it can
    # never go stale against the user's providers/models/default_model. Sessions, logs and
    # history land inside it and die with it, which also makes the run ephemeral.
    repo="$PWD"
    home="$(mktemp -d)" || { echo "kimi: could not create a sandbox home." >&2; exit 1; }
    # The sandbox must NOT live inside the repo under review: the run's cwd is placed in it,
    # and kimi walks cwd's ANCESTORS to find a project root — a sandbox beneath the repo would
    # rediscover the very `.mcp.json` the neutral cwd exists to avoid. TMPDIR can legitimately
    # point inside the tree, so check and relocate rather than assume.
    case "$home/" in
      "$repo"/*)
        rm -rf "$home"
        home="$(TMPDIR=/tmp mktemp -d)" || { echo "kimi: could not create a sandbox home." >&2; exit 1; }
        case "$home/" in
          "$repo"/*) echo "kimi: cannot place a sandbox outside $repo — refusing to run." >&2
                     rm -rf "$home"; exit 1;;
        esac;;
    esac
    # Cleanup on EXIT; a signal must additionally STOP, or the script would carry on mid-run
    # against a home it just deleted. The EXIT trap then re-runs harmlessly (rm -rf, no dir).
    trap 'rm -rf "$home"' EXIT
    trap 'rm -rf "$home"; exit 130' INT
    trap 'rm -rf "$home"; exit 143' TERM

    # The sandbox config is built as an ALLOW-LIST of the user's tables, not a block-list.
    # A block-list has to enumerate every construct that can execute something — [[hooks]]
    # (arbitrary shell on PreToolUse etc., entirely OUTSIDE the tool-permission layer) and
    # mcp_servers (a command kimi SPAWNS at startup, which the deny globs below cannot stop
    # because they only govern tool CALLS) — and it has to do so across every legal TOML
    # spelling of each: [[ hooks ]], [["hooks"]], [['hooks']], [hooks], inline hooks = [...].
    # Any spelling missed, or any future feature that runs a command, silently gets through.
    # Keeping only what a verifier demonstrably needs inverts that: unknown constructs are
    # dropped by default, so the barrier fails closed as the CLI grows.
    # Kept: default_model, [providers*], [models*], [thinking]. Everything else — including
    # the user's own [[permission.rules]], which our injected rules below replace — is dropped.
    awk '
      /^[[:space:]]*\[/ {
        intable = 1
        keep = ($0 ~ /^[[:space:]]*\[\[?[[:space:]]*["'"'"']?providers["'"'"']?/) ||
               ($0 ~ /^[[:space:]]*\[\[?[[:space:]]*["'"'"']?models["'"'"']?/)    ||
               ($0 ~ /^[[:space:]]*\[\[?[[:space:]]*["'"'"']?thinking["'"'"']?[[:space:]]*\]/)
      }
      !intable && /^[[:space:]]*["'"'"']?default_model["'"'"']?[[:space:]]*=/ { print; next }
      intable && keep { print }
    ' "$KIMI_REAL_HOME/config.toml" > "$home/config.toml" || {
      echo "kimi: could not build the sandbox config." >&2; exit 1
    }
    # Fail closed: an empty or hook-only source would leave kimi with no provider at all.
    [ -s "$home/config.toml" ] || { echo "kimi: sandbox config came out empty." >&2; exit 1; }

    # Auth material is symlinked, not copied: a token refreshed mid-run then persists to the
    # user's real store instead of dying with the sandbox.
    for d in credentials oauth; do
      [ -e "$KIMI_REAL_HOME/$d" ] && ln -sfn "$KIMI_REAL_HOME/$d" "$home/$d"
    done
    [ -e "$KIMI_REAL_HOME/device_id" ] && cp "$KIMI_REAL_HOME/device_id" "$home/device_id"

    # --- reasoning effort -------------------------------------------------------------
    # kimi has no CLI flag for effort, but each model table carries `default_effort` plus the
    # `support_efforts` it accepts. Since the config above is ours to shape, the dispatch
    # effort is applied by rewriting that key for the model this run will use.
    # Silently skipped when: no effort was requested, the model has no [models."<id>"] table
    # (aliases resolved by the provider need not have one), or it declares no support_efforts.
    if [ -n "$effort" ]; then
      eff_model="$model"
      [ -n "$eff_model" ] || eff_model="$(awk -F'"' '
        /^[[:space:]]*default_model[[:space:]]*=/ { print $2; exit }' "$home/config.toml")"

      if [ -n "$eff_model" ]; then
        hdr="[models.\"$eff_model\"]"
        # The support_efforts line inside that model's table, if any.
        supported="$(awk -v hdr="$hdr" '
          index($0, hdr) == 1 { inblk = 1; next }
          inblk && /^[[:space:]]*\[/ { inblk = 0 }
          inblk && /^[[:space:]]*support_efforts[[:space:]]*=/ { print; exit }
        ' "$home/config.toml" | grep -oE '"[a-z]+"' | tr -d '"')"

        if [ -n "$supported" ]; then
          # Ladder shared with the dispatcher's own tiers. A model rarely supports all five
          # (k3 offers low/high/max), so map the request to the nearest tier it does support.
          # Ties round UP: an under-powered reviewer costs more than an over-powered one.
          ladder="low medium high xhigh max"
          req=-1; i=0
          for t in $ladder; do [ "$t" = "$effort" ] && req=$i; i=$((i + 1)); done

          if [ "$req" -ge 0 ]; then
            best=""; bestd=99; besti=-1
            for s in $supported; do
              j=0; idx=-1
              for t in $ladder; do [ "$t" = "$s" ] && idx=$j; j=$((j + 1)); done
              [ "$idx" -ge 0 ] || continue
              d=$((idx - req)); [ "$d" -lt 0 ] && d=$((-d))
              # Ties round UP, decided by LADDER position — not by the order support_efforts
              # happens to list, which is arbitrary (["high","low"] is as valid as ["low","high"]).
              if [ "$d" -lt "$bestd" ] || { [ "$d" -eq "$bestd" ] && [ "$idx" -gt "$besti" ]; }; then
                bestd=$d; besti=$idx; best="$s"
              fi
            done

            if [ -n "$best" ]; then
              # default_effort lives INSIDE [models."<id>"], so it must be replaced in place —
              # appending a second [models."<id>"] table would be a duplicate-table TOML error.
              awk -v hdr="$hdr" -v eff="$best" '
                index($0, hdr) == 1 { print; inblk = 1; done = 0; next }
                inblk && /^[[:space:]]*\[/ {
                  if (!done) { print "default_effort = \"" eff "\""; done = 1 }
                  inblk = 0
                }
                inblk && /^[[:space:]]*["'"'"']?default_effort["'"'"']?[[:space:]]*=/ {
                  print "default_effort = \"" eff "\""; done = 1; next
                }
                { print }
                END { if (inblk && !done) print "default_effort = \"" eff "\"" }
              ' "$home/config.toml" > "$home/config.next" && mv "$home/config.next" "$home/config.toml"

              # `[thinking].effort` outranks a model's default_effort, so setting only the
              # latter would be inert whenever the user has a [thinking] section (they
              # commonly do). Set both, to the same tier, leaving no contradictory source.
              if grep -qE '^[[:space:]]*\[[[:space:]]*["'"'"']?thinking["'"'"']?[[:space:]]*\]' "$home/config.toml"; then
                awk -v eff="$best" '
                  /^[[:space:]]*\[[[:space:]]*["'"'"']?thinking["'"'"']?[[:space:]]*\]/ { print; inblk = 1; done = 0; next }
                  inblk && /^[[:space:]]*\[/ {
                    if (!done) { print "effort = \"" eff "\""; done = 1 }
                    inblk = 0
                  }
                  inblk && /^[[:space:]]*["'"'"']?effort["'"'"']?[[:space:]]*=/ {
                    print "effort = \"" eff "\""; done = 1; next
                  }
                  { print }
                  END { if (inblk && !done) print "effort = \"" eff "\"" }
                ' "$home/config.toml" > "$home/config.next" && mv "$home/config.next" "$home/config.toml"
              else
                printf '\n[thinking]\neffort = "%s"\n' "$best" >> "$home/config.toml"
              fi
            fi
          fi
        fi
      fi
    fi

    # The barrier itself: static deny rules hold regardless of permission mode.
    #
    # Rule semantics, both verified against this CLI:
    #  - deny beats allow no matter the order (an `allow`/Bash at line 39 lost to a `deny`/Bash
    #    at line 96), so a permissive user config cannot punch through what we append here;
    #  - patterns are globs (`Gl*` denied `Glob`).
    # A deny therefore cannot be carved out by a narrower allow — `deny "*"` plus
    # `allow "Read"` denies Read too, verified. So an allow-list is impossible and this MUST
    # be an exhaustive block-list. Keep it in sync with kimi's tool set when the CLI updates.
    #
    # The full tool set, straight from the CLI: Agent, AgentSwarm, AskUserQuestion, Bash,
    # CreateGoal, CronCreate, CronDelete, CronList, Edit, EnterPlanMode, ExitPlanMode,
    # FetchURL, GetGoal, Glob, Grep, Read, ReadMediaFile, SetGoalBudget, Skill, TaskList,
    # TaskOutput, TaskStop, TodoList, UpdateGoal, WebSearch, Write. Denied below is everything
    # that can change state; Read/Glob/Grep/ReadMediaFile and the inert listing tools stay.
    #
    # Bash is denied WHOLESALE: kimi runs shell commands locally with no sandbox, so an
    # allowed Bash is a hole straight through the guarantee (`echo x > file`, or any
    # interpreter). Agent/AgentSwarm spawn children whose inheritance of these rules is not
    # guaranteed. Cron*/`*Goal*` create state that OUTLIVES the run. Skill can execute
    # packaged commands. mcp__* is a glob because kimi loads MCP servers declared by the
    # REPO UNDER REVIEW (project `.mcp.json` / `.kimi-code/mcp.json`) — their tools are named
    # mcp__<server>__<tool> and would otherwise be auto-approved in prompt mode.
    cat >> "$home/config.toml" <<'RULES' || { echo "kimi: could not inject the deny rules." >&2; exit 1; }

# --- injected by agent-companion: read-only verifier barrier ---
[[permission.rules]]
decision = "deny"
pattern = "Write"

[[permission.rules]]
decision = "deny"
pattern = "Edit"

[[permission.rules]]
decision = "deny"
pattern = "Bash"

[[permission.rules]]
decision = "deny"
pattern = "Agent"

[[permission.rules]]
decision = "deny"
pattern = "AgentSwarm"

[[permission.rules]]
decision = "deny"
pattern = "Skill"

[[permission.rules]]
decision = "deny"
pattern = "Cron*"

[[permission.rules]]
decision = "deny"
pattern = "*Goal*"

[[permission.rules]]
decision = "deny"
pattern = "TaskStop"

[[permission.rules]]
decision = "deny"
pattern = "mcp__*"

[[permission.rules]]
decision = "deny"
pattern = "mcp:*"
RULES

    # Fail closed: if the barrier is not actually present in the file, do not run at all.
    grep -q '^pattern = "Bash"' "$home/config.toml" || {
      echo "kimi: read-only barrier missing from the sandbox config — refusing to run." >&2
      exit 1
    }

    # THE RUN IS LAUNCHED FROM A NEUTRAL EMPTY CWD, NOT THE REPO. This is load-bearing, not
    # tidiness: kimi discovers project MCP servers (`.mcp.json`, `.kimi-code/mcp.json`) from
    # the current directory and SPAWNS their commands at startup — before any permission rule
    # is consulted. Verified: with cwd inside a repo carrying a hostile `.mcp.json`, its
    # command ran and wrote a file, while every tool call was still correctly denied. Since a
    # verifier reviews code it does not trust, that is arbitrary execution from the tree under
    # review. With cwd neutral the same `.mcp.json` did NOT fire, and the repo stayed fully
    # readable through --add-dir plus absolute paths (the dispatcher passes REPO_ROOT and
    # DIFF_PATCH as absolute paths, and Read reaches outside the workspace anyway).
    repo="$PWD"
    mkdir -p "$home/cwd" && cd "$home/cwd" || {
      echo "kimi: could not enter the neutral working directory." >&2; exit 1
    }
    #
    # --add-dir makes the repo under review an explicit workspace directory.
    #
    # No timeout flag is passed: kimi has no equivalent of agy's --print-timeout, and
    # verify.sh already wraps run in timeout/gtimeout (AGENT_COMPANION_TIMEOUT, 1800s).
    #
    # model is optional (4th arg): absent -> default_model from the copied config. When
    # present it was already resolved against `models` when the entry was added, so it goes
    # through as-is; an unknown alias makes kimi fail, which is the right failure.
    if [ -n "$model" ]; then
      KIMI_CODE_HOME="$home" kimi --add-dir "$repo" --model "$model" -p "$(cat "$prompt")" > "$out"
    else
      KIMI_CODE_HOME="$home" kimi --add-dir "$repo" -p "$(cat "$prompt")" > "$out"
    fi
    rc=$?

    # kimi decorates the first line of every answer block with a "• " bullet and indents the
    # continuation lines. The indent is harmless (classify_verdict trims leading whitespace),
    # but the bullet is NOT: the required verdict starts with STATUS, so the classifier sees
    # "• STATUS: PASS", fails to match, and fail-closes a genuine PASS into a FAIL. Verified.
    # Strip it ONLY off the two lines classification actually anchors on. A blanket strip of
    # every leading bullet would also rewrite legitimate "• "-marked list items in the verdict
    # body, i.e. silently edit the reviewer's own prose; these two lines are the entire fix.
    if [ -s "$out" ]; then
      sed -e 's/^•[[:space:]]*\(STATUS:\)/\1/' \
          -e 's/^•[[:space:]]*\(REQUEST_ID:\)/\1/' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
    fi

    # A denied or swallowed tool call can make kimi exit 0 having printed NOTHING. Left alone
    # that empty file would be classified as a verdict, so make the silence loud.
    if [ "$rc" -eq 0 ] && [ ! -s "$out" ]; then
      echo "kimi: exited 0 but produced no output — a tool call was likely denied." >&2
      exit 1
    fi
    exit "$rc";;
  *) echo "usage: kimi.sh probe|models|run" >&2; exit 64;;
esac
