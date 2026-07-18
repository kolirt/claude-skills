#!/usr/bin/env bash
# agent-companion: durable manager-mode state.
#
# State lives under $DATA (NEVER under the plugin root — that is ephemeral and is wiped by
# `/plugin update`). One file per session: $DATA/sessions/<key>, where <key> is
# sha256(session_id) truncated to 16 hex. Hashing is both collision-resistant enough for this
# purpose and makes path traversal via a hostile session_id impossible.
#
# File format — plain `KEY=VALUE` lines, never sourced/eval'd:
#   active=1
#   prompt_count=<int>
#   last_inject_ts=<epoch>
#
# Activation markers: a SINGLE ordered file $DATA/want holding `on <epoch>` or `off <epoch>`
# (last-write-wins). The first hook invocation that sees it claims it ATOMICALLY by renaming it
# inside the same directory; a concurrent claimer simply finds no file and stays silent.
#
# Every command is fail-open: unwritable $DATA, a missing session_id, or a corrupt state file
# result in a silent `exit 0` with no output. Callers (hooks) treat "no output" as "inactive".

set +e
set -u
set -o pipefail 2>/dev/null || true

# Same DATA resolution expression as verify.sh / verifiers.sh / synthesizer.sh.
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/agent-companion}"

THROTTLE_PROMPTS=8        # inject after this many prompts...
THROTTLE_SECONDS=1200     # ...or this many seconds since the last injection
WANT_MAX_AGE=120          # a `want` marker older than this is stale and is not claimed
SESSION_MAX_DAYS=30       # GC: session files older than this
CLAIMED_MAX_MINUTES=10    # GC: orphaned want.claimed.* files older than this

now_ts() { date +%s 2>/dev/null || printf '0'; }

# Same hashing ladder as verify.sh's repo_key(): sha256 where available, cksum as a last resort.
# Any of the three yields a fixed-length hex/decimal token, so the resulting path is always
# confined to $DATA/sessions regardless of what the session_id contained.
session_key() {
  if   command -v shasum    >/dev/null 2>&1; then printf '%s' "$1" | shasum -a 256 | cut -c1-16
  elif command -v sha256sum >/dev/null 2>&1; then printf '%s' "$1" | sha256sum    | cut -c1-16
  else printf '%s' "$1" | cksum | tr -d ' ' | cut -c1-16; fi
}

state_path() { # <session_id> -> path, or nothing for an empty id
  local sid="${1:-}" key
  [ -n "$sid" ] || return 1
  key="$(session_key "$sid")" || return 1
  [ -n "$key" ] || return 1
  printf '%s/sessions/%s' "$DATA" "$key"
}

# Write stdin to <dest> atomically: mktemp in the SAME directory (so `mv` is a rename, not a
# cross-device copy) then mv. Returns non-zero without side effects if anything fails.
atomic_write() { # <dest>
  local dest="$1" dir tmp
  dir="$(dirname "$dest")"
  mkdir -p "$dir" 2>/dev/null || return 1
  tmp="$(mktemp "$dir/.tmp.XXXXXX" 2>/dev/null)" || return 1
  if ! cat > "$tmp" 2>/dev/null; then rm -f "$tmp" 2>/dev/null; return 1; fi
  if ! mv -f "$tmp" "$dest" 2>/dev/null; then rm -f "$tmp" 2>/dev/null; return 1; fi
  return 0
}

# Populate ST_ACTIVE / ST_COUNT / ST_TS from a state file. Returns 1 when the session is not
# active OR the file is absent/corrupt — the caller cannot tell the difference, and must not:
# both mean "stay silent".
ST_ACTIVE=0; ST_COUNT=0; ST_TS=0
read_state() { # <file>
  ST_ACTIVE=0; ST_COUNT=0; ST_TS=0
  local f="$1" line k v
  [ -f "$f" ] || return 1
  # head caps the work a corrupt/huge file can cause; a well-formed file has 3 lines.
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *=*) ;; *) continue;; esac
    k="${line%%=*}"; v="${line#*=}"
    case "$k" in
      active)         [ "$v" = 1 ] && ST_ACTIVE=1 ;;
      prompt_count)   case "$v" in ''|*[!0-9]*) return 1;; *) ST_COUNT="$v";; esac ;;
      last_inject_ts) case "$v" in ''|*[!0-9]*) return 1;; *) ST_TS="$v";; esac ;;
    esac
  done < <(head -n 10 "$f" 2>/dev/null)
  [ "$ST_ACTIVE" = 1 ] || return 1
  return 0
}

write_state() { # <file> <prompt_count> <last_inject_ts>
  printf 'active=1\nprompt_count=%s\nlast_inject_ts=%s\n' "$2" "$3" | atomic_write "$1"
}

# ---------- commands ----------

# want-on / want-off: best-effort activation marker written by the slash commands, for CLI
# builds where UserPromptSubmit never sees the slash-command text. Global (the command has no
# session_id at hand) — first claimer wins; see commands/on.md for the accepted limitation.
cmd_want() { # <on|off>
  mkdir -p "$DATA" 2>/dev/null || exit 0
  printf '%s %s\n' "$1" "$(now_ts)" | atomic_write "$DATA/want" || exit 0
  exit 0
}

