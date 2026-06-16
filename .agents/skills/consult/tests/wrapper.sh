#!/usr/bin/env bash
set -euo pipefail

# Deterministic wrapper checks for consult.sh. These tests never call a model:
# fake backend binaries are placed first on PATH and every case uses --dry-run
# or a parser path that exits before backend execution.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$TEST_DIR/.." && pwd)"
CONSULT="$SKILL_DIR/scripts/consult.sh"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/consult-wrapper-test.XXXXXX")"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

FAKE_BIN="$TMP_DIR/bin"
mkdir -p "$FAKE_BIN"
for bin in codex gemini claude opencode pi; do
  cat >"$FAKE_BIN/$bin" <<'STUB'
#!/usr/bin/env bash
printf 'unexpected live backend invocation: %s\n' "$0" >&2
exit 99
STUB
  chmod +x "$FAKE_BIN/$bin"
done

PATH_WITH_STUBS="$FAKE_BIN:$PATH"
LAST_STATUS=0
LAST_STDOUT=""
LAST_STDERR=""
CURRENT_TEST=""
PASS_COUNT=0

run_case() {
  local stdout="$TMP_DIR/stdout"
  local stderr="$TMP_DIR/stderr"

  set +e
  PATH="$PATH_WITH_STUBS" "$CONSULT" "$@" >"$stdout" 2>"$stderr"
  LAST_STATUS=$?
  set -e

  LAST_STDOUT="$(<"$stdout")"
  LAST_STDERR="$(<"$stderr")"
}

fail() {
  printf 'not ok - %s\n' "$CURRENT_TEST" >&2
  printf '  %s\n' "$1" >&2
  if [[ -n "$LAST_STDOUT" ]]; then
    printf '  stdout: %s\n' "$LAST_STDOUT" >&2
  fi
  if [[ -n "$LAST_STDERR" ]]; then
    printf '  stderr: %s\n' "$LAST_STDERR" >&2
  fi
  exit 1
}

assert_status() {
  local expected="$1"
  [[ "$LAST_STATUS" -eq "$expected" ]] || fail "expected status $expected, got $LAST_STATUS"
}

assert_stdout_contains() {
  local expected="$1"
  [[ "$LAST_STDOUT" == *"$expected"* ]] || fail "stdout did not contain: $expected"
}

assert_stderr_contains() {
  local expected="$1"
  [[ "$LAST_STDERR" == *"$expected"* ]] || fail "stderr did not contain: $expected"
}

assert_stdout_not_contains() {
  local unexpected="$1"
  [[ "$LAST_STDOUT" != *"$unexpected"* ]] || fail "stdout contained unexpected text: $unexpected"
}

assert_stderr_not_contains() {
  local unexpected="$1"
  [[ "$LAST_STDERR" != *"$unexpected"* ]] || fail "stderr contained unexpected text: $unexpected"
}

run_test() {
  CURRENT_TEST="$1"
  shift
  "$@"
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok - %s\n' "$CURRENT_TEST"
}

test_codex_defaults() {
  run_case --to codex --dry-run "Review API"
  assert_status 0
  assert_stdout_contains "codex -s read-only -a never exec"
  assert_stdout_contains "--skip-git-repo-check"
  assert_stdout_contains "--color never"
  assert_stdout_contains "Do not edit files"
}

test_gemini_defaults() {
  run_case --to gemini --dry-run "Review API"
  assert_status 0
  assert_stdout_contains "gemini -p"
  assert_stdout_contains "--approval-mode plan"
  assert_stdout_contains "Do not edit files"
}

test_claude_defaults() {
  run_case --to claude --dry-run "Review API"
  assert_status 0
  assert_stdout_contains "claude -p --permission-mode plan"
  assert_stdout_contains "Do not edit files"
}

test_opencode_defaults() {
  run_case --to opencode --dry-run "Review API"
  assert_status 0
  assert_stdout_contains "opencode run --agent plan"
  assert_stdout_contains "Do not edit files"
}

test_pi_defaults() {
  run_case --to pi --dry-run "Review API"
  assert_status 0
  assert_stdout_contains "pi -p"
  assert_stdout_contains "--tools read\\,grep\\,ls"
  assert_stdout_contains "--no-extensions --no-skills --no-prompt-templates --no-themes --no-context-files --no-approve"
  assert_stdout_contains "--no-session"
  assert_stdout_contains "Do not edit files"
}

test_passthrough_rejected() {
  run_case --to gemini --dry-run -- "Review API"
  assert_status 2
  assert_stderr_contains "passthrough is not supported"
}

