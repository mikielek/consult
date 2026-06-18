# Claude Code CLI Notes

Used by the `claude` backend adapter (`scripts/backends/claude.sh`).
Observed in a workspace on 2026-06-16 with `claude 2.1.178`; rechecked on
2026-06-18 with Claude Code `2.1.181`.

## Adapter invocation

```bash
claude -p --permission-mode plan [--output-format json] [--model M] \
       [--continue | --resume ID] [--session-id UUID] "PROMPT"
```

- `-p`/`--print` = non-interactive headless mode; the prompt is positional (last).
- `--permission-mode plan` = read-only review: Plan mode does not apply edits (it produces analysis /
  a plan). This is **approval-gated / policy-level** read-only, not an OS sandbox.
- `--output-format json` (requires `--print`) returns a single JSON result object. `--model` accepts
  an alias (`fable`, `opus`, `sonnet`) or a full id (`claude-opus-4-8`).

## Model discovery

`claude whoami` is the best explicit auth check observed — a non-mutating diagnostic that confirms
the account, not model availability. Claude Code has no native model-listing command in `2.1.181`,
so model choice relies on known aliases/ids (`fable`, `sonnet`, `opus`, or a full id like
`claude-sonnet-4-6`) plus a probe.

Probe a model by running a one-shot consult through the wrapper, which applies the adapter's plan
mode, reviewer framing, and secret preflight:

```bash
scripts/consult.sh --to claude --model claude-sonnet-4-6 --prompt "hi"
```

Add `--dry-run` to see the exact resolved `claude` command (plan mode, `--model`, and the framed
prompt; the vendor shape is in "Adapter invocation" above). Do not hand-run a raw `claude` probe —
use the wrapper so the safe defaults and preflight always apply.

## Session persistence

- `--resume latest` → `--continue` (most recent conversation in this directory).
- `--resume <id>` → `--resume <id>`.
- `--session-id <uuid>` starts/uses a specific session (must be a valid UUID).
- `--resume` and `--session-id` are mutually exclusive (the adapter errors if both are given).

## Caveats

- `claude -p` skips the workspace-trust dialog — only consult inside directories you trust.
- Web/search tools are left at the CLI default (not restricted).
- Plan-mode output may also be saved as a local Claude plan under `~/.claude/plans/`. If an
  interrupted consult or truncated stdout only refers to a plan, inspect the newest relevant file
  there. Treat it as a Claude-specific recovery path and as local session data that may contain
  prompt or repo context.
