#!/usr/bin/env bash
set -euo pipefail
# consult-cli: codex

# Backend adapter: Codex CLI. Translates the normalized consult interface into
#   codex -s read-only -a never exec [resume --last|ID] [--skip-git-repo-check]
#         [--color never] [--json] [-m M] PROMPT
# -s/-a are TOP-LEVEL flags and MUST precede `exec` (codex 0.140: `codex exec -a` errors).
# -s read-only is OS-sandbox-enforced read-only; -a never keeps it non-interactive.
# See ../../references/codex-cli.md for observed CLI behavior.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

parse_common_args "$@"
require_prompt

[[ -z "$SESSION_ID" ]] || die "codex assigns its own session id; use --resume latest or --resume <id>"
[[ ${#FILES[@]} -eq 0 ]] || die "codex backend does not support --file; reference the path in --prompt and Codex will read it in its read-only sandbox"

prompt="$(compose_prompt "Codex")"

cmd=(codex -s read-only -a never exec)
resume_mode=0
if [[ -n "$RESUME" ]]; then
  resume_mode=1
  cmd+=(resume)
  if [[ "$RESUME" == "latest" ]]; then
    cmd+=(--last)
  else
    cmd+=("$RESUME")
  fi
fi
cmd+=(--skip-git-repo-check)
[[ "$resume_mode" -eq 0 ]] && cmd+=(--color never)   # --color not accepted on `exec resume`
[[ "$JSON" -eq 1 ]]       && cmd+=(--json)            # NOTE: codex --json is JSONL, not one object
[[ -n "$MODEL" ]]         && cmd+=(-m "$MODEL")
cmd+=("$prompt")

run_or_print "${cmd[@]}"
