#!/usr/bin/env bash
# Shared helpers for consult backend adapters.
# Source this from a backend:
# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
#
# parse_common_args "$@" populates these globals:
#   PROMPT JSON RESUME SESSION_ID MODEL FROM DRY_RUN RAW ALLOW_SECRETS
# One non-flag positional argument may be used as PROMPT; use --prompt when
# the prompt begins with '-'.
#
# There is deliberately no raw passthrough: only validated normalized flags reach
# the backend CLIs, so callers cannot inject capability-/permission-shaping flags.

die() { echo "consult: $*" >&2; exit 2; }

# need_value FLAG REMAINING_ARGC  -> fail if a flag is missing its value
need_value() { [[ "$2" -ge 2 ]] || die "missing value for $1"; }

parse_common_args() {
  PROMPT=""
  JSON=0
  RESUME=""
  SESSION_ID=""
  MODEL=""
  FROM="a coding agent"
  DRY_RUN=0
  RAW=0
  ALLOW_SECRETS=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--prompt)     need_value "$1" $#; PROMPT="$2"; shift 2 ;;
      --json)          JSON=1; shift ;;
      -r|--resume)     need_value "$1" $#; RESUME="$2"; shift 2 ;;
      --session-id)    need_value "$1" $#; SESSION_ID="$2"; shift 2 ;;
      -m|--model)      need_value "$1" $#; MODEL="$2"; shift 2 ;;
      --from)          need_value "$1" $#; FROM="$2"; shift 2 ;;
      --dry-run)       DRY_RUN=1; shift ;;
      --raw)           RAW=1; shift ;;
      --allow-secrets) ALLOW_SECRETS=1; shift ;;
      --) die "passthrough is not supported; only the documented consult flags are allowed" ;;
      -*) die "unknown flag '$1'" ;;
      *)  if [[ -z "$PROMPT" ]]; then PROMPT="$1"; shift; else die "unexpected argument '$1'"; fi ;;
    esac
  done
}

scan_for_secrets() {
  local payload="$1"
  local pattern='(sk-[A-Za-z0-9_-]{32,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{36,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----)'

  [[ -n "$payload" ]] || return 0
  if LC_ALL=C grep -Eq "$pattern" <<<"$payload"; then
    die "ABORTED. Potential secret detected in prompt. Re-run with --allow-secrets only if you intentionally want to send this prompt."
  fi
}

require_prompt() {
  [[ -n "$PROMPT" ]] || die "a prompt is required (use --prompt TEXT or one positional prompt)"
  [[ "$ALLOW_SECRETS" -eq 1 ]] || scan_for_secrets "$PROMPT"
}

# compose_prompt CALLEE -> echoes the prompt to send.
# Prepends a neutral advisory reviewer framing unless --raw was given.
# CALLEE (e.g. "Gemini") is injected by the adapter; FROM comes from --from.
compose_prompt() {
  local callee="$1"
  if [[ "$RAW" -eq 1 ]]; then
    printf '%s' "$PROMPT"
    return
  fi
  printf 'You are %s, consulting with %s as an independent advisory reviewer.\n' "$callee" "$FROM"
  printf 'Do not edit files or run destructive commands; treat this as advice to verify locally.\n\n'
  printf '%s' "$PROMPT"
}

# run_or_print CMD... -> print the resolved command (--dry-run) or exec it.
# The prompt is always passed as an argument, so stdin is redirected from
# /dev/null to keep the consult non-interactive (e.g. codex exec otherwise
# blocks "Reading additional input from stdin...").
# CMD[0] must be the backend's base binary (no wrapper like `npx`), so the
# command -v preflight below accurately reports whether the CLI is installed.
run_or_print() {
  [[ $# -gt 0 ]] || die "internal error: empty command"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    command -v "$1" >/dev/null 2>&1 || echo "consult: note: '$1' not on PATH — a real (non --dry-run) run will fail" >&2
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  command -v "$1" >/dev/null 2>&1 || die "'$1' is not on PATH; install the $1 CLI (and authenticate it) to use this backend"
  exec "$@" </dev/null
}
