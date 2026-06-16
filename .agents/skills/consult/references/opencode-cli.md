# OpenCode CLI Notes

Used by the `opencode` backend adapter (`scripts/backends/opencode.sh`).
Observed in a workspace on 2026-06-12. Also checked official OpenCode docs dated 2026-06-11.

## Relevant Official Docs

- CLI docs: https://opencode.ai/docs/cli/
- Agents docs: https://opencode.ai/docs/agents/
- Permissions docs: https://opencode.ai/docs/permissions/

## Help Output Highlights

`opencode --help` reports:

- `opencode [project]` starts the TUI by default.
- `opencode run [message..]` runs OpenCode non-interactively with a message (passed positionally).
- Top-level and `run` flags include `--model`, `--continue`, `--session`, `--fork`, and `--agent`.
- `opencode run` supports `--format default|json`, `--file`, `--title`, `--attach`, `--dir`,
  `--variant`, `--thinking`, and `--dangerously-skip-permissions`.
- `opencode session list` lists sessions, and `opencode export [sessionID]` exports session data.

Adapter mapping: `--resume latest` → `--continue`; `--resume <id>` → `--session <id>`;
`--json` → `--format json`; the prompt is passed positionally last.

## Plan Agent and Permissions

OpenCode has a built-in `plan` primary agent for planning and analysis without direct
implementation. By default its file edits and bash commands are set to `ask`, not `deny` — so treat
it as **approval-gated** (effectively read-only in headless mode, where prompts can't be answered),
not a hard sandbox guarantee.

Permission actions: `allow` (run without approval), `ask` (prompt), `deny` (block).

Use `opencode run --agent plan` for consultation by default (the adapter does this), keep the prompt
explicitly read-only, and never pass `--dangerously-skip-permissions` (the adapter rejects it).

For strict read-only behavior, configure an OpenCode agent whose permissions deny `edit` and risky
`bash`. The consult adapter always uses `--agent plan` and supports no passthrough, so selecting a
different agent means editing `scripts/backends/opencode.sh` (or invoking `opencode` directly) —
not a consult flag.

## Testing Without Provider Auth

The dry-run path needs no auth and prints the resolved command:

```bash
scripts/consult.sh --to opencode --dry-run --prompt "..."
```

Running an actual consultation may require provider auth, network access, and approval handling
outside a restricted agent sandbox.
