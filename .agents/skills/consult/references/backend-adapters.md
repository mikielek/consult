# Adding & removing consult backends (maintainer guide)

How to extend the `consult` skill with a new backend, or remove one. This is maintenance
documentation — it is **not** needed to *use* the skill, so it lives here (read on demand) rather
than in `SKILL.md`. It travels with the skill when the directory is copied or symlinked.

## Remove a backend

Delete its `scripts/backends/<name>.sh`. Nothing else — `scripts/consult.sh --list` discovers
backends dynamically from that directory, so the backend simply disappears.

## Add a backend

Drop a `scripts/backends/<name>.sh` adapter (copy an existing one as a template). The dispatcher
(`scripts/consult.sh`) validates `--to <name>` against the bare filename and execs the adapter via
`bash`, so adapters do not strictly need the executable bit (though keeping them `+x`, like the
others, is the convention).

An adapter:

1. Starts with the strict preamble and the discovery header:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   # consult-cli: <binary>
   ```
   The `# consult-cli: <binary>` header is read by `--list` (`consult.sh` `list_backends()`) to
   report whether the backend's CLI is installed; omitting it degrades to "CLI not declared".
2. Sources the shared library and parses the normalized flags:
   ```bash
   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
   parse_common_args "$@"
   require_prompt
   ```
   `parse_common_args` populates these globals: `PROMPT JSON RESUME SESSION_ID MODEL FROM DRY_RUN
   RAW FILES[]`. There is **deliberately no `--`/passthrough** — only the documented normalized
   flags reach the backend CLI, so callers cannot inject permission- or capability-shaping flags.
3. Builds the prompt via `prompt="$(compose_prompt "<DisplayName>")"` (capitalized display name,
   e.g. `"Claude"`, `"Pi"`). This prepends the neutral advisory reviewer framing unless `--raw`.
4. Translates the globals into the backend's CLI as an **argv array** (no shell `eval`), enforcing
   mutation-restricted defaults appropriate to that CLI (OS sandbox, plan/approval mode, or a tool
   allowlist — see the per-backend `references/<name>-cli.md`). Reject flags the backend can't
   honor (e.g. `die` if both `--resume` and `--session-id` are given, or if `--file` is
   unsupported).
5. Hands the command to `run_or_print "${cmd[@]}"`, which prints it under `--dry-run` or `exec`s it
   with stdin closed (`</dev/null`) to stay non-interactive. `cmd[0]` must be the backend's base
   binary (not a wrapper like `npx`) so the `command -v` install check is accurate.

The existing adapters are the canonical templates: `claude.sh`, `codex.sh`, `gemini.sh`,
`opencode.sh`, `pi.sh`. Record observed CLI behavior, tested flags, and caveats for the new backend
in a `references/<name>-cli.md`.

## Conventions

- Name the adapter after its backend (`gemini.sh`, `pi.sh`). Prefer small backend-specific adapters
  over branching in `consult.sh`.
- Verify behavior with at least one `scripts/consult.sh --to <name> --dry-run "..."` (and the live
  CLI where practical) before documenting flags in `references/<name>-cli.md`.
- Run `.agents/skills/consult/tests/wrapper.sh` after parser, safety-default, file, session, JSON,
  or prompt-framing changes. It uses fake backend binaries and should not call a model.
