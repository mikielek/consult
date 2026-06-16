#!/usr/bin/env bash
set -euo pipefail
# consult-cli: claude

# Backend adapter: Claude Code CLI. Translates the normalized consult interface into
#   claude -p --permission-mode plan [--output-format json] [--model M]
#          [--continue | --resume ID] [--session-id UUID] PROMPT
# Plan mode is read-only (no edits without approval, unavailable headless).
# See ../../references/claude-cli.md for observed CLI behavior.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

parse_common_args "$@"
require_prompt

[[ -n "$RESUME" && -n "$SESSION_ID" ]] && die "use either --resume or --session-id, not both"

prompt="$(compose_prompt "Claude")"

cmd=(claude -p --permission-mode plan)
[[ "$JSON" -eq 1 ]]    && cmd+=(--output-format json)
[[ -n "$MODEL" ]]      && cmd+=(--model "$MODEL")
if [[ -n "$RESUME" ]]; then
  if [[ "$RESUME" == "latest" ]]; then
    cmd+=(--continue)
  else
    cmd+=(--resume "$RESUME")
  fi
fi
[[ -n "$SESSION_ID" ]] && cmd+=(--session-id "$SESSION_ID")
cmd+=("$prompt")

run_or_print "${cmd[@]}"
