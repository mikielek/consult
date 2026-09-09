# Adding & removing consult backends (maintainer guide)

How to extend the `consult` skill with a new backend, or remove one. This is maintenance
documentation — it is **not** needed to *use* the skill, so it lives here (read on demand) rather
than in `SKILL.md`. It travels with the skill when the directory is copied or symlinked.

## Remove a backend

Delete its `scripts/backends/<name>.sh` — `scripts/consult.sh --list` discovers backends dynamically
from that directory, so it disappears from the dispatcher immediately. Then clean up the
documentation touchpoints: delete `references/<name>-cli.md`, remove its row from the discovery
Parity table in `references/model-discovery.md`, and (if it was a named trigger) remove it from the
backend name lists / frontmatter trigger in `SKILL.md` and update `evals/evals.json`.

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
   RAW ALLOW_SECRETS`. There is **deliberately no `--`/passthrough** — only the documented
   normalized flags reach the backend CLI, so callers cannot inject permission- or
   capability-shaping flags.
3. Builds the prompt via `prompt="$(compose_prompt "<DisplayName>")"` (capitalized display name,
   e.g. `"Claude"`, `"Pi"`). This prepends the neutral advisory reviewer framing unless `--raw`.
4. Translates the globals into the backend's CLI as an **argv array** (no shell `eval`), enforcing
   mutation-restricted defaults appropriate to that CLI (OS sandbox, plan/approval mode, or a tool
   allowlist — see the per-backend `references/<name>-cli.md`). Reject flag combinations the
   backend can't honor, such as conflicting `--resume` and `--session-id` values.
5. Hands the command to `run_or_print "${cmd[@]}"`, which prints it under `--dry-run` or `exec`s it
   with stdin closed (`</dev/null`) to stay non-interactive. `cmd[0]` must be the backend's base
   binary (not a wrapper like `npx`) so the `command -v` install check is accurate.

The existing adapters are the canonical templates: `claude.sh`, `codex.sh`, `gemini.sh`,
`opencode.sh`, `pi.sh`. Record observed CLI behavior, tested flags, and caveats for the new backend
in a `references/<name>-cli.md`, **including a "Model discovery" section** (its auth-signal command,
any native model-listing command, and the safe wrapper probe `consult.sh --to <name> --model M
--prompt "hi"`) **and a "Read scope" snapshot** (see "Re-measuring read scope" below). Add **one
row** to the discovery Parity table in `references/model-discovery.md`.
Update the backend name lists / frontmatter trigger in `SKILL.md` and `evals/evals.json` only if the
backend should be a named trigger.

Discovery itself is a documented **manual** workflow (`references/model-discovery.md`), not a scripted
adapter capability — there is no `discover_models()` hook to implement.

## Conventions

- Name the adapter after its backend (`gemini.sh`, `pi.sh`). Prefer small backend-specific adapters
  over branching in `consult.sh`.
- Verify behavior with at least one `scripts/consult.sh --to <name> --dry-run "..."` (and the live
  CLI where practical) before documenting flags in `references/<name>-cli.md`.
- Run `.agents/skills/consult/tests/wrapper.sh` after parser, safety-default, session, JSON, or
  prompt-framing changes. It uses fake backend binaries and should not call a model.

## Re-measuring read scope

Whether a backend can read a path *outside* the project tree differs per backend and is not a
contract: it turns on the CLI version, the agent/permission defaults, local config, and the host
sandbox. Each `references/<name>-cli.md` carries a dated "Read scope" snapshot; re-measure it rather
than trusting it, and re-date it when you do.

The probe **deliberately violates** the reachability rule in `SKILL.md` (which tells callers to name
only in-tree paths). It is a capability experiment, not a consultation, and it costs a live model
call per backend plus working backend auth and network.

```bash
mkdir -p /tmp/consult-reach && printf 'REACH_MARKER_7Q\n' > /tmp/consult-reach/probe.txt
# from the project root, per backend:
<cli> --version
scripts/consult.sh --to <name> --prompt "Read /tmp/consult-reach/probe.txt and reply with exactly its first line, or reply CANNOT_READ if you cannot access it. Then read README.md and reply with its first heading."
rm -rf /tmp/consult-reach
```

`REACH_MARKER_7Q` back means the backend reads out of tree. `CANNOT_READ` or a tool error **with the
README heading still returned** means it is cwd/workspace-scoped — the README half is the control
that separates "cannot reach that path" from an auth, network, or model failure. Record the CLI
version and the date.

Nothing in the skill's behavior depends on the result: `SKILL.md`'s caller rule is conservative on
purpose, so it holds whichever way a backend answers.
