#!/usr/bin/env bash
set -euo pipefail
# consult-cli: opencode

# Backend adapter: OpenCode CLI. Translates the normalized consult interface into
#   opencode run --agent plan [--format json] [--continue|--session ID]
#                [--model M] PROMPT
# Defaults to the approval-gated `plan` agent (no edits without approval, which is
# unavailable headless). See ../../references/opencode-cli.md for observed behavior.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

parse_common_args "$@"
require_prompt

[[ -z "$SESSION_ID" ]] || die "opencode does not support --session-id; use --resume <session-id>"

prompt="$(compose_prompt "OpenCode")"

cmd=(opencode run --agent plan)
[[ "$JSON" -eq 1 ]] && cmd+=(--format json)
if [[ -n "$RESUME" ]]; then
  if [[ "$RESUME" == "latest" ]]; then
    cmd+=(--continue)
  else
    cmd+=(--session "$RESUME")
  fi
fi
[[ -n "$MODEL" ]] && cmd+=(--model "$MODEL")

cmd+=("$prompt")

run_or_print "${cmd[@]}"