# Take exclusive ownership of $DATA/want via a single rename inside the same directory. Exactly
# one concurrent caller can succeed; every other caller sees a missing file and returns 1.
# Echoes the claimed content on success.
take_want() {
  local claimed="$DATA/want.claimed.$$" content
  [ -f "$DATA/want" ] || return 1
  mv "$DATA/want" "$claimed" 2>/dev/null || return 1
  content="$(head -n1 "$claimed" 2>/dev/null)"
  rm -f "$claimed" 2>/dev/null
  printf '%s' "$content"
  return 0
}

# drop-want: branch (a) of the prompt hook — the prompt itself carried the command, so any
# pending marker is obsolete. Removed through the SAME atomic rename (not `rm`), so it cannot
# race with a concurrent claimer into a double-apply.
cmd_drop_want() { take_want >/dev/null 2>&1; exit 0; }

# claim <session_id>: apply a fresh marker to THIS session. Silent on a stale/absent marker.
cmd_claim() {
  local sid="${1:-}" sp content verb ts age
  sp="$(state_path "$sid")" || exit 0
  content="$(take_want)" || exit 0
  verb="${content%% *}"; ts="${content##* }"
  case "$ts" in ''|*[!0-9]*) exit 0;; esac
  age=$(( $(now_ts) - ts ))
  [ "$age" -ge 0 ] && [ "$age" -le "$WANT_MAX_AGE" ] || exit 0
  case "$verb" in
    on)  write_state "$sp" 0 "$(now_ts)" >/dev/null 2>&1 ;;
    off) rm -f "$sp" 2>/dev/null ;;
  esac
  exit 0
}

# on <session_id>: activate AND reset the throttle, so the very invocation that enabled the mode
# cannot also fire a reminder.
cmd_on() {
  local sp; sp="$(state_path "${1:-}")" || exit 0
  write_state "$sp" 0 "$(now_ts)" >/dev/null 2>&1
  exit 0
}

cmd_off() {
  local sp; sp="$(state_path "${1:-}")" || exit 0
  rm -f "$sp" 2>/dev/null
  exit 0
}

# status <session_id>: prints `active <prompt_count> <last_inject_ts>` when active, else nothing.
cmd_status() {
  local sp; sp="$(state_path "${1:-}")" || exit 0
  read_state "$sp" || exit 0
  printf 'active %s %s\n' "$ST_COUNT" "$ST_TS"
  exit 0
}

# bump <session_id>: increment and PERSIST prompt_count on every active prompt (whether or not a
# reminder fires), then print `<prompt_count> <last_inject_ts>` for the caller's throttle check.
# Prints nothing when the session is not active.
cmd_bump() {
  local sp c; sp="$(state_path "${1:-}")" || exit 0
  read_state "$sp" || exit 0
  c=$((ST_COUNT + 1))
  write_state "$sp" "$c" "$ST_TS" >/dev/null 2>&1 || exit 0
  printf '%s %s\n' "$c" "$ST_TS"
  exit 0
}

# mark-inject <session_id>: reset both throttle fields after an injection (prompt hook or
# SessionStart alike).
cmd_mark_inject() {
  local sp; sp="$(state_path "${1:-}")" || exit 0
  read_state "$sp" || exit 0
  write_state "$sp" 0 "$(now_ts)" >/dev/null 2>&1
  exit 0
}

# should-inject <prompt_count> <last_inject_ts>: exit 0 when the throttle has matured.
cmd_should_inject() {
  local c="${1:-0}" ts="${2:-0}" now
  case "$c$ts" in *[!0-9]*) exit 1;; esac
  [ "$c" -ge "$THROTTLE_PROMPTS" ] && exit 0
  now="$(now_ts)"
  [ $((now - ts)) -ge "$THROTTLE_SECONDS" ] && exit 0
  exit 1
}

# gc: session files older than 30 days (this also sweeps sessions orphaned by a `/clear` that
# changed the session_id), a stale `want`, and orphaned `want.claimed.*` files.
cmd_gc() {
  [ -d "$DATA" ] || exit 0
  find "$DATA/sessions" -maxdepth 1 -type f -mtime "+$SESSION_MAX_DAYS" -delete 2>/dev/null
  find "$DATA" -maxdepth 1 -type f -name 'want' -mmin "+$CLAIMED_MAX_MINUTES" -delete 2>/dev/null
  find "$DATA" -maxdepth 1 -type f -name 'want.claimed.*' -mmin "+$CLAIMED_MAX_MINUTES" -delete 2>/dev/null
  exit 0
}

CMD="${1:-}"; shift 2>/dev/null
case "$CMD" in
  want-on)       cmd_want on ;;
  want-off)      cmd_want off ;;
  drop-want)     cmd_drop_want ;;
  claim)         cmd_claim "${1:-}" ;;
  on)            cmd_on "${1:-}" ;;
  off)           cmd_off "${1:-}" ;;
  status)        cmd_status "${1:-}" ;;
  bump)          cmd_bump "${1:-}" ;;
  mark-inject)   cmd_mark_inject "${1:-}" ;;
  should-inject) cmd_should_inject "${1:-}" "${2:-}" ;;
  gc)            cmd_gc ;;
  key)           [ -n "${1:-}" ] && session_key "$1"; exit 0 ;;
  *) echo "usage: state.sh <want-on|want-off|drop-want|claim|on|off|status|bump|mark-inject|should-inject|gc> [args]" >&2
     exit 64 ;;
esac
