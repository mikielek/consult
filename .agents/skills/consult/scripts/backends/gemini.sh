#!/usr/bin/env bash
set -euo pipefail
# consult-cli: gemini

# Backend adapter: Gemini CLI. Translates the normalized consult interface into
#   gemini -p PROMPT --approval-mode plan [--output-format json] [--resume V]
#          [--session-id ID] [--model M]
# See ../../references/gemini-cli.md for observed CLI behavior.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

parse_common_args "$@"
require_prompt

[[ -n "$RESUME" && -n "$SESSION_ID" ]] && die "use either --resume or --session-id, not both"
[[ ${#FILES[@]} -eq 0 ]] || die "gemini backend does not support --file"

prompt="$(compose_prompt "Gemini")"

cmd=(gemini -p "$prompt" --approval-mode plan)
[[ "$JSON" -eq 1 ]]      && cmd+=(--output-format json)
[[ -n "$RESUME" ]]       && cmd+=(--resume "$RESUME")
[[ -n "$SESSION_ID" ]]   && cmd+=(--session-id "$SESSION_ID")
[[ -n "$MODEL" ]]        && cmd+=(--model "$MODEL")

run_or_print "${cmd[@]}"
