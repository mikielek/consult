#!/usr/bin/env bash
set -euo pipefail
# consult-cli: pi

# Backend adapter: Pi CLI. Translates the normalized consult interface into
#   pi -p --tools read,grep,ls --no-extensions --no-skills
#      --no-prompt-templates --no-themes --no-context-files --no-approve
#      [--no-session] [--model M]
#      [--continue | --session ID] [--session-id ID] [@file...] PROMPT
# Mutation is restricted by a Pi tool allowlist: no edit/write/bash tools and no
# discovered extension/custom tools. See ../../references/pi-cli.md for observed behavior.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

parse_common_args "$@"
require_prompt

[[ -n "$RESUME" && -n "$SESSION_ID" ]] && die "use either --resume or --session-id, not both"
[[ "$JSON" -eq 0 ]] || die "pi backend does not support --json: Pi JSON mode emits verbose JSONL tool/thinking events; omit --json for clean final-response output"

prompt="$(compose_prompt "Pi")"

if [[ "$RAW" -eq 1 ]]; then
  if [[ "$prompt" == -* || "$prompt" == @* ]]; then
    die "pi has no end-of-options delimiter; a --raw prompt cannot begin with '-' or '@' (it would be parsed as a pi flag or file include) - reword it"
  fi
fi

cmd=(
  pi -p
  --tools read,grep,ls
  --no-extensions
  --no-skills
  --no-prompt-templates
  --no-themes
  --no-context-files
  --no-approve
)
[[ -n "$MODEL" ]] && cmd+=(--model "$MODEL")
if [[ -n "$RESUME" ]]; then
  if [[ "$RESUME" == "latest" ]]; then
    cmd+=(--continue)
  else
    cmd+=(--session "$RESUME")
  fi
fi
[[ -n "$SESSION_ID" ]] && cmd+=(--session-id "$SESSION_ID")
[[ -z "$RESUME" && -z "$SESSION_ID" ]] && cmd+=(--no-session)

file=""
for file in "${FILES[@]+"${FILES[@]}"}"; do
  cmd+=("@$file")
done

cmd+=("$prompt")

run_or_print "${cmd[@]}"
