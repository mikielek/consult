#!/usr/bin/env bash
set -euo pipefail
# consult-cli: opencode

# Backend adapter: OpenCode CLI. Translates the normalized consult interface into
#   opencode run --agent plan [--format json] [--continue|--session ID]
#                [--title T] [--model M] PROMPT
# Defaults to the approval-gated `plan` agent (no edits without approval, which is
# unavailable headless). See ../../references/opencode-cli.md for observed behavior.
#
# opencode assigns its own session ids and `--resume latest` continues the newest session of
# the project, which silently crosses concurrent callers. So a fresh run carries a unique
# --title and, after the run, the id is resolved from `session list` by that title and
# reported as `consult-session: <id>` on stderr (stdout stays the backend's output).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

parse_common_args "$@"
require_prompt

[[ -z "$SESSION_ID" ]] || die "opencode does not support --session-id; use --resume <session-id>"
guard_positional_prompt "OpenCode" "-"

prompt="$(compose_prompt "OpenCode")"

cmd=(opencode run --agent plan)
[[ "$JSON" -eq 1 ]] && cmd+=(--format json)
title=""
if [[ -n "$RESUME" ]]; then
  if [[ "$RESUME" == "latest" ]]; then
    cmd+=(--continue)
  else
    cmd+=(--session "$RESUME")
  fi
else
  if [[ "$DRY_RUN" -eq 1 ]]; then
    title="consult-<epoch>-<pid>-<random>"
  else
    title="consult-$(date +%s)-$$-$RANDOM"
  fi
  cmd+=(--title "$title")
fi
[[ -n "$MODEL" ]] && cmd+=(--model "$MODEL")

cmd+=("$prompt")

# Resumed runs keep exec: the id is already known or unresolvable. Only fresh runs need the
# post-run lookup.
warn_resume_latest "OpenCode"
report_known_session
if [[ -n "$RESUME" || "$DRY_RUN" -eq 1 ]]; then
  run_or_print "${cmd[@]}"
  exit 0
fi

rc=0
run_capture_status "${cmd[@]}" || rc=$?

if [[ "${CAPTURE_INTERRUPTED:-0}" -eq 0 ]]; then
  id="unknown"
  if command -v jq >/dev/null 2>&1; then
    found="$(opencode session list --pure --format json 2>/dev/null </dev/null \
      | jq -r --arg t "$title" 'first(.[] | select(.title == $t) | .id) // empty' 2>/dev/null)" || found=""
    [[ -z "$found" ]] || id="$found"
  fi
  echo "consult-session: $id" >&2
fi
exit "$rc"
