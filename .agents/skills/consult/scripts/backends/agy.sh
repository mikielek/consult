#!/usr/bin/env bash
set -euo pipefail
# consult-cli: agy

# Backend adapter: Antigravity CLI (agy). Translates the normalized consult interface into
#   agy --mode plan [--output-format json] [--model M]
#       [-c | --conversation ID | --log-file TMP] -p PROMPT
# Plan mode plus headless auto-denial of writes and shell commands; approval-gated, not an OS
# sandbox. Do not add --disable-slash-commands: agy then silently drops --mode plan.
# See ../../references/agy-cli.md for observed CLI behavior.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

parse_common_args "$@"
require_prompt

[[ -n "$SESSION_ID" ]] && die "agy backend does not support --session-id; agy assigns its own conversation ids (see the consult-session: line)"
# -p binds the prompt as an option value, so a leading '-' is safe; a leading '/' still runs
# a slash command in print mode.
guard_positional_prompt "Antigravity" "/"

prompt="$(compose_prompt "Antigravity")"
# Headless agy auto-denies shell commands and writes, and a denial ends the turn with no answer
# and exit 0. Unsteered reviews reached for grep/head first and came back empty 0/9; with this
# note they succeeded 6/6 (agy 1.2.17). It lives here, not in compose_prompt, because the other
# backends run read-only shell commands fine.
if [[ "$RAW" -eq 0 ]]; then
  prompt+=$'\n\nHeadless note: shell commands and file writes are unavailable in this session'
  prompt+=' and any attempt ends the session with no answer.'
  prompt+=' Use only your built-in file viewing, listing and search tools.'
fi

cmd=(agy --mode plan)
[[ "$JSON" -eq 1 ]] && cmd+=(--output-format json)
[[ -n "$MODEL" ]]   && cmd+=(--model "$MODEL")
# agy only warns on an unknown --mode value and then runs in its default mode, so a renamed
# plan mode would silently drop the read-only gating. `agy --help` is local and fast; refuse
# a live run unless it still lists plan. (A missing binary falls through to run_or_print's
# own error.)
if [[ "$DRY_RUN" -eq 0 ]] && command -v agy >/dev/null 2>&1; then
  # Captured first: under pipefail, `grep -q` closing the pipe early could SIGPIPE agy.
  agy_help="$(agy --help 2>&1 </dev/null)" || true
  grep -Eq -- '--mode[[:space:]].*[(, ]plan[,)]' <<<"$agy_help" \
    || die "this agy no longer lists 'plan' under --mode; refusing to run without plan mode (see references/agy-cli.md)"
fi

log=""
if [[ -n "$RESUME" ]]; then
  if [[ "$RESUME" == "latest" ]]; then
    cmd+=(-c)
  else
    cmd+=(--conversation "$RESUME")
  fi
elif [[ "$DRY_RUN" -eq 1 ]]; then
  cmd+=(--log-file "<per-run-temp-log>")
else
  # agy cannot take a caller-chosen id and prints none in text mode, but its log records
  # `Print mode: conversation=<uuid>` (metadata only, no prompt or response text). A per-run
  # log file makes that lookup safe under concurrent callers.
  log="$(mktemp "${TMPDIR:-/tmp}/consult-agy.XXXXXX")" || die "cannot create a temporary log file"
  trap 'rm -f "$log"' EXIT
  cmd+=(--log-file "$log")
fi
cmd+=(-p "$prompt")

# Resumed runs keep exec: the id is already known or unresolvable. Only fresh runs need the
# post-run lookup.
warn_resume_latest "Antigravity"
report_known_session
if [[ -z "$log" ]]; then
  run_or_print "${cmd[@]}"
  exit 0
fi

rc=0
run_capture_status "${cmd[@]}" || rc=$?

# The log line is agy's internal format, not an interface: if a release rewords it, this
# degrades to `unknown` (the wrapper tests pin the 1.2.17 line).
if [[ "${CAPTURE_INTERRUPTED:-0}" -eq 0 ]]; then
  id="$(sed -n 's/.*Print mode: conversation=\([0-9A-Za-z-]\{1,\}\).*/\1/p' "$log" 2>/dev/null | head -n1)" || id=""
  echo "consult-session: ${id:-unknown}" >&2
fi
exit "$rc"
