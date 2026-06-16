# Claude Code CLI Notes

Used by the `claude` backend adapter (`scripts/backends/claude.sh`).
Observed in a workspace on 2026-06-16 with `claude 2.1.178`.

## Adapter invocation

```bash
claude -p --permission-mode plan [--output-format json] [--model M] \
       [--continue | --resume ID] [--session-id UUID] "PROMPT"
```

- `-p`/`--print` = non-interactive headless mode; the prompt is positional (last).
- `--permission-mode plan` = read-only review: Plan mode does not apply edits (it produces analysis /
  a plan). This is **approval-gated / policy-level** read-only, not an OS sandbox.
- `--output-format json` (requires `--print`) returns a single JSON result object. `--model` accepts
  an alias (`opus`, `sonnet`, `fable`) or a full id (`claude-opus-4-8`).

## Session persistence

- `--resume latest` → `--continue` (most recent conversation in this directory).
- `--resume <id>` → `--resume <id>`.
- `--session-id <uuid>` starts/uses a specific session (must be a valid UUID).
- `--resume` and `--session-id` are mutually exclusive (the adapter errors if both are given).

## Caveats

- No local-file attach: Claude's `--file` is `file_id:relative_path` (resource download), **not** a
  local attach, so the adapter rejects `--file`. Reference the path in `--prompt`; Claude reads it
  with its own tools in plan mode.
- `claude -p` skips the workspace-trust dialog — only consult inside directories you trust.
- Web/search tools are left at the CLI default (not restricted).