test_prompt_secret_preflight() {
  local fake_secret="sk-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  run_case --to gemini --dry-run --prompt "Review token $fake_secret"
  assert_status 2
  assert_stderr_contains "ABORTED. Potential secret detected in prompt."
  assert_stdout_not_contains "$fake_secret"
  assert_stderr_not_contains "$fake_secret"

  run_case --to gemini --dry-run --allow-secrets --prompt "Review token $fake_secret"
  assert_status 0
  assert_stdout_contains "$fake_secret"
}

test_unknown_flag_rejected() {
  run_case --to gemini --dry-run --bogus "Review API"
  assert_status 2
  assert_stderr_contains "unknown flag '--bogus'"

  run_case --to gemini --dry-run --bogus --help
  assert_status 2
  assert_stderr_contains "unknown flag '--bogus'"
}

test_invalid_backend_rejected() {
  run_case --to ../gemini --dry-run "Review API"
  assert_status 2
  assert_stderr_contains "invalid backend name"
}

test_unknown_backend_rejected() {
  run_case --to nope --dry-run "Review API"
  assert_status 2
  assert_stderr_contains "unknown backend 'nope'"
}

test_resume_session_conflicts() {
  local backend
  for backend in gemini claude pi; do
    run_case --to "$backend" --dry-run --resume abc --session-id def "Review API"
    assert_status 2
    assert_stderr_contains "use either --resume or --session-id"
  done
}

test_file_support_boundaries() {
  local backend
  for backend in gemini codex claude; do
    run_case --to "$backend" --dry-run --file README.md "Review API"
    assert_status 2
    assert_stderr_contains "does not support --file"
  done

  run_case --to opencode --dry-run --file README.md "Review API"
  assert_status 0
  assert_stdout_contains "--file README.md"

  run_case --to pi --dry-run --file README.md "Review API"
  assert_status 0
  assert_stdout_contains "@README.md"
}

test_pi_raw_prompt_guards() {
  run_case --to pi --dry-run --raw --prompt "-starts-with-dash"
  assert_status 2
  assert_stderr_contains "a --raw prompt cannot begin with '-' or '@'"

  run_case --to pi --dry-run --raw --prompt "@starts-with-at"
  assert_status 2
  assert_stderr_contains "a --raw prompt cannot begin with '-' or '@'"
}

test_pi_json_rejected() {
  run_case --to pi --dry-run --json "Review API"
  assert_status 2
  assert_stderr_contains "pi backend does not support --json"
}

test_positional_prompt_and_dash_caveat() {
  run_case --to gemini --dry-run "Review API"
  assert_status 0
  assert_stdout_contains "Review API"

  run_case --to gemini --dry-run --prompt "-dash prompt"
  assert_status 0
  assert_stdout_contains "-dash prompt"

  run_case --to gemini --dry-run "-dash prompt"
  assert_status 2
  assert_stderr_contains "unknown flag '-dash prompt'"
}

test_dispatcher_does_not_capture_forwarded_values() {
  run_case --to pi --dry-run --prompt "--help"
  assert_status 0
  assert_stdout_contains "--help"

  run_case --to gemini --dry-run --resume "--list" "Review API"
  assert_status 0
  assert_stdout_contains "--resume --list"
}

run_test "codex dry-run uses read-only sandbox defaults" test_codex_defaults
run_test "gemini dry-run uses plan approval defaults" test_gemini_defaults
run_test "claude dry-run uses plan permission defaults" test_claude_defaults
run_test "opencode dry-run uses plan agent defaults" test_opencode_defaults
run_test "pi dry-run uses tool allowlist and discovery hardening" test_pi_defaults
run_test "raw backend passthrough is rejected" test_passthrough_rejected
run_test "prompt secret preflight blocks obvious secrets" test_prompt_secret_preflight
run_test "unknown normalized flags are rejected" test_unknown_flag_rejected
run_test "invalid backend names are rejected" test_invalid_backend_rejected
run_test "unknown backend names are rejected" test_unknown_backend_rejected
run_test "resume and session-id conflicts fail where both exist" test_resume_session_conflicts
run_test "file attachment support boundaries are explicit" test_file_support_boundaries
run_test "pi raw prompts cannot begin with dash or at sign" test_pi_raw_prompt_guards
run_test "pi rejects consult json mode" test_pi_json_rejected
run_test "positional prompts work with dash caveat" test_positional_prompt_and_dash_caveat
run_test "dispatcher does not capture forwarded option values" test_dispatcher_does_not_capture_forwarded_values

printf '%s wrapper checks passed\n' "$PASS_COUNT"
