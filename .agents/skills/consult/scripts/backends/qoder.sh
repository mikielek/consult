#!/usr/bin/env bash
set -euo pipefail
# consult-cli: qoder

# Backend adapter: Qoder CLI. Translates the normalized consult interface into
#   qoder -p --permission-mode plan [-o json] [--model M]
#         [-c | --resume ID] [--session-id ID] PROMPT
# Plan mode blocks edits (verified in-tree and out-of-tree); it is approval/policy-gated
# read-only, not an OS sandbox. Unlike `-p` on other backends, `-p` here is a boolean and
# the prompt is positional (last), so every flag precedes it (`query` is variadic).
# See ../../references/qoder-cli.md for observed CLI behavior.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

parse_common_args "$@"
require_prompt

# The CLI rejects this pair too, unless --fork-session (unreachable from consult) is added.
[[ -n "$RESUME" && -n "$SESSION_ID" ]] && die "use either --resume or --session-id, not both"
guard_positional_prompt "Qoder" "-"

prompt="$(compose_prompt "Qoder")"

cmd=(qoder -p --permission-mode plan)
[[ "$JSON" -eq 1 ]]    && cmd+=(-o json)
[[ -n "$MODEL" ]]      && cmd+=(--model "$MODEL")
if [[ -n "$RESUME" ]]; then
  if [[ "$RESUME" == "latest" ]]; then
    cmd+=(-c)
  else
    cmd+=(--resume "$RESUME")
  fi
fi
[[ -n "$SESSION_ID" ]] && cmd+=(--session-id "$SESSION_ID")
cmd+=("$prompt")

warn_resume_latest "Qoder"
report_known_session
run_or_print "${cmd[@]}"
