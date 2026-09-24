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

# guard_positional_prompt CALLEE PREFIX... -> reject a --raw prompt that a backend would
# not read as prompt text.
#
# Most backends take the prompt as a positional argument, and their option parsers scan
# every argv position: a leading '-' is read as a backend flag, so `--raw --prompt
# "--some-backend-option"` would reintroduce exactly the flag injection that the absent
# '--' passthrough exists to prevent. Pi additionally treats a leading '@' as a file
# include. Composed prompts always start with the reviewer framing, so --raw is the only
# route to such a value; backends that pass the prompt as an option value (gemini -p) do
# not need this. Deliberately a rejection rather than a '--' delimiter: --help and the
# parsers disagree across these CLIs, and opencode was observed re-quoting '--' into the
# Bun argv rather than honouring it.
guard_positional_prompt() {
  local callee="$1"
  shift
  [[ "$RAW" -eq 1 ]] || return 0
  local lead
  for lead in "$@"; do
    case "$PROMPT" in
      "$lead"*)
        die "a --raw prompt cannot begin with '$lead' for $callee; the CLI would parse it as a flag or include rather than prompt text - drop --raw or reword the prompt"
        ;;
    esac
  done
}

# compose_prompt CALLEE -> echoes the prompt to send.
# Prepends a neutral advisory reviewer framing unless --raw was given. The framing
# includes a hedged read-reachability note: SKILL.md tells callers to name only
# in-tree paths, and this makes a missed case fail loudly instead of guessing.
# CALLEE (e.g. "Gemini") is injected by the adapter; FROM comes from --from.
compose_prompt() {
  local callee="$1"
  if [[ "$RAW" -eq 1 ]]; then
    printf '%s' "$PROMPT"
    return
  fi
  printf 'You are %s, consulting with %s as an independent advisory reviewer.\n' "$callee" "$FROM"
  printf 'Do not edit files or run destructive commands; treat this as advice to verify locally.\n'
  printf 'Files outside the current working directory may be unreadable; if a path in this prompt is unreachable, say so rather than guessing its contents.\n\n'
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

# Session-concurrency contract, shared by every adapter (see references/backend-adapters.md):
# call both right before run_or_print / run_capture_status.
#
# warn_resume_latest CALLEE -> `--resume latest` continues the newest session of the project,
# which silently crosses concurrent callers, so warn (also under --dry-run); never refuse.
warn_resume_latest() {
  if [[ "$RESUME" == "latest" ]]; then
    echo "consult: warning: --resume latest continues $1's newest session of this project; it breaks silently when other agents use $1 here. Resume by id instead (see the consult-session: line, or pass --session-id where supported)." >&2
  fi
  return 0
}

# report_known_session -> on a live run, print `consult-session: <id>` on stderr when the caller
# already chose the id (--session-id) or names it (--resume <id>). stdout is never touched.
report_known_session() {
  local id=""
  if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ -n "$SESSION_ID" ]]; then
      id="$SESSION_ID"
    elif [[ -n "$RESUME" && "$RESUME" != "latest" ]]; then
      id="$RESUME"
    fi
    if [[ -n "$id" ]]; then echo "consult-session: $id" >&2; fi
  fi
  return 0
}

# run_capture_status CMD... -> run CMD live without exec so the adapter can act afterwards.
# Opt-in for backends that cannot report their own session id; call as
# `run_capture_status ... || rc=$?` (errexit-safe). The first INT/TERM/HUP forwards TERM and sets
# CAPTURE_INTERRUPTED=1; a repeated signal escalates to KILL, so the reaped child status is usually
# 143 (128+TERM) after one signal or 137 (128+KILL) after escalation. The child runs in the
# background because bash defers a trapped signal until a foreground child exits, which would keep
# the trap from forwarding anything. KILL reaches only the direct child, not any grandchild it
# spawned; a process-group kill was rejected as scope creep (see references/backend-adapters.md).
run_capture_status() {
  [[ $# -gt 0 ]] || die "internal error: empty command"
  command -v "$1" >/dev/null 2>&1 || die "'$1' is not on PATH; install the $1 CLI (and authenticate it) to use this backend"
  CAPTURE_INTERRUPTED=0
  local child rc=0
  "$@" </dev/null &
  child=$!
  # || true: the child may already be gone, and a failed kill would trip the callers' errexit.
  trap 'if [[ "$CAPTURE_INTERRUPTED" -eq 0 ]]; then CAPTURE_INTERRUPTED=1; kill -TERM "$child" 2>/dev/null || true; else kill -KILL "$child" 2>/dev/null || true; fi' INT TERM HUP
  while :; do
    wait "$child" && rc=0 || rc=$?
    kill -0 "$child" 2>/dev/null || break
  done
  trap - INT TERM HUP
  return "$rc"
}
